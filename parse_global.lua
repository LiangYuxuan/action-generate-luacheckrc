-- Config
local luacCommand = 'luac'
local datapath = './.fg/'
local globals_suffix = 'globals'

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

local function findHighLevelScripts(baseXmlFile)
  local fhandle = io.open(baseXmlFile, 'r')
  local data = fhandle:read("*a")

  local scripts = {}
  for line in string.gmatch(data, '[^\r\n]+') do
    if string.match(line, '<script.+/>') and not string.match(line, '<!--.*<script.+/>.*-->') then
      local fileName, filePath  = string.match(line, '<script%s*name="(.+)"%s*[ruleset=".*"%s*]*file="(.+)"%s*/>')
      if fileName then
        scripts[fileName] = filePath
      end
    end
  end

  fhandle:close()
  return scripts
end

local function findInterfaceScripts(path, xmlFile)
  local fhandle = io.open(xmlFile, 'r')
  local data = fhandle:read("*a")

  local scripts = {}
  for line in string.gmatch(data, '[^\r\n]+') do
    if string.match(line, '<script.+/>') then
      local filePath  = string.match(line, '<script%s*file="(.+)"%s*/>')
      local fileName = string.match(filePath, '.+/(.-).lua') or string.match(filePath, '(.-).lua')
      scripts[fileName] = path .. '/' .. filePath
    end
  end

  fhandle:close()
  return scripts
end

local function findInterfaceXmls(path, searchName)
  local baseXmlFile = findBaseXml(path, searchName)

  local fhandle = io.open(baseXmlFile, 'r')
  local data = fhandle:read("*a")

  local xmlFiles = {}
  for line in string.gmatch(data, '[^\r\n]+') do
    if string.match(line, '<includefile.+/>') and not string.match(line, '<!--.*<includefile.+/>.*-->') then
      local filePath  = string.match(line, '<includefile%s*[ruleset=".*"%s*]*source="(.+)"%s*/>') or ''
      local fileName = string.match(filePath, '.+/(.-).xml') or string.match(filePath, '(.-).xml')
      if fileName then
        xmlFiles[fileName] = path .. '/' .. filePath
      end
    end
  end

  fhandle:close()
  return xmlFiles
end

local function findGlobals(output, parent, luac, file)
  executeCapture('perl -e \'s/\\xef\\xbb\\xbf//;\' -pi ' .. file)
  local content = executeCapture(string.format('%s -l -p ' .. file, luac))

  for line in string.gmatch(content, '[^\r\n]+') do
    if string.match(line, 'SETGLOBAL\t') and
    not string.match(line, '\t; (_)%s*') then
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

    local currentBranch = executeCapture(
      string.format(
        'git -C %s branch --show-current', packagePath .. packageName
      )
    )

    local formattedPackageName = string.gsub(packageName, '[^%a%d]+', '')
    if string.sub(formattedPackageName, 1, 1):match('%d') then
<<<<<<< HEAD
      formattedPackageName = 'def' .. formattedPackageName
=======
      formattedPackageName .. 'def' .. formattedPackageName
>>>>>>> 7eb3d0b1eb145a7c00aba7cb9c361ccc8ce7ce6c
    end
    print(
      string.format(
      "Currently generating stds definition for %s@%s", formattedPackageName, currentBranch
      )
    )
    local destFilePath = (
      datapath ..
      packageTypeName ..
      globals_suffix ..
      '/' ..
      formattedPackageName ..
      globals_suffix ..
      '.lua'
    )

    local destFile = assert(
      io.open(destFilePath, 'w'), "Error opening file " .. destFilePath)

    local baseXmlFile = findBaseXml(packagePath .. packageName, packageType[2])
    local highLevelScripts = findHighLevelScripts(baseXmlFile)
    local contents = {}
    for parent, filePath in pairs(highLevelScripts) do
      --print(string.format("Handling file %s", filePath))
      findGlobals(contents, parent, luacCommand, packageType[1] .. packageName .. '/' .. filePath)
    end

    local interfaceScripts = findInterfaceXmls(packagePath .. packageName, packageType[2])
    for _, xmlPath in pairs(interfaceScripts) do
      local xmlScripts = findInterfaceScripts(packagePath .. packageName, xmlPath)
      for fileName, filePath in pairs(xmlScripts) do
        print(string.format("Handling file %s", fileName))
        findGlobals(contents, fileName, luacCommand, filePath)
      end
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
