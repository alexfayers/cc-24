-- The main lexicon program.
-- From here, you can access all of lexicon's subprograms!

local completion = require("cc.completion")

local MANIFEST_URL = "https://raw.githubusercontent.com/alexfayers/cc-24/main/lexicon/lexicon-db.json"

-- local pretty = require("cc.pretty")

---Add a token to the end of a URL to prevent caching
---@param url string
---@return string
local function addTokenToUrl(url)
    return url .. "?token=" .. os.epoch("utc")
end

---Get the latest manifest from the lexicon repository
---@return table
local function getLatestManifest()
    -- use a token to prevent caching
    ---@diagnostic disable-next-line: undefined-field
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
    for packageName, _ in pairs(manifest["packages"]) do
        print(" - " .. packageName)
    end
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

            -- ensure that the directory exists
            local downloadDirectory = fs.getDir(downloadPath)
            fs.makeDir(downloadDirectory)

            local file = fs.open(downloadPath, "w")
            file.write(fileContents)
            file.close()
        else
            error("Failed to download file")
        end
    end

    if not parentPackage then
        term.setTextColor(colors.lime)
        print("Downloaded " .. packageName .. " (" .. packageData["version"] .. ")")
        term.setTextColor(colors.white)
    end

    -- Check if the program path is set
    if packageData["program-path"] then
        local globalPath = shell.path()
        local path = packageData["program-path"]
        if not globalPath:find(path, 1, true) then
            shell.setPath(globalPath .. ":" .. path)
        end
        -- term.setTextColor(colors.grey)
        -- print("Added " .. packageName .. " to the shell path")
        -- term.setTextColor(colors.white)
    end
end


local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, { "get", "list" }, true)
    end
end

local function usage()
    print("Usage: lexicon <command>")
    print("Commands:")
    print("  get <package> - Download a package from the lexicon repository")
    print("  list - List all available packages")
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

            downloadPackage(arg[2], nil)
        elseif arg[1] == "list" then
            showAvailablePackages()
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
