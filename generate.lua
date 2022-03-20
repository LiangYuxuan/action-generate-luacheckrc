-- Config
local dataPath = './.fg/'
local globalsExtension = '.lua'

local stdString = arg[1] or 'lua51+fg+fgfunctions+corerpg'
local headerFileName = arg[2] or '.luacheckrc_header'
local outputFile = arg[3] or '.luacheckrc'

-- Datatypes
local packageTypes = {
  ['rulesets'] = { dataPath .. 'rulesetsglobals/', 'base.xml' },
  ['extensions'] = { dataPath .. 'extensionsglobals/', 'extension.xml' },
}

-- Core
local lfs = require('lfs')

local destFile = assert(io.open(outputFile, 'w'), "Error opening file " .. outputFile)

local headerFile = io.open(headerFileName, 'r')
if headerFile then
	destFile:write(headerFile:read('*a'))
	headerFile:close()
end

if stdString then
	destFile:write("\nstd = '" .. stdString .. "'\n")
end

local function findPackageFiles(path)
  local result = {}

  for file in lfs.dir(path) do
    local fileType = lfs.attributes(path .. '/' .. file, 'mode')
		local packageName = string.match(file, '(.*)globals.lua')
		if packageName and fileType == 'file' then
      if file ~= '.' and file ~= '..' then
        result[packageName] = path .. '/' .. file
      end
    end
  end

	return result
end

for _, packageType in pairs(packageTypes) do
	local packageFiles = findPackageFiles(packageType[1])
	for packageName, file in pairs(packageFiles) do
		destFile:write('\nstds.' .. packageName:lower() .. ' = {\n')
		local fhandle = io.open(file, 'r')
		local content = fhandle:read("*a")
		for line in string.gmatch(content, '[^\r\n]+') do
			destFile:write("\t" .. line .. "\n")
		end
		destFile:write('}\n')
	end
end

destFile:close()
