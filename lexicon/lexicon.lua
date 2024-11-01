-- The main lexicon program.
-- From here, you can access all of lexicon's subprograms!

local completion = require("cc.completion")

local MANIFEST_URL = "https://raw.githubusercontent.com/alexfayers/cc-24/main/lexicon/lexicon-db.json"

-- local pretty = require("cc.pretty")
local LEXICON_DB_PATH = "/.lexicon/db.json"

---Load the lexicon database from disk
---@return table
local function loadLexiconDb()
    local f = fs.open(LEXICON_DB_PATH, "r")
    if f then
        local db = textutils.unserialiseJSON(f.readAll())
        f.close()
        return db
    end

    return {
        packages = {}
    }
end

---Save the lexicon database to disk
---@param db table
---@return nil
local function saveLexiconDb(db)
    local f = fs.open(LEXICON_DB_PATH, "w")
    f.write(textutils.serialiseJSON(db))
    f.close()
end

---Add a token to the end of a URL to prevent caching
---@param url string
---@return string
local function addTokenToUrl(url)
    ---@diagnostic disable-next-line: undefined-field
    return url .. "?token=" .. os.epoch("utc")
end

---Get the latest manifest from the lexicon repository
---@return table
local function getLatestManifest()
    -- use a token to prevent caching
    local request = http.get(addTokenToUrl(MANIFEST_URL))
    if request then
        local manifest = textutils.unserialiseJSON(request.readAll())
        request.close()
        return manifest
    end

    error("Failed to get latest manifest")
end

local manifest = getLatestManifest()


local function showAvailablePackages()
    term.setTextColor(colors.blue)
    print("Available packages:")
    term.setTextColor(colors.white)
    for packageName, packageData in pairs(manifest["packages"]) do
        if packageData["type"] == "library" then
            term.setTextColor(colors.gray)
        elseif packageData["type"] == "program" then
            term.setTextColor(colors.lime)
        end
        print(" - " .. packageName .. " (" .. packageData["version"] .. ")")
    end
    term.setTextColor(colors.white)
end


local function showInstalledPackages()
    local db = loadLexiconDb()
    term.setTextColor(colors.blue)
    print("Installed packages:")
    term.setTextColor(colors.white)
    for packageName, _ in pairs(db["packages"]) do
        term.setTextColor(colors.lime)
        print(" - " .. packageName)
    end
    term.setTextColor(colors.white)
end


---Download a package from the lexicon repository
---@param packageName string The name of the package to download
---@param parentPackage string | nil The name of the parent package
local function downloadPackage(packageName, parentPackage)
    -- pretty.print(pretty.pretty(manifest))
    local packageData = manifest["packages"][packageName]

    if not packageData then
        term.setTextColor(colors.red)
        print("Package '" .. packageName .. "' not found.")
        showAvailablePackages()
        return
    end

    local downloadMessage = "Downloading " .. packageName .. " (" .. packageData["version"] .. ")"
    if parentPackage then
        term.setTextColor(colors.gray)
        downloadMessage = downloadMessage .. " for " .. parentPackage
    end
    print(downloadMessage .. "...")
    term.setTextColor(colors.white)

    local packageDependencies = packageData["dependencies"]
    if #packageDependencies > 0 then
        -- term.setTextColor(colors.blue)
        -- print("Found " .. #packageDependencies .. " dependencies for '" .. packageName .. "'")
        -- term.setTextColor(colors.white)
        for _, dependecyName in pairs(packageDependencies) do
            downloadPackage(dependecyName, packageName)
        end
    end

    local packageFiles = packageData["files"]
    -- files are an array of {url, downloadPath}
    for _, file in ipairs(packageFiles) do
        local sourceUrl = file[1]
        local downloadPath = file[2]

        local request = http.get(addTokenToUrl(sourceUrl))
        if request then
            local fileContents = request.readAll()
            request.close()

            local f = fs.open(downloadPath, "w")
            f.write(fileContents)
            f.close()
        else
            error("Failed to download file")
        end
    end

    -- Check if the program path is set
    if packageData["program-path"] then
        local globalPath = shell.path()
        local path = packageData["program-path"]
        if not globalPath:find(path, 1, true) then
            shell.setPath(globalPath .. ":" .. path)
        end
        term.setTextColor(colors.gray)
        print("Added '" .. packageName .. "' to the shell path")
        term.setTextColor(colors.white)
    end

    if not parentPackage then
        local db = loadLexiconDb()
        table.insert(db["packages"], packageName)
        saveLexiconDb(db)

        term.setTextColor(colors.lime)
        print("Downloaded " .. packageName .. " (" .. packageData["version"] .. ")")
        if packageData["type"] == "program" then
            term.setTextColor(colors.blue)
            print("You can run it with '" .. packageName .. "'")
        end
        term.setTextColor(colors.white)
    end
end


---Update all packages in the lexicon database
---@return nil
local function updatePackages()
    local db = loadLexiconDb()
    for _, packageName in pairs(db["packages"]) do
        downloadPackage(packageName)
    end
end


local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, { "get", "upgrade", "list", "list-installed" }, true)
    elseif index == 2 then
        if previous[#previous] == "get" then
            packageNames = {}
            for packageName, _ in pairs(manifest["packages"]) do
                table.insert(packageNames, packageName)
            end
            return completion.choice(argument, packageNames)
        end
    end
end

local function usage()
    print("Usage: lexicon <command>")
    print("Commands:")
    print("  get <package> - Download a package from the lexicon repository")
    print("  upgrade - Update all previously downloaded packages")
    print("  list - List all available packages")
    print("  list-installed - List all installed packages")
end

local function handleArgs()
    if #arg == 0 then
        usage()
        return
    else
        if arg[1] == "get" then
            if #arg < 2 then
                print("Usage: lexicon get <package>")
                return
            end

            downloadPackage(arg[2])
        elseif arg[1] == "list" then
            showAvailablePackages()
        elseif arg[1] == "upgrade" then
            updatePackages()
        elseif arg[1] == "list-installed" then
            showInstalledPackages()
        else
            term.setTextColor(colors.red)
            print("Unknown command: '" .. arg[1] .. "'")
            term.setTextColor(colors.white)
            usage()
        end
    end
end

-- Download package-example as a test
shell.setCompletionFunction("lexicon.lua", complete)
handleArgs()
