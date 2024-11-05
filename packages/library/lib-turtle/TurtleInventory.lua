-- Imports
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local tableHelpers = require("lexicon-lib.lib-table")

local pretty = require("cc.pretty")

---This class represents the turtle inventory
---It has a lot of parallels with the Map and MapSlot classes in lib-storage2,
---but is different due to the fact that a turtle inventory is not huge.


local TURTLE_INVENTORY_SLOTS = 16
local TURTLE_MAX_FUEL = 10000
local COMBUSTIBLE_ITEM_IDS_FILE = "/.turtle/combustibleItemIds.json"

---@class slotInfo: ccTweaked.turtle.slotInfoDetailed

---@alias TurtleInventorySlots table<integer, slotInfo?>


---@class TurtleInventory
TurtleInventory = class()

---Initialise the turtle inventory
function TurtleInventory:init()
    ---@type TurtleInventorySlots
    self.slots = {}
    ---@type table<string, boolean>
    self.combustibleItems = {}

    self:updateSlots()
    self:loadCombustibleItems()
end


---Load the combustable item ids
function TurtleInventory:loadCombustibleItems()
    self.combustibleItems = tableHelpers.loadTable(COMBUSTIBLE_ITEM_IDS_FILE) or {}
end


---Save the combustable item ids
---This is done to avoid having to check every item in the turtle inventory
---to see if it's combustible
function TurtleInventory:saveCombustibleItems()
    tableHelpers.saveTable(COMBUSTIBLE_ITEM_IDS_FILE, self.combustibleItems)
end


---Update all the slots in the turtle inventory
---It won't be run that often, so it's fine if it's a bit slow (it's parallel tho)
function TurtleInventory:updateSlots()
    ---@type TurtleInventorySlots
    local newSlots = {}

    ---@type function[]
    local slotTasks = {}

    for i = 1, TURTLE_INVENTORY_SLOTS do
        slotTasks[i] = function()
            local item = turtle.getItemDetail(i, true)
            ---@cast item slotInfo

            if item then
                newSlots[i] = item
            end
        end
    end

    parallel.waitForAll(table.unpack(slotTasks))

    self.slots = newSlots
end


---Scan all the items in the turtle inventory where combustable info isn't known, and update it
function TurtleInventory:scanForCombustibleItems()
    local didAdd = false
    for slot, item in pairs(self.slots) do
        if self.combustibleItems[item.name] == nil then
            turtle.select(slot)
            self.combustibleItems[item.name], _ = turtle.refuel(0)
            didAdd = true
        end
    end

    self:selectFirstSlot()

    if didAdd then
        self:saveCombustibleItems()
    end
end


---Refuel using all of the combustable items in the turtle inventory
---This will only refuel if the turtle is not full
---@return number fuelLevel The fuel level after refueling
function TurtleInventory:refuel()
    local fuelLevel = turtle.getFuelLevel()
    if fuelLevel == "unlimited" then
        return TURTLE_MAX_FUEL
    end
    ---@cast fuelLevel number

    if fuelLevel >= TURTLE_MAX_FUEL then
        return fuelLevel
    end

    self:scanForCombustibleItems()

    for slot, item in pairs(self.slots) do
        if self.combustibleItems[item.name] then
            turtle.select(slot)
            turtle.refuel(TURTLE_MAX_FUEL - fuelLevel)

            fuelLevel = turtle.getFuelLevel()
            ---@cast fuelLevel number

            if fuelLevel >= TURTLE_MAX_FUEL then
                break
            end
        end
    end

    self:selectFirstSlot()

    return fuelLevel
end


---Discard all items with given tags in the turtle inventory
---@param items string[] The tags to discard
---@return boolean, string? _ Whether the items were discarded
function TurtleInventory:discardItems(items)
    for slot, item in pairs(self.slots) do
        for _, trashItem in pairs(items) do
            if tableHelpers.contains(item.tags, trashItem) then
                turtle.select(slot)
                local res, err = turtle.dropUp()
                if not res then
                    return false, err
                end
            end
        end
    end

    self:selectFirstSlot()

    return true
end


---Select the first slot if it's not already selected
---@return boolean _ Whether the slot was selected
function TurtleInventory:selectFirstSlot()
    if turtle.getSelectedSlot() ~= 1 then
        turtle.select(1)
        return true
    end

    return false
end


---Compress the turtle inventory by combining stacks of items
---@return boolean _ Whether the inventory was compressed
function TurtleInventory:compress()
    for slot, item in pairs(self.slots) do
        if not item then
            -- this slot is empty, so skip it because there's nothing to compress
            goto continue
        end

        if turtle.getItemSpace(slot) == 0 then
            -- this slot is full, so skip it because it's already compresses
            goto continue
        end

        for otherSlot, otherItem in pairs(self.slots) do
            if slot ~= otherSlot and item.name == otherItem.name then
                if turtle.getItemSpace(otherSlot) == 0 then
                    -- other slot is full, so we can't compress into it
                    goto continue2
                end

                turtle.select(slot)
                turtle.transferTo(otherSlot)

                self.slots[otherSlot].count = turtle.getItemCount(otherSlot)

                if turtle.getItemCount(slot) == 0 then
                    -- this slot is now empty, so mark it as such
                    -- and break out of the loop, so we can move on to the next slot
                    self.slots[slot] = nil
                    break
                end
                ::continue2::
            end
        end
        ::continue::
    end

    self:selectFirstSlot()

    return true
end


local function test()
    local inv = TurtleInventory()
    inv:refuel()
end
