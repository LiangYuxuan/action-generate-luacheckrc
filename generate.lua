-- Config
local dataPath = './.fg/'

local stdBase = 'lua51+fg+fgfunctions+corerpg'
local stdString = arg[1] or ''
local headerFileName = arg[2] or '.luacheckrc_header'
local outputFile = arg[3] or '.luacheckrc'

-- Core
local lfs = require('lfs')

-- open new luachecrc file for writing and post error if not possible
local destFile = assert(io.open(outputFile, 'w'), 'Error opening file ' .. outputFile)

-- open header file and add to top of new config file
local headerFile = io.open(headerFileName, 'r')
if headerFile then
	destFile:write(headerFile:read('*a'))
	headerFile:close()
end

-- add std config to luachecrc file
destFile:write("\nstd = \'" .. stdBase .. stdString .. "\'\n")

-- returns a list of files ending in globals.lua
local function findPackageFiles(path)
	local result = {}

	for file in lfs.dir(path) do
		local fileType = lfs.attributes(path .. '/' .. file, 'mode')
		local packageName = string.match(file, '(.*).luacheckrc_std')
		if packageName and fileType == 'file' then
			if file ~= '.' and file ~= '..' then result[packageName] = path .. '/' .. file end
		end
	end

	return result
end

-- looks through each package type's detected globals
-- it then appends them to the config file
local packageFiles = findPackageFiles(dataPath .. 'globals/')
for packageName, file in pairs(packageFiles) do
	local stdsName = ('\nstds.' .. packageName:lower() .. ' = {\n')
	destFile:write(stdsName)
	local fhandle = io.open(file, 'r')
	local content = fhandle:read('*a')
	for line in string.gmatch(content, '[^\r\n]+') do destFile:write('\t' .. line .. '\n') end
	destFile:write('}\n')
end

destFile:close()
