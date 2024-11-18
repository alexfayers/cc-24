-- Imports
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")
require("lib-storage2.Constants")

local helpers = require("lib-storage2.helpers")
local pretty = require("cc.pretty")

-- types

---@alias SerializedMapSlotTable {name: string, chestName: string, slot: number, count: number, maxCount: number, isFull: boolean, tags: table<string, boolean>, displayName?: string}
---@alias SerializedMap table<string, SerializedMapSlotTable[]> The serialized storage map


-- Class definition

---@class MapSlot
---@overload fun(name: string, chest: ccTweaked.peripherals.Inventory, slot: number, count: number, maxCount: number, isFull?: boolean, tags?: table<string, boolean>, displayName?: string): MapSlot
MapSlot = class()

---Properties

MapSlot.EMPTY_SLOT_NAME = "empty"

---Initialise a new MapSlot
---@param name string The name of the item
---@param chest ccTweaked.peripherals.Inventory The chest that the slot is in
---@param slot number The slot number
---@param count number The number of items in the slot
---@param maxCount number The maximum number of items that can be in the slot
---@param isFull boolean Whether the slot is full or not
---@param tags table<string, boolean>|nil The tags of the item
---@param displayName? string The readable name of the item
function MapSlot:init(name, chest, slot, count, maxCount, isFull, tags, displayName)
    self.name = name
    self.chest = chest
    self.chestName = peripheral.getName(chest)
    self.slot = slot
    self.count = count
    self.maxCount = maxCount
    self.isFull = isFull or self:calcIsFull()
    self.tags = self.ensureUniqueTags(tags or {})
    self.displayName = displayName
end


---Get the name stub for the slot
---@return string
function MapSlot.getNameStub(name)
    return string.match(name, ".+:(.+)")
end


---Convert an item name stub to a full name
---@param nameStub string The name stub
---@return string
function MapSlot.fullNameFromNameStub(nameStub)
    if string.find(nameStub, ":") then
        return nameStub
    end

    return string.format("%s:%s", Constants.ITEM_NAMESPACE, nameStub)
end

---Ensure that a table of tags only has unique keys to prevent serialisation issues
---@param tags ChestGetItemDetailItemTags The table of tags
---@return ChestGetItemDetailItemTags
function MapSlot.ensureUniqueTags(tags)
    -- TODO: figure out why tf this is necessary
    local uniqueTags = {}
    for tag, _ in pairs(tags) do
        uniqueTags[tag] = true
    end
    return uniqueTags
end

---Create an empty slot
---@param chest ccTweaked.peripherals.Inventory The chest that the slot is in
---@param slot number The slot number
---@return MapSlot
function MapSlot.empty(chest, slot)
    return MapSlot(MapSlot.EMPTY_SLOT_NAME, chest, slot, 0, Constants.CHEST_SLOT_MAX, false)
end

---Increase the count of the slot by a given amount
---@param amount number The amount to increase the count by
function MapSlot:addCount(amount)
    self.count = self.count + amount
    self:updateIsFull()
end

---Calculate if the slot is full
---@return boolean
function MapSlot:calcIsFull()
    return self.count >= self.maxCount
end

---Check if the slot is full
---@return nil
function MapSlot:updateIsFull()
    self.isFull = self:calcIsFull()
end

---Mark a slot as full
---@return nil
function MapSlot:markFull()
    self.isFull = true
end

---Mark a slot as not full
---@return nil
function MapSlot:markNotFull()
    self.isFull = false
end


---Enrich a slot by using the item details function (meant to be called as a parallel task because it's slow)
---@return nil
function MapSlot:enrich()
    if self.displayName ~= nil then
        -- we've already enriched this slot
        return
    end

    local itemDetail = helpers.chestGetItemDetailRetry(self.chest, self.slot)

    if not itemDetail then
        return
    end

    self.maxCount = itemDetail.maxCount
    self.displayName = itemDetail.displayName
    self.tags = self.ensureUniqueTags(itemDetail.tags)

    self:updateIsFull()
end

---Serialize the slot
---@return SerializedMapSlotTable
function MapSlot:serialize()
    return {
        name = self.name,
        chestName = peripheral.getName(self.chest),
        slot = self.slot,
        count = self.count,
        maxCount = self.maxCount,
        isFull = self.isFull,
        tags = self.tags,
        displayName = self.displayName,
    }
end

---Unserialize the slot
---@param data SerializedMapSlotTable The serialized slot
---@return MapSlot?
function MapSlot.unserialize(data)
    local wrappedPeripheral = peripheral.wrap(data.chestName); if not wrappedPeripheral then return end
    local wrappedChest = helpers.ensureInventory(wrappedPeripheral); if not wrappedChest then return end

    return MapSlot(
        data.name,
        wrappedChest,
        data.slot,
        data.count,
        data.maxCount,
        data.isFull,
        data.tags,
        data.displayName
    )
end
