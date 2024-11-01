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

local SAVE_EMPTY_SLOTS = false
local CHEST_SLOT_MAX = 64

local logger = logging.getLogger("storage2")
logger:setLevel(logging.LEVELS.DEBUG)

local inputChestName = settings.get("storage2.inputChest")
local inputChest = peripheral.wrap(inputChestName)

if not inputChest then
    logger:error("Input chest not found. You may need to change the inputChest setting (set inputChest {chest name}).")
    return
end

local outputChestName = settings.get("storage2.outputChest")
local outputChest = peripheral.wrap(outputChestName)

if not outputChest then
    logger:error("Output chest not found. You may need to change the outputChest setting (set outputChest {chest name}).")
    return
end

local storageChests = {
    peripheral.find("minecraft:chest", function(name, _)
        return name ~= inputChestName and name ~= outputChestName
    end)
}

if #storageChests == 0 then
    logger:error("No storage chests found. Add more chests to the network!")
    return
end

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


---Populate empty slots in the storageMap
---@param map table The storageMap to populate
---@return table
local function populateEmptySlots(map)
    logger:debug("Populating empty slots")
    for chestId, chest in ipairs(storageChests) do
        logger:debug("Processing chest %d", chestId)
        local chestName = peripheral.getName(chest)

        for slot = 1, chest.size() do
            -- iter over all slots in the chest
            -- if the slot is not found within the chest.list() table, it is empty
            local found = false
            for _, slots in pairs(map) do
                for _, storageSlot in pairs(slots) do
                    if peripheral.getName(storageSlot.chest) == chestName and storageSlot.slot == slot then
                        found = true
                        break
                    end
                end
            end
            if not found then
                if not map["empty"] then
                    map["empty"] = {}
                end
                table.insert(map["empty"], {
                    chest = chest,
                    slot = slot,
                    count = 0,
                    isFull = false,
                })
            end
        end
    end
    return map
end


---Populate the storageMap table with all items in the storage chests
---storageMap is a table with keys being the item name and values being a table of tables with the following structure:
---{ chest = peripheral, slot = number, count = number, isFull = boolean }
---@param chests table The list of storage chests
---@return table
local function populateStorageMap(chests)
    logger:warn("Creating storage map")
    local map = {}

    for chestId, chest in ipairs(chests) do
        logger:debug("Scanning chest %d", chestId)

        local chestList = chest.list()

        for slot, item in pairs(chestList) do
            if not map[item.name] then
                map[item.name] = {}
            end
            table.insert(map[item.name], {
                chest = chest,
                slot = slot,
                count = item.count,
                isFull = item.count >= CHEST_SLOT_MAX,
            })
        end

    end
    return populateEmptySlots(map)
end

---Get all slots in the storageMap that have the item
---@param map table The storageMap
---@param itemName string
---@return table
local function getSlots(map, itemName)
    return map[itemName] or {}
end

---Get the first slot in the storageMap that has the item
---@param map table The storageMap
---@param itemName string
---@return table
local function getFirstSlot(map, itemName)
    local allSlots = getSlots(map, itemName)
    return allSlots and allSlots[1]
end


---Filter a table using a function
---@param tbl table The table to filter
---@param filter function The function to use to filter the table
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


---Get a list of slots in the storageMap that have the item
---@param map table The storageMap
---@param itemName string
---@param filter function|nil A function that is used to filter the slots (should take 1 argument [a slot] and return true or false)
---@return table
local function getSlotsFilter(map, itemName, filter)
    local slots = getSlots(map, itemName)
    if filter then
        return filterTable(slots, filter)
    end

    return slots
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
---@param map table The storageMap
---@param itemName string
---@return number
local function getTotalItemCount(map, itemName)
    local slots = getSlots(map, itemName)
    if not slots then
        return 0
    end
    return getTotalCount(slots)
end


---Get the free slots in the storageMap
---@param map table The storageMap
---@return table
local function getFreeSlots(map)
    return getSlots(map, "empty")
end

---Get the first free slot in the storageMap
---@param map table The storageMap
---@return table|nil
local function getFirstFreeSlot(map)
    return getFirstSlot(map, "empty")
end

---Get a list of slots that potentially have space for the item
---@param map table The storageMap
---@param itemName string
---@return table
local function getSlotsWithSpace(map, itemName)
    local slots = getSlotsFilter(map, itemName, function (slots)
        return slots.isFull == false
    end)

    -- append all free slots to the list as well
    for _, slot in ipairs(getFreeSlots(map)) do
        table.insert(slots, slot)
    end

    return slots
end

---Push items from the input chest to the storage chests
---@param map table The storageMap
---@return table
local function pushItems(map)
    logger:info("Pushing items to storage")
    local totalPushedCount = 0
    local totalExpectedPushedCount = 0
    for inputSlot, inputItem in pairs(inputChest.list()) do
        logger:debug("Processing item %s in slot %d", inputItem.name, inputSlot)
        local itemCount = inputItem.count
        local itemPushedCount = 0
        totalExpectedPushedCount = totalExpectedPushedCount + itemCount
        local slots = getSlotsWithSpace(map, inputItem.name)

        for _, storageSlot in ipairs(slots) do
            logger:debug("Pushing %d %s to slot %d in chest %s", itemCount, inputItem.name, storageSlot.slot, peripheral.getName(storageSlot.chest))
            local attemptCount = storageSlot.chest.pullItems(
                inputChestName,
                inputSlot,
                itemCount,
                storageSlot.slot
            )
            logger:debug("Pushed %d items to slot %d", attemptCount, storageSlot.slot)
            if attemptCount == 0 then
                -- This slot is full so mark it so we don't try to push to it again
                storageSlot.isFull = true
            else
                if storageSlot.count == 0 then
                    -- This slot was empty so we need to add it to the map
                    if not map[inputItem.name] then
                        map[inputItem.name] = {}
                    end
                    table.insert(map[inputItem.name], storageSlot)
                    -- Remove the slot from the empty slots
                    for i, emptySlot in ipairs(map["empty"]) do
                        if emptySlot == storageSlot then
                            table.remove(map["empty"], i)
                            break
                        end
                    end
                end
                storageSlot.count = storageSlot.count + attemptCount

                if storageSlot.count >= CHEST_SLOT_MAX then
                    storageSlot.isFull = true
                end
            end
            totalPushedCount = totalPushedCount + attemptCount
            itemPushedCount = itemPushedCount + attemptCount

            if itemPushedCount == itemCount then
                break
            end
        end
    end

    if totalPushedCount == totalExpectedPushedCount then
        logger:info("Pushed %d items to storage", totalPushedCount)
    else
        logger:error("Expected to push %d items but only pushed %d", totalExpectedPushedCount, totalPushedCount)
    end

    return map
end

---Serialise and save a storageMap to a file. Mainly for debugging purposes.
---@param path string The path to save the file to
---@param map table The storageMap to save
---@return nil
local function saveStorageMap(path, map)
    local file = fs.open(path, "w")
    local noChestMap = {}
    for itemName, slots in pairs(map) do
        if not SAVE_EMPTY_SLOTS and itemName == "empty" then
            goto continue
        end
        noChestMap[itemName] = {}
        for _, slot in pairs(slots) do
            table.insert(noChestMap[itemName], {
                chestName = peripheral.getName(slot.chest),
                slot = slot.slot,
                count = slot.count,
                isFull = slot.isFull,
            })
        end
        ::continue::
    end
    file.write(textutils.serialiseJSON(noChestMap))
    file.close()
end

---Load a storageMap from a file
---@param path string The path to load the file from
---@return table|nil
local function loadStorageMap(path)
    if not fs.exists(path) then
        return nil
    end

    local file = fs.open(path, "r")
    local data = file.readAll()
    file.close()
    local noChestMap = textutils.unserialiseJSON(data)
    local map = {}
    for itemName, slots in pairs(noChestMap) do
        map[itemName] = {}
        for _, slot in pairs(slots) do
            table.insert(map[itemName], {
                chest = peripheral.wrap(slot.chestName),
                slot = slot.slot,
                count = slot.count,
                isFull = slot.isFull,
            })
        end
    end
    if not SAVE_EMPTY_SLOTS then
        map = populateEmptySlots(map)
    end
    return map
end

local storageMap = loadStorageMap("storageMap.json") or populateStorageMap(storageChests)

-- print(inputChest.setItem(2, { name = "minecraft:dirt", count = 1 }))
-- pretty.pretty_print(inputChest.list())

storageMap = pushItems(storageMap)
-- local file = fs.open("test.txt", "w")
-- for _, tabl in ipairs(getFreeSlots(storageMap)) do
--     file.write(peripheral.getName(tabl.chest) .. ", " .. tabl.slot .. ", " .. tabl.count .. "\n")
-- end
-- file.close()

saveStorageMap("storageMap.json", storageMap)

-- pretty.pretty_print(getAllSlots("minecraft:dirt"))
-- pretty.print(pretty.pretty(getFirstSlot("minecraft:dirt")))
-- print(getTotalItemCount(storageMap, "minecraft:dirt"))
-- local slots = getSlots("minecraft:stone", 128)
-- pretty.print(pretty.pretty(slots))
-- print(getTotalCount(slots))
