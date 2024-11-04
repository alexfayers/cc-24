-- Imports
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("storage2.lib.MapSlot")
require("storage2.lib.ItemDetailCache")

local helpers = require("storage2.lib.helpers")

local logger = require("lexicon-lib.lib-logging").getLogger("storage2.Map")

-- types

---@alias MapTable table<string, MapSlot[]>


-- Class definition

---@class Map
---@overload fun(chests: ccTweaked.peripherals.Inventory[], mapTable?: MapTable): Map
Map = class()

---Properties

Map.saveFilename = settings.get("storage2.storageFile")
Map.detailMapFilename = settings.get("storage2.itemDetailCacheFile")

---Initialise a new Map
---@param chests ccTweaked.peripherals.Inventory[] The chests to use for the map
function Map:init(chests)
    self.chests = chests
    ---@type MapTable
    self.mapTable = {}

    self:populate()
end


---Add a new slot
---@param slot MapSlot The slot to add
function Map:addSlot(slot)
    if not self.mapTable[slot.name] then
        self.mapTable[slot.name] = {}
    end
    table.insert(self.mapTable[slot.name], slot)
end


---Delete a slot list
---@param name string The name of the item
function Map:deleteSlotList(name)
    self.mapTable[name] = nil
end


---Add a new empty slot
---@param chest ccTweaked.peripherals.Inventory The chest that the slot is in
---@param slotNumber number The slot number
function Map:addSlotEmpty(chest, slotNumber)
    self:addSlot(MapSlot.empty(chest, slotNumber))
end


---Remove a slot
---@param slot MapSlot The slot to remove
function Map:removeSlot(slot)
    local slots = self:getItemSlots(slot.name)
    for i, s in ipairs(slots) do
        if s.chest == slot.chest and s.slot == slot.slot then
            table.remove(slots, i)
            return
        end
    end
end


---Get the items that match a search (ignoring empty slots ofc)
---@param search string The regex to search for
---@return string[]
function Map:searchItemNames(search)
    local results = {}
    for itemName, _ in pairs(self.mapTable) do
        if itemName ~= MapSlot.EMPTY_SLOT_NAME and string.match(itemName, search) then
            table.insert(results, itemName)
        end
    end
    return results
end


---Get the slots that contain a specific item
---@param name string The name of the item
---@return MapSlot[]
function Map:getItemSlots(name)
    return self.mapTable[name] or {}
end


---Get the slots that contain an item that matches a search (ignoring empty slots ofc)
---@param search string The regex to search for
---@return MapSlot[]
function Map:getItemSlotsBySearch(search)
    local results = {}
    local itemNames = self:searchItemNames(search)

    for _, itemName in ipairs(itemNames) do
        for _, slot in ipairs(self:getItemSlots(itemName)) do
            table.insert(results, slot)
        end
    end
    return results
end


---Get the slots that match a name and a filter function
---@param name string The name of the item
---@param filter function The filter function (takes a MapSlot and returns a boolean)
---@return MapSlot[]
function Map:getItemSlotsFiltered(name, filter)
    return helpers.filterTable(self:getItemSlots(name), filter)
end


---Get the slots that have space for a specific item
---@param name string The name of the item
---@return MapSlot[]
function Map:getItemSlotsWithSpace(name)
    ---@param slot MapSlot
    ---@return boolean
    local function isFullFilter(slot)
        return slot.isFull == false
    end

    local slots = self:getItemSlotsFiltered(name, isFullFilter)

    for _, slot in ipairs(self:getItemSlots("empty")) do
        table.insert(slots, slot)
    end

    return slots
end


---Get the total count of items in a list of slots
---@param slots MapSlot[] The slots to count
---@return number
function Map.getTotalCount(slots)
    local count = 0
    for _, slot in ipairs(slots) do
        count = count + slot.count
    end
    return count
end


---Get the total maxCount of items in a list of slots
---@param slots MapSlot[] The slots to count
---@return number
function Map.getTotalMaxCount(slots)
    local count = 0
    for _, slot in ipairs(slots) do
        count = count + slot.maxCount
    end
    return count
end


---Get the total count of a specific item
---@param name string The name of the item
---@param fuzzy? boolean Whether to use fuzzy matching for the item name
---@return number
function Map:getTotalItemCount(name, fuzzy)
    local slots = self:getItemSlots(name)

    if fuzzy and helpers.tableIsEmpty(slots) then
        slots = self:getItemSlotsBySearch(name)
    end

    return self.getTotalCount(slots)
end


---Get a list of all name stubs in the map
---@return string[]
function Map:getAllItemStubs()
    local itemStubs = {}
    for name, _ in pairs(self.mapTable) do
        if name ~= MapSlot.EMPTY_SLOT_NAME then
            table.insert(itemStubs, MapSlot.getNameStub(name))
        end
    end
    return itemStubs
end


---Get all slots in the map
---@return MapSlot[]
function Map:getAllSlots()
    local slots = {}
    for _, slotList in pairs(self.mapTable) do
        for _, slot in ipairs(slotList) do
            table.insert(slots, slot)
        end
    end
    return slots
end


---Get full slots in the map
---@return MapSlot[]
function Map:getFullSlots()
    ---@param slot MapSlot
    ---@return boolean
    local isFullFilter = function(slot)
        return slot.isFull
    end

    return helpers.filterTable(self:getAllSlots(), isFullFilter)
end


---Clear the current map
function Map:clear()
    self.mapTable = {}
end


---Populate the map with the items in the chests
function Map:populate()
    if self:load() then
        return
    end

    logger:warn("Populating storage map")
    self:clear()

    local itemDetailCache = ItemDetailCache(self.detailMapFilename)

    for _, chest in ipairs(self.chests) do
        local chestList = helpers.chestListRetry(chest)

        if not chestList then
            goto continue
        end

        for slotNumber = 1, chest.size() do
            local item = chestList[slotNumber]
            if item then
                local slotDetails = itemDetailCache:getItemDetail(chest, slotNumber, item.name)

                if not slotDetails then
                    goto continue2
                end

                self:addSlot(MapSlot(
                    slotDetails.name,
                    chest,
                    slotNumber,
                    item.count,
                    slotDetails.maxCount,
                    nil,
                    slotDetails.tags
                ))
            else
                self:addSlotEmpty(chest, slotNumber)
            end

            ::continue2::
        end

        ::continue::
    end
end


---Save the map to a file
function Map:save()
    local serialized = {}

    for name, slots in pairs(self.mapTable) do
        serialized[name] = {}
        for _, slot in ipairs(slots) do
            table.insert(serialized[name], slot:serialize())
        end
    end

    helpers.saveTable(self.saveFilename, serialized)
end


---Load the map from a file
---@return boolean _ Whether the map was loaded successfully
function Map:load()
    ---@type SerializedMap?
    local serialized = helpers.loadTable(self.saveFilename)

    if not serialized then
        return false
    end

    self:clear()

    for _, slots in pairs(serialized) do
        for _, slot in ipairs(slots) do
            local unserialisedSlot = MapSlot.unserialize(slot)
            if not unserialisedSlot then
                logger:error("Failed to unserialize slot")
                goto continue
            end

            self:addSlot(unserialisedSlot)
            ::continue::
        end
    end

    return true
end


---Push all items from an input chest to the storage chests, updating the map as needed
---@param inputChest ccTweaked.peripherals.Inventory The chest to push items from
function Map:push(inputChest)
    local totalPushedCount = 0
    local totalExpectedPushedCount = 0
    local inputChestName = peripheral.getName(inputChest)

    local itemDetailCache = ItemDetailCache(self.detailMapFilename)

    local inputChestList = helpers.chestListRetry(inputChest)

    if not inputChestList then
        return
    end

    for inputSlot, inputItem in pairs(inputChestList) do
        logger:debug("Pushing %s, slot %s", inputItem.name, inputSlot)
        local inputItemPushedCount = 0

        local availableSlots = self:getItemSlotsWithSpace(inputItem.name)

        totalExpectedPushedCount = totalExpectedPushedCount + inputItem.count

        for _, slot in ipairs(availableSlots) do
            logger:debug("Pushing %d %s to slot %d in chest %s", inputItem.count, inputItem.name, slot.slot, slot.chestName)
            local quantity = helpers.chestPushItemsRetry(
                inputChest,
                slot.chestName,
                inputSlot,
                inputItem.count,
                slot.slot
            )

            if not quantity then
                slot:markFull()
                goto continue
            end

            if quantity == 0 then
                -- If we've pushed 0 items, the slot is probs full
                -- TODO: update maxItems if this happens?
                -- NOTE: Most likely this is because of a custom name - maybe store readable names in the map?
                -- That'd make things much slower though, maybe.
                slot:markFull()
            else
                -- pushed at least one item, update the map
                if slot.name == MapSlot.EMPTY_SLOT_NAME then
                    -- slot was empty, update this to the new item
                    local slotDetails = itemDetailCache:getItemDetail(slot.chest, slot.slot, inputItem.name)
                    if not slotDetails then
                        goto continue
                    end

                    self:addSlot(MapSlot(
                        slotDetails.name,
                        slot.chest,
                        slot.slot,
                        quantity,
                        slotDetails.maxCount,
                        nil,
                        slotDetails.tags
                    ))
                    self:removeSlot(slot)
                else
                    -- slot was not empty, update the count
                    slot:addCount(quantity)
                end
            end

            inputItemPushedCount = inputItemPushedCount + quantity
            totalPushedCount = totalPushedCount + quantity

            if totalPushedCount >= totalExpectedPushedCount then
                break
            end

            ::continue::
        end
    end

    if totalPushedCount < totalExpectedPushedCount then
        logger:error("Only pushed %d/%d items", totalPushedCount, totalExpectedPushedCount)
    else
        logger:info("Pushed %d/%d items", totalPushedCount, totalExpectedPushedCount)
    end
end


---Pull items from the storage chests to the output chest, updating the map as needed
---@param outputChest ccTweaked.peripherals.Inventory The chest to pull items to
---@param itemName string The name of the item to pull
---@param amount number The amount of the item to pull
---@param fuzzy boolean Whether to use fuzzy matching for the item name
function Map:pull(outputChest, itemName, amount, fuzzy)
    local totalPulledCount = 0
    local totalExpectedPulledCount = amount
    local outputChestName = peripheral.getName(outputChest)

    local slots = self:getItemSlots(itemName)

    if fuzzy and helpers.tableIsEmpty(slots) then
        -- didn't have an exact match, and we're using fuzzy matching so search
        slots = self:getItemSlotsBySearch(itemName)
    end

    ---@type MapSlot[]
    local mapRemovals = {}

    for _, slot in ipairs(slots) do
        logger:debug("Pulling %d %s from slot %d in chest %s", amount, slot.name, slot.slot, slot.chestName)
        local quantity = helpers.chestPullItemsRetry(
            outputChest,
            slot.chestName,
            slot.slot,
            totalExpectedPulledCount - totalPulledCount
        )

        if not quantity then
            table.insert(mapRemovals, slot)
            goto continue
        end

        if quantity == 0 then
            -- If we've pulled 0 items, the slot is probs empty
            table.insert(mapRemovals, slot)
        else
            -- pulled at least one item, update the map
            slot:addCount(-quantity)

            if slot.count == 0 then
                -- slot is now empty, mark it as such
                table.insert(mapRemovals, slot)
            end
        end

        totalPulledCount = totalPulledCount + quantity

        if totalPulledCount >= totalExpectedPulledCount then
            break
        end

        ::continue::
    end

    if totalPulledCount < totalExpectedPulledCount then
        logger:warn("Only pulled %d/%d items", totalPulledCount, totalExpectedPulledCount)
    else
        logger:info("Pulled %d/%d items", totalPulledCount, totalExpectedPulledCount)
    end

    for _, slot in ipairs(mapRemovals) do
        self:addSlotEmpty(slot.chest, slot.slot)
        self:removeSlot(slot)

        if self:getTotalItemCount(itemName) == 0 then
            self:deleteSlotList(itemName)
        end
    end
end