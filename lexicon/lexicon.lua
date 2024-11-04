-- The main lexicon program.
-- From here, you can access all of lexicon's subprograms!

local completion = require("cc.completion")
local pretty = require("cc.pretty")

settings.define("lexicon.dbUrl", {
    description = "The URL to the lexicon database",
    default = "https://raw.githubusercontent.com/alexfayers/cc-24/main/lexicon/lexicon-db.json",
    type = "string",
})

settings.define("lexicon.dbPath", {
    description = "The path to the lexicon database",
    default = "/.lexicon/db.json",
    type = "string",
})

local MANIFEST_URL = settings.get("lexicon.dbUrl")

-- local pretty = require("cc.pretty")
local LEXICON_DB_PATH = settings.get("lexicon.dbPath")

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
---@return table _ The files that were downloaded
local function downloadPackage(packageName, parentPackage)
    -- pretty.print(pretty.pretty(manifest))
    local downloadedFiles = {}
    local depenencyFiles = {}
    local packageData = manifest["packages"][packageName]

    if not packageData then
        term.setTextColor(colors.red)
        print("Package '" .. packageName .. "' not found.")
        showAvailablePackages()
        return downloadedFiles
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
            local depDbPackageData = downloadPackage(dependecyName, packageName)
            for _, file in ipairs(depDbPackageData["files"]) do
                table.insert(depenencyFiles, file)
            end

            for _, file in ipairs(depDbPackageData["dependencyFiles"]) do
                table.insert(depenencyFiles, file)
            end
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

            table.insert(downloadedFiles, downloadPath)
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
        term.setTextColor(colors.lime)
        print("Downloaded " .. packageName .. " (" .. packageData["version"] .. ")")
        if packageData["type"] == "program" then
            term.setTextColor(colors.blue)
            local usageCommand = "'" .. packageName .. "'"
            if packageData["usage"] then
                usageCommand = packageData["usage"]
            end
            print("You can run it with " .. usageCommand)
        end
        term.setTextColor(colors.white)
    end

    local db = loadLexiconDb()

    local dbPackageData = {
        version = packageData["version"],
        type = packageData["type"],
        dependencies = packageData["dependencies"],
        files = downloadedFiles,
        dependencyFiles = depenencyFiles,
    }
    db["packages"][packageName] = dbPackageData

    -- pretty.pretty_print(dbPackageData)

    saveLexiconDb(db)

    return dbPackageData
end


---Update all packages in the lexicon database
---@return nil
local function updatePrograms()
    local db = loadLexiconDb()
    for packageName, packageData in pairs(db["packages"]) do
        if packageData["type"] == "program" then
            downloadPackage(packageName)
        end
    end
end


---Return packages that use a file
---@param filePath string
---@return table
local function packagesUsingFile(filePath)
    local db = loadLexiconDb()
    local packageNames = {}
    for packageName, packageData in pairs(db["packages"]) do
        for _, file in ipairs(packageData["files"]) do
            if file == filePath then
                table.insert(packageNames, packageName)
                break
            end
        end

        for _, file in ipairs(packageData["dependencyFiles"]) do
            if file == filePath then
                table.insert(packageNames, packageName)
                break
            end
        end
    end
    return packageNames
end


local function otherPackagesUsingThisOne(packageName)
    local db = loadLexiconDb()
    local packageNames = {}
    for otherPackageName, otherPackageData in pairs(db["packages"]) do
        for _, depName in ipairs(otherPackageData["dependencies"]) do
            if depName == packageName then
                table.insert(packageNames, otherPackageName)
                break
            end
        end
    end
    return packageNames
end


---Delete files that are not used by any package
---@param packageName string
---@param packageFiles table
---@return table
local function deleteUnusedPackageFiles(packageName, packageFiles)
    local deletedFiles = {}
    for _, file in ipairs(packageFiles) do
        if fs.exists(file) then
            local otherPackages = packagesUsingFile(file)

            if #otherPackages == 0 or (#otherPackages == 1 and otherPackages[1] == packageName) then
                fs.delete(file)
                table.insert(deletedFiles, file)
            end
        else
            term.setTextColor(colors.red)
            print("File '" .. file .. "' not found.")
            term.setTextColor(colors.white)
        end
    end

    return deletedFiles
end


---Uninstall a package
---@param packageName string
---@param isParent boolean
---@return table | nil
local function uninstallPackage(packageName, isParent)
    local db = loadLexiconDb()
    local packageData = db["packages"][packageName]

    if packageData then
        if isParent then
            term.setTextColor(colors.blue)
            print("Uninstalling " .. packageName .. " (" .. packageData["version"] .. ")")
            term.setTextColor(colors.white)
        end

        -- Remove the files
        local deletedPackageFiles = deleteUnusedPackageFiles(packageName, packageData["files"])

        -- Remove the package from the database
        if deletedPackageFiles and #deletedPackageFiles > 0 then
            db["packages"][packageName] = nil
        elseif isParent then
            term.setTextColor(colors.red)
            print("Package '" .. packageName .. "' is still in use by the following packages:")
            local otherPackages = otherPackagesUsingThisOne(packageName)
            for _, otherPackageName in ipairs(otherPackages) do
                term.setTextColor(colors.lime)
                print(" - " .. otherPackageName)
            end
            term.setTextColor(colors.white)
            return
        end
        saveLexiconDb(db)

        for _, depName in ipairs(packageData["dependencies"]) do
            local depDeletes = uninstallPackage(depName, false)

            if depDeletes and #depDeletes > 0 then
                term.setTextColor(colors.gray)
                print("Uninstalled " .. depName .. " (unused dep of " .. packageName .. ")")
                term.setTextColor(colors.white)
            end
        end

        if deletedPackageFiles and isParent then
            term.setTextColor(colors.lime)
            print("Uninstalled " .. packageName)
            term.setTextColor(colors.white)
        end

        return deletedPackageFiles
    else
        term.setTextColor(colors.red)
        print("Package '" .. packageName .. "' not found.")
        term.setTextColor(colors.white)
        return
    end
end


local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, { "get", "remove", "upgrade", "list", "list-installed" }, true)
    elseif index == 2 then
        if previous[#previous] == "get" then
            local packageNames = {}
            for packageName, _ in pairs(manifest["packages"]) do
                table.insert(packageNames, packageName)
            end
            return completion.choice(argument, packageNames)
        elseif previous[#previous] == "remove" then
            local db = loadLexiconDb()
            local packageNames = {}
            for packageName, _ in pairs(db["packages"]) do
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
    print("  remove <package> - Uninstall a package")
    print("  upgrade - Update all previously downloaded PROGRAMS (not libraries)")
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
        elseif arg[1] == "remove" then
            if #arg < 2 then
                print("Usage: lexicon remove <package>")
                return
            end

            uninstallPackage(arg[2], true)
        elseif arg[1] == "list" then
            showAvailablePackages()
        elseif arg[1] == "upgrade" then
            updatePrograms()
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
