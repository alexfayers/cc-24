package.path = package.path .. ";/usr/lib/?.lua"

require("lib-storage2.Constants")

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


---Filter a table using a function
---@param tbl table The table to filter
---@param filter function The function to use to filter the table (takes an item and returns a boolean)
---@return table
local function filterTable(tbl, filter)
    local filtered = {}
    for _, item in ipairs(tbl) do
        if filter(item) then
            table.insert(filtered, item)
        end
    end
    return filtered
end


---Run the list function for a chest, but retry if it fails
---@param chest ccTweaked.peripherals.Inventory The chest to list
---@return table<number, ccTweaked.peripherals.inventory.item>?
local function chestListRetry(chest)
    local attempts = 0

    ::retry::
    local chestList = chest.list()
    if not chestList then
        attempts = attempts + 1
        if attempts >= Constants.MAX_METHOD_RETRIES then
            logger:error("Failed to list chest %s after %d attempts", chest, Constants.MAX_METHOD_RETRIES)
            return
        end
        goto retry
    end
    return chestList
end


---Run the getItemDetail function for a chest, but retry if it fails
---@param chest ccTweaked.peripherals.Inventory The chest to get the item from
---@param slot number The slot to get the item from
---@return ChestGetItemDetailItem|nil
local function chestGetItemDetailRetry(chest, slot)
    local attempts = 0

    ::retry::
    local itemDetail = chest.getItemDetail(slot)
    if not itemDetail then
        attempts = attempts + 1
        if attempts >= Constants.MAX_METHOD_RETRIES then
            logger:error("Failed to get item detail for slot %d in chest %s after %d attempts", slot, chest, Constants.MAX_METHOD_RETRIES)
            return
        end
        goto retry
    end
    return itemDetail
end


---Run the pullItems function for a chest, but retry if it returns nil
---@param chest ccTweaked.peripherals.Inventory The chest to pull items from
---@param sourceName string The name of the chest to pull items from
---@param sourceSlot number The slot to pull items from
---@param limit? number The maximum number of items to move
---@param targetSlot? number The slot to push the items into
---@return number|nil quantity The number of items transferred
local function chestPullItemsRetry(chest, sourceName, sourceSlot, limit, targetSlot)
    local attempts = 0

    ::retry::
    local pcallRes, quantity = pcall(chest.pullItems, sourceName, sourceSlot, limit, targetSlot)
    if not pcallRes or not quantity then
        attempts = attempts + 1
        if attempts >= Constants.MAX_METHOD_RETRIES then
            logger:error("Failed to pull items from %s in slot %d in chest %s after %d attempts", sourceName, sourceSlot, peripheral.getName(chest), Constants.MAX_METHOD_RETRIES)
            return
        end
        goto retry
    end
    return quantity
end


---Run the pushItems function for a chest, but retry if it returns nil
---@param chest ccTweaked.peripherals.Inventory The chest to push items to
---@param toName string The name of the chest to push items to
---@param sourceSlot number The slot to push items from
---@param limit? number The maximum number of items to move
---@param targetSlot? number The slot to push the items into
---@return number|nil quantity The number of items transferred
local function chestPushItemsRetry(chest, toName, sourceSlot, limit, targetSlot)
    local attempts = 0

    ::retry::
    local pcallRes, quantity = pcall(chest.pushItems, toName, sourceSlot, limit, targetSlot)
    if not pcallRes or not quantity then
        attempts = attempts + 1
        if attempts >= Constants.MAX_METHOD_RETRIES then
            logger:error("Failed to push items to %s in slot %d in chest %s after %d attempts", toName, sourceSlot, peripheral.getName(chest), Constants.MAX_METHOD_RETRIES)
            return
        end
        goto retry
    end
    return quantity
end


---Sort a table by key (or by a custom order function)
---From https://stackoverflow.com/questions/15706270/sort-a-table-in-lua
---@param t table The table to sort
---@param order? function The order function to use
---@return function
local function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end



return {
    ensureInventory = ensureInventory,
    tableIsEmpty = tableIsEmpty,
    saveTable = saveTable,
    loadTable = loadTable,
    filterTable = filterTable,
    chestListRetry = chestListRetry,
    chestGetItemDetailRetry = chestGetItemDetailRetry,
    chestPullItemsRetry = chestPullItemsRetry,
    chestPushItemsRetry = chestPushItemsRetry,
    spairs = spairs,
}
