-- Config
-- local prefix = './.fg/rulesets/'
local globalsDirectory = './.fg/globals'
local outputFile = arg[1] or '.luacheckrc'
local headerFile = arg[2] or '.luacheckrc_header'

-- Core
local lfs = require('lfs')

local destFile = assert(io.open(outputFile, 'w'), "Error opening file " .. outputFile)
local srcFile = io.open(headerFile, 'r')

if srcFile then
	destFile:write(srcFile:read('*a'))
	srcFile:close()
end

local function findAllGlobals(path)
  local result = {}

  for file in lfs.dir(path) do
    local fileType = lfs.attributes(path .. '/' .. file, 'mode')
		local ruleset = string.match(file, '(.*)globals.lua')
		if fileType == 'file' and ruleset then
      if file ~= '.' and file ~= '..' then
        result[ruleset] = path .. '/' .. file
      end
    end
  end

	return result
end

local globalFiles = findAllGlobals(globalsDirectory)
for ruleset, file in pairs(globalFiles) do
	destFile:write('\nstds.' .. ruleset:lower() .. ' = {\n')
	local fhandle = io.open(file, 'r')
	local content = fhandle:read("*a")
	for line in string.gmatch(content, '[^\r\n]+') do
		destFile:write("\t" .. line .. "\n")
	end
	destFile:write('}\n')
end

destFile:close()
