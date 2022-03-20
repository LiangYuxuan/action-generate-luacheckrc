-- Config
local luacCommand = 'luac'
local datapath = './.fg/'
local globals_suffix = 'globals'
local globals_fileextension = '.lua'

-- Datatypes
local packageTypes = {
  ['rulesets'] = { datapath .. 'rulesets/', 'base.xml' },
  ['extensions'] = { datapath .. 'extensions/', 'extension.xml' },
}

-- Core
local lfs = require('lfs')

local function findAllPackages(path)
  local result = {}

  lfs.mkdir(path)
  for file in lfs.dir(path) do
    local fileType = lfs.attributes(path .. '/' .. file, 'mode')
    if fileType == 'directory' then
      if file ~= '.' and file ~= '..' then
        table.insert(result, file)
      end
    end
  end

  return result
end

local function executeCapture(command)
  local file = assert(io.popen(command, 'r'))
  local str = assert(file:read('*a'))
  str = string.gsub(str, '^%s+', '')
  str = string.gsub(str, '%s+$', '')

  file:close()
  return str
end

local function findBaseXml(path, searchName)
  for file in lfs.dir(path) do
    local fileType = lfs.attributes(path .. '/' .. file, 'mode')
    if fileType == 'file' and string.find(file, searchName) then
      return path .. '/' .. file
    end
  end
end

local function findHighLevelScripts(path, searchName)
  local baseXmlFile = findBaseXml(path, searchName)

  local fhandle = io.open(baseXmlFile, 'r')
  local data = fhandle:read("*a")

  local globals = {}
  for line in string.gmatch(data, '[^\r\n]+') do
    if string.match(line, '<script.+/>') then
      local global, filePath  = string.match(line, '<script name="(.+)" file="(.+)" />')
      globals[global] = filePath
    end
  end

  fhandle:close()
  return globals
end

local function findHighLevelGlobals(output, parent, luac, path, file)
  executeCapture(string.format('perl -e \'s/\\xef\\xbb\\xbf//;\' -pi %s/%s', path, file))
  local content = executeCapture(string.format('%s -l -p %s/%s', luac, path, file))

  for line in string.gmatch(content, '[^\r\n]+') do
    if string.match(line, 'SETGLOBAL\t') then
      local variable = (
        '\t\t' ..
        string.match(line, '\t; (.+)%s*') ..
        ' = {\n' ..
        '\t\t\t\tread_only = false,\n\t\t\t\tother_fields = false,' ..
        '\n\t\t\t},\n'
      )
      if not output[parent] then
        output[parent] = variable
      elseif not string.find(output[parent], '\t' .. variable .. '\t') then
        output[parent] = output[parent] .. '\t' .. variable
      end
    end
  end

  return output
end

for packageTypeName, packageType in pairs(packageTypes) do
  local packageList = findAllPackages(packageType[1])
  table.sort(packageList)

  print(string.format("Searching for %s", packageTypeName))
  lfs.mkdir(datapath .. packageTypeName .. globals_suffix .. '/')
  for _, packageName in pairs(packageList) do
    local packagePath = datapath .. packageTypeName .. '/'
    print(string.format("Searching %s files for globals", packageName))
    local highLevelScripts = findHighLevelScripts(packagePath .. packageName, packageType[2])

    local currentBranch = executeCapture(
      string.format(
        'git -C %s branch --show-current', packagePath .. packageName
      )
    )
    print(
      string.format(
      "Currently generating stds definition for %s@%s", packageName, currentBranch
      )
    )

    local destFilePath = (
      datapath ..
      packageTypeName ..
      globals_suffix ..
      '/' ..
      packageName ..
      globals_suffix ..
      globals_fileextension
    )
    local destFile = assert(
      io.open(destFilePath, 'w'), "Error opening file " .. destFilePath)

    local contents = {}
    for parent, filePath in pairs(highLevelScripts) do
      --print(string.format("Handling file %s", filePath))
      findHighLevelGlobals(contents, parent, luacCommand, packageType[1] .. packageName, filePath)
    end

    local output = {}
    for parent, var in pairs(contents) do
      local global = (
        parent .. ' = {\n\t\tread_only = false,\n\t\tfields = {\n\t' .. var .. '\t\t},\n\t},'
      )
      table.insert(output, global)
    end
    table.sort(output)

    destFile:write('globals = {\n')
    for _, var in ipairs(output) do
      destFile:write('\t' .. var .. '\n')
    end

    destFile:write('}\n')
    destFile:close()
  end
end
