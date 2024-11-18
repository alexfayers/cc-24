package.path = package.path .. ";/usr/lib/?.lua"

require("lib-storage2.Constants")

local logger = require("lexicon-lib.lib-logging").getLogger("storage2.helpers")

---Ensure a wrapped peripheral is an inventory
---@param wrappedPeripheral ccTweaked.peripherals.wrappedPeripheral
---@return ccTweaked.peripherals.Inventory?
local function ensureInventory(wrappedPeripheral)
---@diagnostic disable-next-line: param-type-mismatch
    if not peripheral.hasType(wrappedPeripheral, "inventory") and not peripheral.hasType(wrappedPeripheral, "turtle") then
        logger:error("%s is not an inventory. Please use an inventory chest.", wrappedPeripheral)
        return
    end
    ---@type ccTweaked.peripherals.Inventory
    return wrappedPeripheral
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
            logger:error("Failed to list chest %s after %d attempts", peripheral.getName(chest), Constants.MAX_METHOD_RETRIES)
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
            logger:error("Failed to get item detail for slot %d in chest %s after %d attempts", slot, peripheral.getName(chest), Constants.MAX_METHOD_RETRIES)
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
    if not pcallRes or quantity ~ nil then
        attempts = attempts + 1
        if attempts >= Constants.MAX_METHOD_RETRIES then
            logger:error("Failed to pull items from %s in slot %d to chest %s after %d attempts", sourceName, sourceSlot, peripheral.getName(chest), Constants.MAX_METHOD_RETRIES)
            return
        end
        goto retry
    end
    return quantity
end


---Run the pushItems function for a chest, but retry if it returns nil
---@param chest ccTweaked.peripherals.Inventory The chest to push items from
---@param toName string The name of the chest to push items to
---@param sourceSlot number The slot to push items from
---@param limit? number The maximum number of items to move
---@param targetSlot? number The slot to push the items into
---@return number|nil quantity The number of items transferred
local function chestPushItemsRetry(chest, toName, sourceSlot, limit, targetSlot)
    local attempts = 0

    ::retry::
    local pcallRes, quantity = pcall(chest.pushItems, toName, sourceSlot, limit, targetSlot)
    if not pcallRes or quantity ~ nil then
        attempts = attempts + 1
        if attempts >= Constants.MAX_METHOD_RETRIES then
            logger:error("Failed to push items to %s in slot %d in chest %s after %d attempts", toName, sourceSlot, peripheral.getName(chest), Constants.MAX_METHOD_RETRIES)
            return
        end
        goto retry
    end
    return quantity
end


return {
    ensureInventory = ensureInventory,
    chestListRetry = chestListRetry,
    chestGetItemDetailRetry = chestGetItemDetailRetry,
    chestPullItemsRetry = chestPullItemsRetry,
    chestPushItemsRetry = chestPushItemsRetry,
}
