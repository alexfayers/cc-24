package.path = package.path .. ";/usr/lib/?.lua"
local logger = require("lexicon-lib.lib-logging").getLogger("storage2.helpers")

---Ensure a wrapped peripheral is an inventory
---@param wrappedPeripheral ccTweaked.peripherals.wrappedPeripheral
---@return ccTweaked.peripherals.Inventory?
local function ensureInventory(wrappedPeripheral)
    if not peripheral.getType(wrappedPeripheral) == "inventory" then
        logger:error("%s is not an inventory. Please use an inventory chest.", wrappedPeripheral)
        return
    end
    ---@type ccTweaked.peripherals.Inventory
    return wrappedPeripheral
end


---Check if a table is empty
---@param table table
---@return boolean
local function tableIsEmpty(table)
    local next = next
    return next(table) == nil
end


---Save a table to a file as json
---@param path string The path to save the file to
---@param data table The data to save
---@return nil
local function saveTable(path, data)
    local file = fs.open(path, "w")
    if not file then
        logger:error("Failed to open file %s for writing", path)
        return
    end
    file.write(textutils.serialiseJSON(data))
    file.close()
end


---Load a table from a file
---@param path string The path to load the file from
---@return table|nil
local function loadTable(path)
    if not fs.exists(path) then
        return nil
    end

    local file = fs.open(path, "r")

    if not file then
        logger:error("Failed to open file %s for reading", path)
        return
    end

    local data = file.readAll()
    file.close()

    if not data then
        logger:error("Failed to read file or the file was empty %s", path)
        return
    end

    local jsonData = textutils.unserialiseJSON(data)

    if not jsonData then
        logger:error("Failed to parse json data from file %s", path)
        return
    end

    return jsonData
end


return {
    ensureInventory = ensureInventory,
    tableIsEmpty = tableIsEmpty,
    saveTable = saveTable,
    loadTable = loadTable,
}
