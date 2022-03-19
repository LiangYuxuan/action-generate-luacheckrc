-- Config
local prefix = './.fg/rulesets/'
local globals = './.fg/globals.lua'
local outputFile = arg[1] or '.luacheckrc'
local headerFile = arg[2] or '.luacheckrc_header'

-- Database
local MiscCustom = {
	"Interface",
}

-- Core
local function loadfileToEnv(path, env)
	-- Lua 5.1
	local func, err = loadfile(path)
	assert(func, err)
	setfenv(func, env)
	func()

	return env
end

local destFile = assert(io.open(outputFile, 'w'), "Error opening file " .. outputFile)
local srcFile = io.open(headerFile, 'r')

if srcFile then
	destFile:write(srcFile:read('*a'))
	srcFile:close()
end

local _GlobalStrings = {}; _GlobalStrings._G = {}
local _LuaEnum = {}

loadfileToEnv(prefix .. 'GlobalStrings.lua', _GlobalStrings)
loadfileToEnv(prefix .. 'LuaEnum.lua', _LuaEnum)

local FrameXMLGlobals = dofile(globals)
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

	for key, data in pairs(_LuaEnum.Constants) do
		for indexName in pairs(data) do
			table.insert(Constants, 'Constants.' .. key .. '.' .. indexName)
		end
	end
	table.sort(Constants)
	_LuaEnum.Constants = nil

	local Enum = _LuaEnum.Enum
	_LuaEnum.Enum = nil
	LEStrings = SortKeyName(_LuaEnum)

	for key, data in pairs(Enum) do
		for indexName in pairs(data) do
			table.insert(Enums, 'Enum.' .. key .. '.' .. indexName)
		end
	end
	table.sort(Enums)
end

local tableMap = {
	{MiscCustom,      "Misc Custom"},

	-- Parse from Official Rulesets
	{FrameXMLGlobals, "FrameXML Globals"},
}

destFile:write("read_globals = {")

for _, data in ipairs(tableMap) do
	local tbl, desc = data[1], data[2]

	destFile:write("\n\t-- " .. desc .. "\n")
	for _, name in ipairs(tbl) do
		destFile:write("\t\"" .. name .. "\",\n")
	end
end

destFile:write("}\n")
destFile:close()
