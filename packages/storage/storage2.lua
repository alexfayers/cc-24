-- Storage management system for computercraft
package.path = package.path .. ";/usr/lib/?.lua"

-- imports

local pretty = require("cc.pretty")
local logging = require("lexicon-lib.lib-logging")

-- Setting config

settings.define("storage2.inputChest", {
    description = "The name of the chest that items are pulled from into the system",
    default = "left",
    type = "string",
})

settings.define("storage2.outputChest", {
    description = "The name of the chest that items are pushed to out of the system",
    default = "right",
    type = "string",
})

-- constants

local logger = logging.getLogger("storage2")

local inputChestName = settings.get("storage2.inputChest")
local inputChest = peripheral.wrap(inputChestName)

if not inputChest then
    error("Input chest not found. You may need to change the inputChest setting (set inputChest {chest name}).")
end

local outputChestName = settings.get("storage2.outputChest")
local outputChest = peripheral.wrap(outputChestName)

if not outputChest then
    error("Output chest not found. You may need to change the outputChest setting (set outputChest {chest name}).")
end

local storageChests = {
    peripheral.find("minecraft:chest", function(name, _)
        return name ~= inputChestName and name ~= outputChestName
    end)
}

if #storageChests == 0 then
    error("No storage chests found. Add more chests to the network!")
end

local storageMap = {}
-- storageMap is a table with keys being the item name and values being a table of tables with the following structure:
-- { chest = peripheral, slot = number, count = number, max = number }

-- functions


---Write a string to a file
---@param path string The path to save the file to
---@param data string The data to write to the file
---@return nil
local function writeToFile(path, data)
    local file = fs.open(path, "w")
    file.write(data)
    file.close()
end

---Populate the storageMap table with all items in the storage chests
---@return nil
local function populateStorageMap()
    logger:info("Creating storage map")
    for chestId, chest in ipairs(storageChests) do
        logger:info("Scanning chest %d", chestId)

        local chestList = chest.list()

        for slot, item in pairs(chestList) do
            if not storageMap[item.name] then
                storageMap[item.name] = {}
            end
            table.insert(storageMap[item.name], {
                chest = chest,
                slot = slot,
                count = item.count,
                max = chest.getItemLimit(slot)
            })
        end

        local emptySlots = {}
        local emptySlotMaxSize = -1

        for slot = 1, chest.size() do
            -- iter over all slots in the chest
            -- if the slot in not found within the chest.list() table, it is empty
            if not chestList[slot] then
                table.insert(emptySlots, slot)
                if emptySlotMaxSize == -1 then
                    emptySlotMaxSize = chest.getItemLimit(slot)
                end
                if not storageMap["empty"] then
                    storageMap["empty"] = {}
                end
                table.insert(storageMap["empty"], {
                    chest = chest,
                    slot = slot,
                    count = 0,
                    max = emptySlotMaxSize
                })
            end
        end
    end
end

---Get all slots in the storageMap that have the item
---@param itemName string
---@return table
local function getAllSlots(itemName)
    return storageMap[itemName] or {}
end

---Get the first slot in the storageMap that has the item
---@param itemName string
---@return table
local function getFirstSlot(itemName)
    local allSlots = getAllSlots(itemName)
    return allSlots and allSlots[1]
end


---Get a list of slots in the storageMap that have the item, up to the count
---@param itemName string
---@param count number
---@return table
local function getSlots(itemName, count)
    local slots = getAllSlots(itemName)
    if not slots then
        return {}
    end

    local result = {}
    local remaining = count
    for _, slot in ipairs(slots) do
        if slot.count <= remaining then
            table.insert(result, slot)
            remaining = remaining - slot.count
        else
            table.insert(result, {
                chest = slot.chest,
                slot = slot.slot,
                count = remaining,
                max = slot.max
            })
            break
        end
    end

    return result
end

---Get the total count of items from a list of slots
---@param slots table
---@return number
local function getTotalCount(slots)
    local total = 0
    for _, slot in ipairs(slots) do
        total = total + slot.count
    end
    return total
end


---Get the total count of a specific item in the storageMap
---@param itemName string
---@return number
local function getTotalItemCount(itemName)
    local slots = getAllSlots(itemName)
    if not slots then
        return 0
    end
    return getTotalCount(slots)
end


---Get the free slots in the storageMap
---@return table
local function getFreeSlots()
    return getAllSlots("empty")
end

---Get the first free slot in the storageMap
---@return table|nil
local function getFirstFreeSlot()
    return getFirstSlot("empty")
end

---Get a list of slots that have space for the item - search for empty slots if necessary
---@param itemName string
---@param count number
---@return table
local function getSlotsWithSpace(itemName, count)
    local slots = getSlots(itemName, count)
    local remaining = count - getTotalCount(slots)
    if remaining > 0 then
        local freeSlots = getSlots("empty", remaining)
        for _, slot in ipairs(freeSlots) do
            table.insert(slots, slot)
        end
    end
    return slots
end

---Push items from the input chest to the storage chests
---@return number
local function pushItems()
    local pushedCount = 0
    for inputSlot, inputItem in pairs(inputChest.list()) do
        local slots = getSlotsWithSpace(inputItem.name, inputItem.count)
        pretty.pretty_print(slots, {ribbon_frac=0.4})
        for _, storageSlot in pairs(slots) do
            -- pretty.pretty_print(slots)
            pushedCount = pushedCount +
                storageSlot.chest.pullItems(
                    inputChestName,
                    inputSlot,
                    inputItem.count, 
                    storageSlot.slot
                )
        end
    end
    return pushedCount
end

---Serialise and save a storageMap to a file. Mainly for debugging purposes.
---@param path string The path to save the file to
---@param map table The storageMap to save
---@return nil
local function saveStorageMap(path, map)
    local file = fs.open(path, "w")
    local noChestMap = {}
    for itemName, slots in pairs(map) do
        if itemName ~= "empty" then
            noChestMap[itemName] = {}
            for _, slot in pairs(slots) do
                table.insert(noChestMap[itemName], {
                    slot = slot.slot,
                    count = slot.count,
                    max = slot.max
                })
            end
        end
    end
    file.write(textutils.serialiseJSON(noChestMap))
    file.close()
end



populateStorageMap()

saveStorageMap("storageMap.json", storageMap)

print(inputChest.setItem(2, { name = "minecraft:dirt", count = 1 }))
-- pretty.pretty_print(inputChest.list())

print(pushItems())

-- pretty.pretty_print(getAllSlots("minecraft:dirt"))
-- pretty.print(pretty.pretty(getFirstSlot("minecraft:dirt")))
print(getTotalItemCount("minecraft:dirt"))
-- local slots = getSlots("minecraft:stone", 128)
-- pretty.print(pretty.pretty(slots))
-- print(getTotalCount(slots))
