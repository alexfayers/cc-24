-- Imports
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local tableHelpers = require("lexicon-lib.lib-table")

local pretty = require("cc.pretty")
local logging = require("lexicon-lib.lib-logging")

require("lib-storage2.remote.StorageClient")

---This class represents the turtle inventory
---It has a lot of parallels with the Map and MapSlot classes in lib-storage2,
---but is different due to the fact that a turtle inventory is not huge.


local TURTLE_INVENTORY_SLOTS = 16
local TURTLE_MAX_FUEL = 10000
local COMBUSTIBLE_ITEM_IDS_FILE = "/.turtle/combustibleItemIds.json"
local REMOTE_STORAGE_IO_CHESTS_FILE = "/.turtle/remoteStorageIOChests.json"

---@class slotInfo: ccTweaked.turtle.slotInfoDetailed

---@alias TurtleInventorySlots table<integer, slotInfo?>


---@class TurtleInventory
TurtleInventory = class()

---Initialise the turtle inventory
function TurtleInventory:init()
    self.logger = logging.getLogger("TurtleInventory")

    ---@type TurtleInventorySlots
    self.slots = {}
    ---@type table<string, boolean>
    self.combustibleItems = {}

    ---@type table<string, string>?
    self.remoteStorageIOChests = nil

    ---@type StorageClient?
    self.storageClient = nil

    self:updateSlots()
    self:loadCombustibleItems()
    self:loadRemoteStorageIOChests()
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


---Load the remote storage IO chests
function TurtleInventory:loadRemoteStorageIOChests()
    self.remoteStorageIOChests = tableHelpers.loadTable(REMOTE_STORAGE_IO_CHESTS_FILE) or {}
end


---Save the remote storage IO chests
function TurtleInventory:saveRemoteStorageIOChests()
    tableHelpers.saveTable(REMOTE_STORAGE_IO_CHESTS_FILE, self.remoteStorageIOChests)
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
            else
                newSlots[i] = nil
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

    if didAdd then
        self:saveCombustibleItems()
    end
end


---Refuel using all of the combustable items in the turtle inventory
---This will only refuel if the turtle is not full
---@return boolean If changes were made to the inventory
function TurtleInventory:refuel()
    local fuelLevel = turtle.getFuelLevel()
    if fuelLevel == "unlimited" then
        return false
    end
    ---@cast fuelLevel number

    if fuelLevel >= TURTLE_MAX_FUEL then
        return false
    end

    self:scanForCombustibleItems()

    local madeChanges = false

    for slot, item in pairs(self.slots) do
        if self.combustibleItems[item.name] then
            turtle.select(slot)
            if turtle.refuel(TURTLE_MAX_FUEL - fuelLevel) then
                madeChanges = true
            end

            fuelLevel = turtle.getFuelLevel()
            ---@cast fuelLevel number

            if fuelLevel >= TURTLE_MAX_FUEL then
                break
            end
        end
    end

    return madeChanges
end


---Discard all items with given tags in the turtle inventory.
---Updates the slots table to reflect the changes.
---@param itemNames string[] The names to discard
---@param itemTags string[] The tags to discard
---@param minStackSize? integer The minimum stack size to discard (default 1)
---@return boolean, string? _ Whether the items were discarded
function TurtleInventory:discardItems(itemNames, itemTags, minStackSize)
    if not minStackSize then
        minStackSize = 1
    end

    local madeChanges = false

    for slot, item in pairs(self.slots) do
        for _, trashItem in pairs(itemNames) do
            if item.name == trashItem and item.count >= minStackSize then
                turtle.select(slot)
                local res, err = turtle.dropUp()
                if not res then
                    return false, err
                else
                    self.slots[slot] = nil
                    madeChanges = true
                end
            end
        end

        for _, trashItem in pairs(itemTags) do
            if tableHelpers.contains(item.tags, trashItem) and item.count >= minStackSize then
                turtle.select(slot)
                local res, err = turtle.dropUp()
                if not res then
                    return false, err
                else
                    self.slots[slot] = nil
                    madeChanges = true
                end
            end
        end
    end

    return madeChanges
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


---Compress the turtle inventory by combining stacks of items.
---Updates the slots table to reflect the changes.
---@return boolean _ Whether the inventory was compressed
function TurtleInventory:compress()
    local madeChanges = false
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
                if turtle.transferTo(otherSlot) then
                    madeChanges = true

                    self.slots[otherSlot].count = turtle.getItemCount(otherSlot)
                    local slotCount = turtle.getItemCount(slot)

                    if slotCount == 0 then
                        -- this slot is now empty, so mark it as such
                        -- and break out of the loop, so we can move on to the next slot
                        self.slots[slot] = nil
                        break
                    else
                        -- this slot still has items in it, so update the slot info
                        self.slots[slot].count = slotCount
                    end
                end

                ::continue2::
            end
        end
        ::continue::
    end

    return madeChanges
end


---Attach a storageClient if we're attached to a network with inventories
---@return StorageClient? _ Whether a storageClient was attached
function TurtleInventory:attachStorageClient()
    if self.storageClient then
        return self.storageClient
    end

    if not peripheral.find("modem") then
        return nil
    end

    local storageClient = StorageClient()
    if storageClient.serverId then
        self.storageClient = storageClient

        if not self.remoteStorageIOChests then
            local chestNameRes, chestNames = self.storageClient:callCommand(self.storageClient.getChestNames)
            if chestNameRes then
                self.remoteStorageIOChests = chestNames
                self:saveRemoteStorageIOChests()
            else
                self.logger:error("Failed to get remote chest names!")
            end
        end
        return self.storageClient
    end

    return nil
end


---Detatch the storageClient
---@return boolean _ Whether the storageClient was detatched
function TurtleInventory:detachStorageClient()
    if self.storageClient then
        self.storageClient:closeModem()
        self.storageClient = nil
        return true
    end

    return false
end


---Find inventories in the network. Also attaches a storageClient if we're attached to a network with inventories.
---@return ccTweaked.peripherals.Inventory[]
function TurtleInventory:findInventories()
    local inventories = { peripheral.find("inventory") }

    if not inventories then
        return {}
    end

    -- we're attached to a network with inventories, so probs a storage2
    -- server, so let's try to connect to it
    self:attachStorageClient()

    if self.remoteStorageIOChests then
        for i = #inventories, 1, -1 do
            for _, chest in pairs(self.remoteStorageIOChests) do
                if peripheral.getName(inventories[i]) == chest then
                    table.remove(inventories, i)
                end
            end
        end
    end

    return inventories
end


---Find the local name of the turtle by finding a wired modem and calling getNameLocal on it
---@return string? _ The local name of the turtle
function TurtleInventory:findLocalName()
    local modem = peripheral.find("modem", function (name, wrapped)
        return not wrapped.isWireless()
    end)
    if not modem then
        return
    end
    ---@cast modem ccTweaked.peripherals.WiredModem

    return modem.getNameLocal()
end


---Remote refresh the storage system if there's a storage client
---@return boolean _ Whether the storage system was refreshed
function TurtleInventory:refreshStorage()
    local retryCount = 10
    if self:attachStorageClient() then
        local didRefresh = false
        for _=1, retryCount do
            didRefresh = self.storageClient:callCommand(self.storageClient.refresh)
            if not didRefresh then
                self.logger:error("Failed to refresh storage, trying again")
            else
                self.logger:info("Refreshed remote storage :)")
                break
            end
        end
        if not didRefresh then
            self.logger:error("Failed to refresh storage after %d tries", retryCount)
            return false
        end
    end

    return true
end


---Push the items in the turtle inventory into chests in the network until
---the turtle is empty or the chests are full.
---Updates the slots table to reflect the changes.
---@param keepSlots number[]? A list of slots to keep in the turtle inventory
---@return boolean _ Whether any items were pushed
function TurtleInventory:pushItems(keepSlots)
    if not keepSlots then
        keepSlots = {}
    end
    local madeChanges = false

    local inventories = self:findInventories()

    if tableHelpers.tableIsEmpty(inventories) then
        return false
    end

    local localName = self:findLocalName()

    if not localName then
        return false
    end

    for _, inventory in pairs(inventories) do
        local emptySlots = 0
        ---@type function[]
        local slotTasks = {}

        for slot, item in pairs(self.slots) do
            if tableHelpers.valuesContain(keepSlots, slot) or not item then
                emptySlots = emptySlots + 1
            else
                table.insert(slotTasks, function()
                    local amount = inventory.pullItems(localName, slot)
                    if amount and amount > 0 then
                        self.logger:info("Pushed %d %s", amount, item.displayName, peripheral.getName(inventory))
    
                        self.slots[slot].count = turtle.getItemCount(slot)
                        if self.slots[slot].count <= 0 then
                            self.slots[slot] = nil
                        end
    
                        madeChanges = true
                    end
                end)
            end
            ::continue::
        end

        if emptySlots == TURTLE_INVENTORY_SLOTS then
            break
        end

        parallel.waitForAll(table.unpack(slotTasks))
    end

    if madeChanges then
        self:updateSlots()
        self:refreshStorage()
    end

    return madeChanges
end


---Pull an item from the network into the turtle inventory
---@param itemName string The name of the item to pull
---@param amount integer The amount of the item to pull
---@param toSlot? integer The slot to pull the item into (default first empty slot)
---@return boolean, number? _ Whether the item was pulled and how many were pulled
function TurtleInventory:pullItems(itemName, amount, toSlot)
    if not self:attachStorageClient() then
        return false
    end

    local localName = self:findLocalName()

    if not localName then
        return false
    end

    local pullRes, pullData = self.storageClient:pull(localName, itemName, amount, toSlot)

    if pullRes and pullData and pullData.count > 0 then
        -- self.logger:info("Pulled %d %s", pullData.count, itemName)
        self:updateSlots()
        return true, pullData.count
    else
        -- self.logger:warn("Failed to pull %s", itemName)
        return false
    end
end


---Pull fuel from chests in the network into the turtle inventory and use it to refuel the turtle until a target fuel level is reached or the chests no longer have fuel in them.
---@param targetFuelLevel integer The target fuel level to reach
---@param fuelTags table<string, integer>? The tags of the fuel items to pull (default {"c:coal"})
---@return boolean, number? _ Whether the turtle was refueled and what the fuel level is after refueling
function TurtleInventory:pullFuel(targetFuelLevel, fuelTags)
    if not fuelTags then
        fuelTags = {
            ["c:coal"] = 80,
            ["c:rods/blaze"] = 120,
            ["c:coal_block"] = 800,
        }
    end

    local fuelLevel = turtle.getFuelLevel()
    if fuelLevel == "unlimited" then
        return false, TURTLE_MAX_FUEL
    end
    ---@cast fuelLevel number

    if fuelLevel >= targetFuelLevel then
        return false, fuelLevel
    end

    if not self:attachStorageClient() then
        return false, fuelLevel
    end

    local madeChanges = false

    local localName = self:findLocalName()

    if not localName then
        return false, fuelLevel
    end
    
    for fuelTag, fuelGain in pairs(fuelTags) do
        local targetSlot = self:findNonFullSlot(fuelTag) or self:findEmptySlot()
    
        if not targetSlot then
            self.logger:warn("Not enough space to pull %s", fuelTag)
            goto continue
        end

        local targetAmount = math.ceil((targetFuelLevel - fuelLevel) / fuelGain)
        if targetAmount <= 0 then
            return true
        end

        local pullRes, pullData = self.storageClient:pull(localName, "#" .. fuelTag, targetAmount, targetSlot)

        if pullRes and pullData and pullData.count > 0 then
            self.logger:info("Pulled %d %s", pullData.count, fuelTag)
            turtle.select(targetSlot)
            turtle.refuel()

            madeChanges = true
            fuelLevel = turtle.getFuelLevel()
            ---@cast fuelLevel number
    
            if fuelLevel >= targetFuelLevel then
                break
            end
        else
            self.logger:warn("Failed to pull %s", fuelTag)
        end

        ::continue::
    end

    if madeChanges then
        self:updateSlots()
    end

    return madeChanges, fuelLevel
end


---Check if all slots in there turtle inventory are being used (or a specific count of slots are full)
---@param count? integer The number of slots to check (default all)
---@return boolean _ Whether all slots are full
function TurtleInventory:isFull(count)
    if not count then
        count = TURTLE_INVENTORY_SLOTS
    end

    for i = 1, count do
        if not self.slots[i] then
            return false
        end
    end

    return true
end


---Find an item in the turtle inventory. Can also be a tag.
---@param search string The name of the item to find
---@return table<number, slotInfo> _ The slot number and the slot info of the items
function TurtleInventory:findItems(search)
    local slots = {}
    for slotNumber, item in pairs(self.slots) do
        if item.name == search or tableHelpers.contains(item.tags, search) then
            slots[slotNumber] = item
        end
    end

    return slots
end


---Select the first slot with a specific item in it
---@param search string The name of the item to find
---@return boolean _ Whether the slot was selected
function TurtleInventory:selectItem(search)
    local slots = self:findItems(search)
    local slot = next(slots)
    if slot then
        turtle.select(slot)
        return true
    end

    return false
end


---Find an empty slot in the turtle inventory
---@return number? _ The slot number of the empty slot
function TurtleInventory:findEmptySlot()
    for slotNumber = 1, TURTLE_INVENTORY_SLOTS do
        if not self.slots[slotNumber] then
            return slotNumber
        end
    end

    return nil
end


---Find first non full slot in the turtle inventory with a specific item in it
---@param search string The name of the item to find
---@return number? _ The slot number of the non full slot
function TurtleInventory:findNonFullSlot(search)
    local slots = self:findItems(search)
    for slotNumber, item in pairs(slots) do
        if item.count < item.maxCount then
            return slotNumber
        end
    end

    return nil
end


---Remove a count of the selected slot from the turtle inventory
---@param count integer The number of items to remove
---@param slot? number The slot to remove from (default selected slot)
---@return boolean _ Whether the items were removed
function TurtleInventory:removeItems(count, slot)
    if not slot then
        slot = turtle.getSelectedSlot()
    end

    if not self.slots[slot] then
        return false
    end

    if self.slots[slot].count < count then
        return false
    end

    self.slots[slot].count = turtle.getItemCount(slot)

    if self.slots[slot].count <= 0 then
        self.slots[slot] = nil
    end

    return true
end


local function test()
    local inv = TurtleInventory()
    inv:refuel()
end
