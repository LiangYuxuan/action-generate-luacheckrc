-- Config
local UISource = './.wow/wow-ui-source/Interface/'
local luacCommand = 'luac'
local outputFile = './.wow/FrameXMLGlobals.lua'

-- Core
local lfs = require('lfs')

local function findAllFiles(path)
    local result = {}

    for file in lfs.dir(path) do
        local fileType = lfs.attributes(path .. '/' .. file, 'mode')
        if fileType == 'file' and string.find(file, '^[^.].+%.lua') then
            table.insert(result, file)
        elseif fileType == 'directory' then
            if file ~= '.' and file ~= '..' and file ~= 'Blizzard_Deprecated' then
                local subResult = findAllFiles(path .. '/' .. file)
                for _, subFile in ipairs(subResult) do
                    table.insert(result, file .. '/' .. subFile)
                end
            end
        end
    end

    return result
end

local function executeCapture(command)
    local file = assert(io.popen(command, 'r'))
    local str = assert(file:read('*a'))
    file:close()
    str = string.gsub(str, '^%s+', '')
    str = string.gsub(str, '%s+$', '')
    return str
end

local function findAllGlobals(output, luac, path, file)
    executeCapture(string.format('perl -e \'s/\\xef\\xbb\\xbf//;\' -pi %s/%s', path, file))
    local content = executeCapture(string.format('%s -l -p %s/%s', luac, path, file))

    for line in string.gmatch(content, '[^\r\n]+') do
        if string.match(line, 'SETGLOBAL\t') then
            local variable = string.match(line, '\t; (.+)%s*')
            output[variable] = true
        end
    end

    return output
end

local fileList = findAllFiles(UISource)
table.sort(fileList)

local currentBranch = executeCapture(string.format('git -C %s branch --show-current', UISource))
print(string.format("Currently generating FrameXML globals for %s", currentBranch))

local destFile = assert(io.open(outputFile, 'w'), "Error opening file " .. outputFile)

local globals = {}
for _, filePath in ipairs(fileList) do
    print(string.format("Handling file %s", filePath))
    findAllGlobals(globals, luacCommand, UISource, filePath)
end

local output = {}
for var in pairs(globals) do
    table.insert(output, var)
end
table.sort(output)

destFile:write('local globals = {\n')

for _, var in ipairs(output) do
    destFile:write('\t"' .. var .. '",\n')
end

destFile:write('}\n\nreturn globals\n')
destFile:close()
