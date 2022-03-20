-- Config
local dataPath = './.fg/'
local globalsExtension = '.lua'

local outputFile = arg[1] or '.luacheckrc'
local headerFileName = arg[2] or '.luacheckrc_header'
local stdFileName = arg[3] or '.luacheckrc_std'

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

local stdFile = io.open(stdFileName, 'r')
if stdFile then
	destFile:write('\n' .. stdFile:read('*a'))
	stdFile:close()
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
