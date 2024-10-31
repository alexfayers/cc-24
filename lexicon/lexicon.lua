-- The main lexicon program.
-- From here, you can access all of lexicon's subprograms!

local MANIFEST_URL = "https://raw.githubusercontent.com/alexfayers/lexicon/main/lexicon/lexicon-db.json"

---Get the latest manifest from the lexicon repository
---@return table
local function getLatestManifest()
    local request = http.get(MANIFEST_URL)
    if request then
        local manifest = textutils.unserialiseJSON(request.readAll())
        request.close()
        return manifest
    end

    error("Failed to get latest manifest")
end


---Download a package from the lexicon repository
---@param packageName string The name of the package to download
local function downloadPackage(packageName)
    local manifest = getLatestManifest()
    local packageData = manifest[packageName]

    if not packageData then
        error("Package not found")
    end

    print("Downloading " .. packageName .. " (version " .. packageData["version"] .. ")...")

    local packageDependencies = packageData["dependencies"]
    if packageDependencies then
        print("Found " .. #packageDependencies .. " dependencies, downloading them first...")
        for dependencyName, _ in pairs(packageDependencies) do
            downloadPackage(dependencyName)
        end
    end

    local packageFiles = packageData["files"]
    -- files are an array of {url, downloadPath}
    for _, file in ipairs(packageFiles) do
        local sourceUrl = file[1]
        local downloadPath = file[2]

        local request = http.get(sourceUrl)
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
end


-- Download package-example as a test
print("Downloading package-example!")
downloadPackage("package-example")
