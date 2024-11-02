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

settings.define("storage2.storageFile", {
    description = "The path to the file that the storage map is saved to",
    default = "/.storage2/map.json",
    type = "string",
})

-- constants

local SAVE_EMPTY_SLOTS = false
local CHEST_SLOT_MAX = 64

local logger = logging.getLogger("storage2")
logger:setLevel(logging.LEVELS.INFO)


-- functions


-- from https://stackoverflow.com/questions/15706270/sort-a-table-in-lua
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

---Convert an item name stub into a full item name
---@param stub string The item name stub
---@return string
local function convertItemNameStub(stub)
    if string.find(stub, ":") then
        return stub
    end
    return "minecraft:" .. stub
end


---Convert a full item name into a stub
---@param name string The full item name
---@return string
local function convertItemNameToStub(name)
    return string.match(name, ".+:(.+)")
end


---Get the path to the storage map file
---@return string
local function getStorageMapPath()
    return settings.get("storage2.storageFile")
end


---Get the wrapped input chest
---@return table|nil
local function getInputChest()
    local inputChestName = settings.get("storage2.inputChest")
    local inputChest = peripheral.wrap(inputChestName)

    if not inputChest then
        logger:error("Input chest not found. You may need to change the inputChest setting (set storage2.inputChest {chest name}).")
        return
    end

    return inputChest
end

---Get the wrapped output chest
---@return table|nil
local function getOutputChest()
    local outputChestName = settings.get("storage2.outputChest")
    local outputChest = peripheral.wrap(outputChestName)

    if not outputChest then
        logger:error("Output chest not found. You may need to change the outputChest setting (set storage2.outputChest {chest name}).")
        return
    end

    return outputChest
end

---Get the wrapped storage chests table
---@param inputChest table The input chest
---@param outputChest table The output chest
---@return table|nil
local function getStorageChests(inputChest, outputChest)
    local inputChestName = peripheral.getName(inputChest)
    local outputChestName = peripheral.getName(outputChest)

    local chests = {
        peripheral.find("minecraft:chest", function(name, _)
            return name ~= inputChestName and name ~= outputChestName
        end)
    }

    if #chests == 0 then
        logger:error("No storage chests found. Add more chests to the network!")
        return
    end

    return chests
end


---Copy a table
---@param obj table
---@param seen table|nil
---@return table
local function copyTable(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[copyTable(k, s)] = copyTable(v, s) end
    return res
  end
  


---Write a string to a file
---@param path string The path to save the file to
---@param data string The data to write to the file
---@return nil
local function writeToFile(path, data)
    local file = fs.open(path, "w")
    file.write(data)
    file.close()
end


---Add a slot to the storageMap
---@param map table The storageMap
---@param itemName string The name of the item
---@param slot table The slot to add
---@return table
local function addSlot(map, itemName, slot)
    if not map[itemName] then
        map[itemName] = {}
    end
    table.insert(map[itemName], slot)
    return map
end


---Add a new empty slot to the storageMap
---@param map table The storageMap
---@param chest table The chest that the slot is in
---@param slot number The slot number
---@return table
local function addEmptySlot(map, chest, slot)
    addSlot(map, "empty", {
        chest = chest,
        slot = slot,
        count = 0,
        isFull = false,
    })
    return map
end


---Get all slots in the storageMap that have the item
---@param map table The storageMap
---@param itemName string
---@return table
local function getSlots(map, itemName)
    return map[itemName] or {}
end


---Remove a slot from the storageMap
---@param map table The storageMap
---@param itemName string The name of the item
---@param slot table The slot to remove
---@return table
local function removeSlot(map, itemName, slot)
    local slots = getSlots(map, itemName)
    for i, storageSlot in ipairs(slots) do
        if storageSlot == slot then
            table.remove(slots, i)
            break
        end
    end
    return map
end

---Remove a slot from the storageMap and add it to the empty slots
---@param map table The storageMap
---@param itemName string The name of the item
---@param slot table The slot to remove
---@return table
local function removeSlotAndAddEmpty(map, itemName, slot)
    map = removeSlot(map, itemName, slot)
    map = addEmptySlot(map, slot.chest, slot.slot)
    return map
end

---Populate empty slots in the storageMap
---@param map table The storageMap to populate
---@param chests table The list of storage chests
---@return table
local function populateEmptySlots(map, chests)
    logger:debug("Populating empty slots")
    for chestId, chest in ipairs(chests) do
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
                map = addEmptySlot(map, chest, slot)
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
            addSlot(map, item.name, {
                chest = chest,
                slot = slot,
                count = item.count,
                isFull = item.count >= CHEST_SLOT_MAX,
            })
        end

    end
    return populateEmptySlots(map, chests)
end


---Get the first slot in the storageMap that has the item
---@param map table The storageMap
---@param itemName string
---@return table
local function getFirstSlot(map, itemName)
    local allSlots = getSlots(map, itemName)
    return allSlots and allSlots[1]
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


---Check if an item is available in the storageMap
---@param map table The storageMap
---@param itemName string The name of the item
---@return boolean
local function isItemAvailable(map, itemName)
    if not getTotalItemCount(map, itemName) then
        return false
    end
    return true
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
---@param inputChest table The chest to pull items from
---@return table
local function pushItems(map, inputChest)
    logger:debug("Pushing items...")
    local totalPushedCount = 0
    local totalExpectedPushedCount = 0
    local inputChestName = peripheral.getName(inputChest)

    local mapAdditions = {}

    for inputSlot, inputItem in pairs(inputChest.list()) do
        logger:debug("Processing item %s in slot %d", inputItem.name, inputSlot)
        local itemCount = inputItem.count
        local itemPushedCount = 0
        totalExpectedPushedCount = totalExpectedPushedCount + itemCount
        local slots = getSlotsWithSpace(map, inputItem.name)

        for _, storageSlot in ipairs(slots) do
            local retry_push_count = 0
            ::retry_push::
            logger:debug("Pushing %d %s to slot %d in chest %s", itemCount, inputItem.name, storageSlot.slot, peripheral.getName(storageSlot.chest))
            local attemptCount = storageSlot.chest.pullItems(
                inputChestName,
                inputSlot,
                itemCount,
                storageSlot.slot
            )
            if attemptCount == nil then
                logger:warn("Failed to push items from slot %d to slot %d in chest %s, retrying", inputSlot, storageSlot.slot, peripheral.getName(storageSlot.chest))
                retry_push_count = retry_push_count + 1
                if retry_push_count > 3 then
                    logger:error("Failed to push items too many times, marking the slot as full and continuing", inputSlot, storageSlot.slot, peripheral.getName(storageSlot.chest))
                    storageSlot.isFull = true
                    goto continue
                end
                goto retry_push
            end

            logger:debug("Pushed %d items to slot %d", attemptCount, storageSlot.slot)
            if attemptCount == 0 then
                -- This slot is full so mark it so we don't try to push to it again
                storageSlot.isFull = true
            else
                if storageSlot.count == 0 then
                    -- This slot was empty so we need to add it to the map
                    addSlot(map, inputItem.name, storageSlot)
                    -- Remove the slot from the empty slots
                    removeSlot(map, "empty", storageSlot)
                end
                storageSlot.count = storageSlot.count + attemptCount

                if storageSlot.count >= CHEST_SLOT_MAX then
                    storageSlot.isFull = true
                end
            end
            totalPushedCount = totalPushedCount + attemptCount
            itemPushedCount = itemPushedCount + attemptCount

            if totalPushedCount == totalExpectedPushedCount then
                break
            end
            ::continue::
        end
    end

    if totalPushedCount == totalExpectedPushedCount then
        logger:info("Pushed %d items", totalPushedCount)
    else
        logger:error("Expected to push %d items but only pushed %d", totalExpectedPushedCount, totalPushedCount)
    end

    for _, removal in ipairs(mapAdditions) do
        map = addSlot(map, removal.itemName, removal.slot)
        map = removeSlot(map, "empty", removal.slot)
    end

    return map
end


---Pull items from the storage chests to the output chest
---@param map table The storageMap
---@param itemName string The name of the item to pull
---@param count number The number of items to pull
---@param outputChest table The chest to push items to
---@return table
local function pullItems(map, itemName, count, outputChest)
    logger:debug("Pulling %d %s...", count, itemName)
    local totalPulledCount = 0
    local totalExpectedPulledCount = count
    local slots = getSlots(map, itemName)
    local toPullCount = count

    local outputChestName = peripheral.getName(outputChest)

    local mapRemovals = {}

    for _, storageSlot in pairs(slots) do
        local retry_pull_count = 0
        ::retry_pull::
        logger:debug("Pulling %d %s from slot %d in chest %s", toPullCount, itemName, storageSlot.slot, peripheral.getName(storageSlot.chest))
        local attemptCount = storageSlot.chest.pushItems(
            outputChestName,
            storageSlot.slot,
            toPullCount
        )

        if attemptCount == nil then
            logger:warn("Failed to pull items from slot %d in chest %s, retrying", storageSlot.slot, peripheral.getName(storageSlot.chest))
            retry_pull_count = retry_pull_count + 1
            if retry_pull_count > 3 then
                logger:error("Failed to pull items too many times, marking the slot as empty and continuing", storageSlot.slot, peripheral.getName(storageSlot.chest))
                -- map = removeSlotAndAddEmpty(map, itemName, storageSlot)
                table.insert(mapRemovals, {
                    itemName = itemName,
                    slot = storageSlot,
                })
                goto continue
            end
            goto retry_pull
        end

        toPullCount = toPullCount - attemptCount

        logger:debug("Pulled %d items from slot %d", attemptCount, storageSlot.slot)
        if attemptCount == 0 then
            -- This slot is empty so mark it as empty
            -- map = removeSlotAndAddEmpty(map, itemName, storageSlot)
            table.insert(mapRemovals, {
                itemName = itemName,
                slot = storageSlot,
            })
        else
            storageSlot.count = storageSlot.count - attemptCount
            if storageSlot.count == 0 then
                -- This slot is now empty
                -- map = removeSlotAndAddEmpty(map, itemName, storageSlot)
                table.insert(mapRemovals, {
                    itemName = itemName,
                    slot = storageSlot,
                })
            end
        end
        totalPulledCount = totalPulledCount + attemptCount

        if totalPulledCount == totalExpectedPulledCount then
            break
        end
        ::continue::
    end

    if totalPulledCount == totalExpectedPulledCount then
        logger:info("Pulled %d %s", totalPulledCount, itemName)
    else
        logger:error("Expected to pull %d %s but only pulled %d", totalExpectedPulledCount, itemName, totalPulledCount)
    end

    for _, removal in ipairs(mapRemovals) do
        map = removeSlotAndAddEmpty(map, removal.itemName, removal.slot)

        -- if the newly removed item's total count is 0, remove it from the map
        if getTotalItemCount(map, removal.itemName) == 0 then
            map[removal.itemName] = nil
        end
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
---@param chests table The list of storage chests (used if empty slots aren't saved)
---@return table|nil
local function loadStorageMap(path, chests)
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
        map = populateEmptySlots(map, chests)
    end
    return map
end

---Load the storageMap from a file or populate it if the file does not exist
---@param path string The path to load the file from
---@param chests table The list of storage chests
---@return table
local function loadOrPopulateStorageMap(path, chests)
    return loadStorageMap(path, chests) or populateStorageMap(chests)
end


---Get a list of item name stubs from the storageMap (only showing items that have a count of more than 0)
---@param map table The storageMap
---@return table
local function getAllItemStubs(map)
    local items = {}
    for itemName, slots in spairs(map) do
        if itemName ~= "empty" and getTotalItemCount(map, itemName) > 0 then
            table.insert(items, convertItemNameToStub(itemName))
        end
    end
    return items
end

---Return all matches of a pattern in the keys of the storageMap
---@param map table The storageMap
---@param pattern string The pattern to match
---@return table
local function getAllMatches(map, pattern)
    local matches = {}
    for itemName, _ in pairs(map) do
        if string.match(itemName, pattern) then
            table.insert(matches, itemName)
        end
    end
    return matches
end


---Return the first match of a pattern in the keys of the storageMap
---@param map table The storageMap
---@param pattern string The pattern to match
---@return string
local function getFirstMatch(map, pattern)
    return getAllMatches(map, pattern)[1] or pattern
end


-- Main

local function test()
    local globInputChest = getInputChest()
    if not globInputChest then
        return
    end

    local globOutputChest = getOutputChest()
    if not globOutputChest then
        return
    end

    local globStorageChests = getStorageChests(globInputChest, globOutputChest)
    if not globStorageChests then
        return
    end

    local storageMap = loadOrPopulateStorageMap("storageMap.json", globStorageChests)

    -- print(inputChest.setItem(2, { name = "minecraft:dirt", count = 1 }))
    -- pretty.pretty_print(inputChest.list())


    storageMap = pushItems(storageMap, globInputChest)

    -- local file = fs.open("test.txt", "w")
    -- for _, tabl in ipairs(getSlots(storageMap, "minecraft:stone")) do
    --     file.write(peripheral.getName(tabl.chest) .. ", " .. tabl.slot .. ", " .. tabl.count .. "\n")
    -- end
    -- file.close()

    storageMap = pullItems(storageMap, "minecraft:stone", 999, globOutputChest)

    saveStorageMap("storageMap.json", storageMap)

    -- pretty.pretty_print(getAllSlots("minecraft:dirt"))
    -- pretty.print(pretty.pretty(getFirstSlot("minecraft:dirt")))
    -- print(getTotalItemCount(storageMap, "minecraft:dirt"))
    -- local slots = getSlots("minecraft:stone", 128)
    -- pretty.print(pretty.pretty(slots))
    -- print(getTotalCount(slots))
end

-- test()


return {
    loadStorageMap = loadStorageMap,
    saveStorageMap = saveStorageMap,
    populateStorageMap = populateStorageMap,
    loadOrPopulateStorageMap=loadOrPopulateStorageMap,
    pushItems = pushItems,
    pullItems = pullItems,
    getInputChest = getInputChest,
    getOutputChest = getOutputChest,
    getStorageChests = getStorageChests,
    getStorageMapPath = getStorageMapPath,
    getTotalItemCount = getTotalItemCount,
    isItemAvailable = isItemAvailable,
    getAllItemStubs = getAllItemStubs,
    convertItemNameStub = convertItemNameStub,
    getFirstMatch = getFirstMatch,
    getAllMatches = getAllMatches,
}
