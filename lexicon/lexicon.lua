-- The main lexicon program.
-- From here, you can access all of lexicon's subprograms!

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


---Download a package from the lexicon repository
---@param packageName string The name of the package to download
---@param parentPackage string | nil The name of the parent package
local function downloadPackage(packageName, parentPackage)
    -- pretty.print(pretty.pretty(manifest))
    local packageData = manifest["packages"][packageName]

    if not packageData then
        error("Package '" .. packageName .. "' not found")
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


-- Download package-example as a test
downloadPackage("package-example", nil)
