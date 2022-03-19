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

local _GlobalStrings = {}; _GlobalStrings._G = {}
local _LuaEnum = {}

local GlobalStrings
local Constants = {}
local LEStrings
local Enums = {}

do
	local function SortKeyName(data)
		local result = {}
		for key in pairs(data) do
			table.insert(result, key)
		end

		table.sort(result)
		return result
	end

	for key in pairs(_GlobalStrings._G) do
		_GlobalStrings[key] = true
	end
	_GlobalStrings._G = nil
	GlobalStrings = SortKeyName(_GlobalStrings)
end

local tableMap = {}

local function findAllGlobals(path)
  local result = {}

  for file in lfs.dir(path) do
    local fileType = lfs.attributes(path .. '/' .. file, 'mode')
		if fileType == 'file' and string.match(file, '(.*)globals.lua') then
      if file ~= '.' and file ~= '..' then
        table.insert(result, path .. '/' .. file)
      end
    end
  end

	return result
end

local globalFiles = findAllGlobals(globalsDirectory)
for _, file in ipairs(globalFiles) do
	table.insert(tableMap, { file, 'Scripts and functions from ' .. file })
end

destFile:write('\nglobals = {')

local function executeCapture(command)
  local file = assert(io.popen(command, 'r'))
  local str = assert(file:read('*a'))
  file:close()
  str = string.gsub(str, '^%s+', '')
  str = string.gsub(str, '%s+$', '')
  return str
end

for _, data in ipairs(tableMap) do
	local file, desc = data[1], data[2]
	destFile:write("\n\t-- " .. desc .. "\n")
	local fhandle = io.open(file, 'r')
  local content = fhandle:read("*a")
	for line in string.gmatch(content, '[^\r\n]+') do
		destFile:write("\t" .. line .. "\n")
	end
end

destFile:write('}\n')
destFile:close()
