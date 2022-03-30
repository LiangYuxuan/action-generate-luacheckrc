local function print_table(node)
	local cache, stack, output = {}, {}, {}
	local depth = 1
	local output_str = '{\n'

	while true do
		local size = 0
		for k, v in pairs(node) do size = size + 1 end

		local cur_index = 1
		for k, v in pairs(node) do
			if (cache[node] == nil) or (cur_index >= cache[node]) then

				if (string.find(output_str, '}', output_str:len())) then
					output_str = output_str .. ',\n'
				elseif not (string.find(output_str, '\n', output_str:len())) then
					output_str = output_str .. '\n'
				end

				-- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
				table.insert(output, output_str)
				output_str = ''

				local key
				if (type(k) == 'number' or type(k) == 'boolean') then
					key = '[' .. tostring(k) .. ']'
				else
					key = '[\'' .. tostring(k) .. '\']'
				end

				if (type(v) == 'number' or type(v) == 'boolean') then
					output_str = output_str .. string.rep('\t', depth) .. key .. ' = ' .. tostring(v)
				elseif (type(v) == 'table') then
					output_str = output_str .. string.rep('\t', depth) .. key .. ' = {\n'
					table.insert(stack, node)
					table.insert(stack, v)
					cache[node] = cur_index + 1
					break
				else
					output_str = output_str .. string.rep('\t', depth) .. key .. ' = \'' .. tostring(v) .. '\''
				end

				if (cur_index == size) then
					output_str = output_str .. '\n' .. string.rep('\t', depth - 1) .. '}'
				else
					output_str = output_str .. ','
				end
			else
				-- close the table
				if (cur_index == size) then output_str = output_str .. '\n' .. string.rep('\t', depth - 1) .. '}' end
			end

			cur_index = cur_index + 1
		end

		if (size == 0) then output_str = output_str .. '\n' .. string.rep('\t', depth - 1) .. '}' end

		if (#stack > 0) then
			node = stack[#stack]
			stack[#stack] = nil
			depth = cache[node] == nil and depth + 1 or depth - 1
		else
			break
		end
	end

	-- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
	table.insert(output, output_str)
	output_str = table.concat(output)

	print(output_str)
end

local datapath = './.fg/'

-- Dependencies
local lfs = require('lfs') -- luafilesystem
local parseXmlFile = require('xmlparser').parseFile

-- Datatypes
local packages = {
	['rulesets'] = { ['path'] = datapath .. 'rulesets/', ['baseFile'] = 'base.xml', ['definitions'] = {} },
	['extensions'] = { ['path'] = datapath .. 'extensions/', ['baseFile'] = 'extension.xml', ['definitions'] = {} },
}

--
-- Functions
--

local function executeCapture(command)
	local file = assert(io.popen(command, 'r'))
	local str = assert(file:read('*a'))
	str = string.gsub(str, '^%s+', '')
	str = string.gsub(str, '%s+$', '')

	file:close()
	return str
end

-- Converts XML escaped strings into the base characters.
-- &gt; to >, for example. This allows the lua parser to handle it correctly.
local function convertXmlEscapes(string)
	string = string:gsub('&amp;', '&')
	string = string:gsub('&quot;', '"')
	string = string:gsub('&apos;', '\'')
	string = string:gsub('&lt;', '<')
	string = string:gsub('&gt;', '>')
	return string
end

-- Opens a file and returns the contents as a string
local function loadFile(file)
	local fhandle = io.open(file, 'r')
	local string

	if fhandle then
		string = fhandle:read('*a')
		fhandle:close()
	end

	return string
end

-- Calls luac and find included SETGLOBAL commands
-- Adds them to supplied table 'globals'
local function findGlobals(globals, directory, file)
	local concatPath = table.concat(directory) .. '/' .. file

	if lfs.touch(concatPath) then
		executeCapture('perl -e \'s/\\xef\\xbb\\xbf//;\' -pi ' .. concatPath)
		local content = executeCapture(string.format('%s -l -p ' .. concatPath, 'luac'))

		for line in content:gmatch('[^\r\n]+') do
			if line:match('SETGLOBAL%s+') and not line:match('%s+;%s+(_)%s*') then
				local globalName = line:match('\t; (.+)%s*')
				globals[globalName] = true
			end
		end

		return true
	end
end

-- Searches for directories in supplied path
-- Adds them to supplied table 'list' and sorts the table
local function findAllPackages(list, path)
	lfs.mkdir(path) -- if not found, create path to avoid errors

	for file in lfs.dir(path) do
		if lfs.attributes(path .. '/' .. file, 'mode') == 'directory' then
			if file ~= '.' and file ~= '..' then table.insert(list, file) end
		end
	end

	table.sort(list)
end

-- Searches for file by name in supplied directory
-- Returns string in format of 'original_path/file_result'
local function findBaseXml(path, searchName)
	local concatPath = table.concat(path)
	for file in lfs.dir(concatPath) do
		local filePath = concatPath .. '/' .. file
		local fileType = lfs.attributes(filePath, 'mode')
		if fileType == 'file' and string.find(file, searchName) then return filePath end
	end
end

-- Checks child elements for matching tag name
-- If found, returns a table of that child element
local function findXmlElement(root, searchStrings)
	if root and root.children then
		for _, xmlElement in ipairs(root.children) do
			for _, searchString in ipairs(searchStrings) do if xmlElement.tag == searchString then return xmlElement end end
		end
	end
end

-- Trims package name to prevent issues with luacheckrc
local function trimPackageName(text)
	text = text:gsub('.+:', '') -- remove prefix
	text = text:gsub('%(.+%)', '') -- remove parenthetical
	text = text:gsub('%W', '') -- remove non alphanumeric
	return text
end

-- Reads supplied XML file to find name and author definitions.
-- Returns a simplified string to identify the extension
local function getAltPackageName(baseXmlFile)
	local altName = { '' }

	local xmlRoot = findXmlElement(parseXmlFile(baseXmlFile), { 'root' })
	local xmlProperties = findXmlElement(xmlRoot, { 'properties' })
	if xmlProperties then
		for _, element in ipairs(xmlProperties.children) do
			if element.tag == 'name' or element.tag == 'author' then
				table.insert(altName, trimPackageName(element.children[1]['text']))
			end
		end
	end

	table.sort(altName)

	return table.concat(altName)
end

-- Determine best package name
-- Returns as a lowercase string
local function getPackageName(baseXmlFile, packageName)
	local shortPackageName = getAltPackageName(baseXmlFile)

	if shortPackageName == '' then shortPackageName = packageName end

	-- prepend 'def' if 1st character isn't a-z
	if string.sub(shortPackageName, 1, 1):match('%A') then shortPackageName = 'def' .. shortPackageName end

	return shortPackageName:lower()
end

-- Search through a supplied fantasygrounds xml file to find other defined xml files.
local function findXmls(baseXmlFile, path)
	local data = loadFile(baseXmlFile)

	local concatPath = table.concat(path)

	local xmlFiles = {}
	for line in data:gmatch('[^\r\n]+') do
		if line:match('<includefile.+/>') and not line:match('<!--.*<includefile.+/>.*-->') then
			local sansRuleset = line:gsub('ruleset=".-"%s+', '')
			local filePath = sansRuleset:match('<includefile%s+source="(.+)"%s*/>') or ''
			local fileName = filePath:match('.+/(.-).xml') or filePath:match('(.-).xml')
			if fileName then xmlFiles[fileName] = concatPath .. '/' .. filePath end
		end
	end

	return xmlFiles
end

-- Calls findGlobals for lua functions in XML-formatted string
-- Creates temp file, writes string to it, calls findGlobals, deletes temp file
local function getFnsFromLuaInXml(fns, string)
	local tempFilePath = datapath .. 'xmlscript.tmp'
	tempFile = assert(io.open(tempFilePath, 'w'), 'Error opening file ' .. tempFilePath)

	local script = convertXmlEscapes(string)

	tempFile:write(script)
	tempFile:close()

	findGlobals(fns, { datapath }, 'xmlscript.tmp')

	os.remove(tempFilePath)
end

local function findAltScriptLocation(templateFunctions, packagePath, filePath)
	for _, packageName in ipairs(packages.extensions.packageList) do
		if packageName ~= altPackagePath[4] then
			local altPackagePath = packagePath
			altPackagePath[4] = packageName
			findGlobals(templateFunctions, altPackagePath, filePath)
		end
	end
end

-- When supplied with a lua-xmlparser table for the <script> element of a template,
-- this function adds any functions from it into a supplied table.
local function getTemplateScriptFromXml(templates, packagePath, parent, element)
	local script = findXmlElement(parent, { 'script' })
	if script then
		local templateFunctions = {}
		if script.attrs.file then
			if not findGlobals(templateFunctions, packagePath, script.attrs.file) then
				findAltScriptLocation(templateFunctions, packagePath, script.attrs.file)
			end
		elseif script.children[1].text then
			getFnsFromLuaInXml(templateFunctions, script.children[1].text)
		end
		templates[element.attrs.name] = { ['inherit'] = parent.tag, ['functions'] = templateFunctions }
	end
end

local function findTemplateRelationships(templates, packagePath, xmlFiles)
	for _, xmlPath in pairs(xmlFiles) do
		local root = findXmlElement(parseXmlFile(xmlPath), { 'root' })
		for _, element in ipairs(root.children) do
			if element.tag == 'template' then
				for _, template in ipairs(element.children) do
					getTemplateScriptFromXml(templates, packagePath, template, element)
				end
			end
		end
	end
end

local function matchRelationshipScripts(templates)
	for name, data in pairs(templates) do
		local inheritedTemplate = templates[data['inherit']]
		if inheritedTemplate and inheritedTemplate['functions'] then
			for functionName, _ in pairs(inheritedTemplate['functions']) do templates[name]['functions'][functionName] = true end
		end
	end
end

-- When supplied with a lua-xmlparser table for the <script> element,
-- this function adds any functions from it into a supplied table.
local function getScriptFromXml(output, packagePath, element)
	local script = findXmlElement(parent, { 'script' })
	if script then
		local fns = {}
		if script.attrs.file then
			if not findGlobals(fns, packagePath, script.attrs.file) then
				local altPackagePath = packagePath
				altPackagePath[4] = 'CoreRPG'
				findGlobals(fns, altPackagePath, script.attrs.file)
			end
		elseif script.children[1].text then
			getFnsFromLuaInXml(fns, script.children[1].text)
		end
		output[element.attrs.name] = { ['functions'] = fns }
	end
end

local function recursiveXmlSearch(packageDefinitions, packagePath, parent, templates)
	for _, element in ipairs(parent.children) do
		local script = findXmlElement(element, { 'script' })
		if script then
			getScriptFromXml(packageDefinitions, packagePath, parent, element)
		elseif element.children then
			recursiveXmlSearch(packageDefinitions, packagePath, element, templates)
		end
	end
end

local function getWindowclassScript(packageDefinitions, packagePath, element)
	local script = findXmlElement(element, { 'script' })
	if script then
		local functions = {}
		if script.attrs.file then
			if not findGlobals(functions, packagePath, script.attrs.file) then
				local altPackagePath = packagePath
				altPackagePath[4] = 'CoreRPG'
				findGlobals(functions, altPackagePath, script.attrs.file)
			end
			elseif script.children[1].text then
			getFnsFromLuaInXml(functions, script.children[1].text)
		end
		packageDefinitions[element.attrs.name] = functions
	end
end
local function findInterfaceScripts(packageDefinitions, templates, xmlFiles, packagePath)
	for _, xmlPath in pairs(xmlFiles) do
		local root = findXmlElement(parseXmlFile(xmlPath), { 'root' })
		for _, element in ipairs(root.children) do
			if element.tag == 'windowclass' then -- save windowclass scripts
				getWindowclassScript(packageDefinitions, packagePath, element)
			elseif element.tag ~= 'template' then -- ignore templates and search through rest of file hierarchy recursively
				local sheetdata = findXmlElement(element, { 'sheetdata' })
				if sheetdata then recursiveXmlSearch(packageDefinitions, packagePath, sheetdata, templates) end
			end
		end
	end
end

-- Compiles list of of scripts defined in supplied XML file.
-- Returns table of script file paths keyed to the script name.
local function findHighLevelScripts(baseXmlFile)
	local data = loadFile(baseXmlFile)

	local scripts = {}
	for line in string.gmatch(data, '[^\r\n]+') do
		if string.match(line, '<script.+/>') and not string.match(line, '<!--.*<script.+/>.*-->') then
			local sansRuleset = line:gsub('ruleset=".-"%s+', '')
			local ScriptName, filePath = sansRuleset:match('<script%s+name="(.+)"%s+file="(.+)"%s*/>')
			if ScriptName then scripts[ScriptName] = filePath end
		end
	end

	return scripts
end

--
-- MAIN CHUNK
--

local templates = {}
-- Iterate through package types defined in packageTypes
for packageTypeName, packageTypeData in pairs(packages) do
	packageTypeData.packageList = {}

	print(string.format('Searching for %s', packageTypeName))
	findAllPackages(packageTypeData.packageList, packageTypeData['path'])

	for _, packageName in ipairs(packageTypeData.packageList) do
		print(string.format('Found %s.', packageName))
		local packagePath = { datapath, packageTypeName, '/', packageName }
		local baseXmlFile = findBaseXml(packagePath, packageTypeData['baseFile'])

		local shortPackageName = getPackageName(baseXmlFile, packageName)
		print(string.format('Creating definition entry %s.', shortPackageName))

		packageTypeData['definitions'][shortPackageName] = {}

		local interfaceXmlFiles = findXmls(baseXmlFile, packagePath)

		findTemplateRelationships(templates, packagePath, interfaceXmlFiles)
		matchRelationshipScripts(templates)

		findInterfaceScripts(packageTypeData['definitions'][shortPackageName], templates, interfaceXmlFiles, packagePath)
		print_table(packageTypeData['definitions'][shortPackageName])
	end
end
