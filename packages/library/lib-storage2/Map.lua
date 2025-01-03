-- Imports
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-storage2.MapSlot")
require("lib-storage2.ChestFilter")

local helpers = require("lib-storage2.helpers")
local tableHelpers = require("lexicon-lib.lib-table")
local chestHelpers = require("lib-storage2.chestHelpers")

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
Map.filterDirectory = settings.get("storage2.filterDirectory")

---Initialise a new Map
---@param chests ccTweaked.peripherals.Inventory[] The chests to use for the map
function Map:init(chests)
    self.chests = chests
    ---@type MapTable
    self.mapTable = {}
    ---@type ChestFilter[]
    self.filters = {}

    self:populate()
    self:loadFilters()

    self.populating = false
end


---Load filters from disk
---@return boolean _ Whether the filters were loaded successfully
function Map:loadFilters()
    ---@type ChestFilter[]
    self.filters = {}

    for _, path in pairs(fs.find(self.filterDirectory .. "/*.json")) do
        ---@type SerializedChestFilter?
        local serialized, loadError = tableHelpers.loadTable(path)
    
        if not serialized then
            logger:error("Failed to load %s: %s", path, loadError)
            return false
        end

        table.insert(self.filters, ChestFilter(serialized.name, serialized.itemNames, serialized.itemTags, serialized.slotNumbers))
    end

    return true
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
---@param skipWaitPopulate? boolean Whether the map is currently populating
function Map:removeSlot(slot, skipWaitPopulate)
    local slots = self:getItemSlots(slot.name, skipWaitPopulate)
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
    self:waitIfPopulating()

    local results = {}
    local stringFirstChar = nil
    if string.len(search) > 0 then
        stringFirstChar = string.sub(search, 1, 1)
    end

    for itemName, slots in pairs(self.mapTable) do
        if itemName ~= MapSlot.EMPTY_SLOT_NAME then
            if stringFirstChar == "#" then
                local firstSlot = slots[1]
                if not firstSlot then
                    goto continue
                end
                if not tableHelpers.contains(firstSlot.tags, string.sub(search, 2)) then
                    goto continue
                else
                    table.insert(results, itemName)
                end
            elseif stringFirstChar == "@" then
                for _, slot in ipairs(slots) do
                    local slotEnchantmentStubs = slot:getEnchantmentNameStubs() or {}
                    local gotMatch = false
                    for _, slotEnchantmentStub in ipairs(slotEnchantmentStubs) do

                        if slotEnchantmentStub == MapSlot.getNameStub(string.sub(search, 2)) then
                            table.insert(results, itemName)
                            gotMatch = true
                            break
                        end
                    end
                    if gotMatch then
                        break
                    end
                end
            else
                if string.match(itemName, search) then
                    table.insert(results, itemName)
                end
            end
        end
        ::continue::
    end
    return results
end


---Get the slots that contain a specific item
---@param name string The name of the item
---@param skipWaitPopulate? boolean Whether the map is currently populating
---@return MapSlot[]
function Map:getItemSlots(name, skipWaitPopulate)
    if not skipWaitPopulate then
        self:waitIfPopulating()
    end

    return self.mapTable[name] or {}
end


---Get the slots that have a specific tag
---@param tag string The tag to search for
---@return MapSlot[]
function Map:getItemSlotsByTag(tag)
    self:waitIfPopulating()

    local results = {}
    for _, slots in pairs(self.mapTable) do
        for _, slot in ipairs(slots) do
            if tableHelpers.contains(slot.tags, tag) then
                table.insert(results, slot)
            end
        end
    end
    return results
end


---Get the slots that have a specific enchantment
---@param enchantment string The enchantment to search for
---@return MapSlot[]
function Map:getItemSlotsByEnchantment(enchantment)
    self:waitIfPopulating()

    local enchantment_name_stub = MapSlot.getNameStub(enchantment)

    local results = {}
    for _, slots in pairs(self.mapTable) do
        for _, slot in ipairs(slots) do
            local slotEnchantmentStubs = slot:getEnchantmentNameStubs()
            if slotEnchantmentStubs then
                for _, slotEnchantmentStub in ipairs(slotEnchantmentStubs) do
                    if slotEnchantmentStub == enchantment_name_stub then
                        table.insert(results, slot)
                    end
                end
            end
        end
    end
    return results
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
    return tableHelpers.filterTable(self:getItemSlots(name), filter)
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


---Get slots by search - for use with the cli mainly
---@param search string The search string
---@param fuzzy? boolean Whether to use fuzzy matching
---@return MapSlot[]
function Map:getSlotsBySearchString(search, fuzzy)
    local slots = {}

    local stringFirstChar = nil
    if string.len(search) > 0 then
        stringFirstChar = string.sub(search, 1, 1)
    end

    if stringFirstChar == "#" then
        slots = self:getItemSlotsByTag(string.sub(search, 2))
    elseif stringFirstChar == "@" then
        slots = self:getItemSlotsByEnchantment(string.sub(search, 2))
    else
        slots = self:getItemSlots(MapSlot.fullNameFromNameStub(search))

        if fuzzy and tableHelpers.tableIsEmpty(slots) then
            slots = self:getItemSlotsBySearch(search)
        end
    end

    return slots
end


---Get the total count of a specific item
---@param name string The name of the item
---@param fuzzy? boolean Whether to use fuzzy matching for the item name
---@return number
function Map:getTotalItemCount(name, fuzzy)
    local slots = self:getSlotsBySearchString(name, fuzzy)

    return self.getTotalCount(slots)
end


---Get a list of all name stubs in the map
---@return string[]
function Map:getAllItemStubs()
    self:waitIfPopulating()

    local itemStubs = {}
    for name, _ in pairs(self.mapTable) do
        if name ~= MapSlot.EMPTY_SLOT_NAME then
            table.insert(itemStubs, MapSlot.getNameStub(name))
        end
    end

    table.sort(itemStubs, function(a, b)
        return a < b
    end)

    local tagsUnique = {}
    local enchantmentsUnique = {}

    for _, slots in pairs(self.mapTable) do
        for _, slot in ipairs(slots) do
            for tag, _ in pairs(slot.tags) do
                tag = "#" .. tag
                tagsUnique[tag] = true
            end

            local enchantmentStubs = slot:getEnchantmentNameStubs()
            if enchantmentStubs then
                for _, enchantmentStub in ipairs(enchantmentStubs) do
                    enchantmentStub = "@" .. enchantmentStub
                    enchantmentsUnique[enchantmentStub] = true
                end
            end
        end
    end

    local tags = {}

    for tag, _ in pairs(tagsUnique) do
        table.insert(tags, tag)
    end

    table.sort(tags, function(a, b)
        return a < b
    end)

    for _, tag in ipairs(tags) do
        table.insert(itemStubs, tag)
    end

    local enchantments = {}

    for enchantment, _ in pairs(enchantmentsUnique) do
        table.insert(enchantments, enchantment)
    end

    table.sort(enchantments, function(a, b)
        return a < b
    end)

    for _, enchantment in ipairs(enchantments) do
        table.insert(itemStubs, enchantment)
    end

    return itemStubs
end


---Get all slots in the map
---@param skipWaitPopulate? boolean Whether to skip waiting for the map to populate
---@return MapSlot[]
function Map:getAllSlots(skipWaitPopulate)
    if not skipWaitPopulate then
        self:waitIfPopulating()
    end

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

    return tableHelpers.filterTable(self:getAllSlots(), isFullFilter)
end


---Clear the current map
function Map:clear()
    self.mapTable = {}
end


---Order the empty slots by chestName and slot
---@param skipWaitPopulate? boolean Whether the map is currently populating
function Map:orderEmptySlots(skipWaitPopulate)
    local emptySlots = self:getItemSlots(MapSlot.EMPTY_SLOT_NAME, skipWaitPopulate)
    table.sort(emptySlots, function(a, b)
        if a.chestName == b.chestName then
            return a.slot < b.slot
        end
        return a.chestName < b.chestName
    end)
    self.mapTable[MapSlot.EMPTY_SLOT_NAME] = emptySlots
end


---Compress the map to reduce the number of empty slots. Essentially, will create as many full stacks as possible.
---@param skipWaitPopulate? boolean Whether the map is currently populating
---@return boolean _ Whether any changes were made
function Map:compress(skipWaitPopulate)
    local allSlots = self:getAllSlots(skipWaitPopulate)

    local nonEmptyNotFullSlots = tableHelpers.filterTable(allSlots, function(slot)
        return slot.isFull == false and slot.name ~= MapSlot.EMPTY_SLOT_NAME
    end)

    local nameGroupedSlots = tableHelpers.groupBy(nonEmptyNotFullSlots, function(slot)
        return slot.name
    end)

    local changesMade = false

    for _, slotList in pairs(nameGroupedSlots) do
        ---@cast slotList MapSlot[]
        for i = #slotList, 1, -1 do
            local fromSlot = slotList[i]

            for _, toSlot in ipairs(slotList) do
                if fromSlot == toSlot then
                    break
                end

                local movedCount = helpers.chestPushItemsRetry(
                    fromSlot.chest,
                    toSlot.chestName,
                    fromSlot.slot,
                    math.min(fromSlot.count, toSlot.maxCount - toSlot.count),
                    toSlot.slot
                )

                if not movedCount then
                    break
                end

                if movedCount > 0 then
                    fromSlot:addCount(-movedCount)
                    toSlot:addCount(movedCount)
                    changesMade = true
                end

                if fromSlot.count == 0 then
                    self:removeSlot(fromSlot, skipWaitPopulate)
                    self:addSlotEmpty(fromSlot.chest, fromSlot.slot)
                    break
                end

                if toSlot.isFull then
                    break
                end
            end
        end
    end

    return changesMade
end


---Check for differences between the map and the chests
---@return boolean _ Whether any differences were found
function Map:checkDiffs()
    local allSlots = self:getAllSlots()

    local differences = false


    local nonEmptySlots = tableHelpers.filterTable(allSlots, function(slot)
        return slot.name ~= MapSlot.EMPTY_SLOT_NAME
    end)

    local emptySlots = self:getItemSlots(MapSlot.EMPTY_SLOT_NAME)

    for _, batch in pairs(tableHelpers.batch(nonEmptySlots, 50)) do
        local diffTasks = {}
        for _, slot in pairs(batch) do
            table.insert(diffTasks, function()
                local slotDetails = slot.chest.getItemDetail(slot.slot)

                if not slotDetails then
                    logger:warn("%s, %d: %s (%d) => EMPTY", slot.chestName, slot.slot, slot.name, slot.count)
                    differences = true
                    return
                end

                if slot.name ~= slotDetails.name or slot.count ~= slotDetails.count then
                    logger:warn("%s, %d: %s (%d) => %s (%d)", slot.chestName, slot.slot, slot.name, slot.count, slotDetails.name, slotDetails.count)
                    differences = true
                end
            end)
        end

        parallel.waitForAll(table.unpack(diffTasks))
    end

    for _, batch in pairs(tableHelpers.batch(emptySlots, 50)) do
        local diffTasks = {}
        for _, slot in ipairs(batch) do
            table.insert(diffTasks, function()
                local slotDetails = slot.chest.getItemDetail(slot.slot)

                if slotDetails then
                    logger:warn("%s, %d: EMPTY => %s (%d)", slot.chestName, slot.slot, slotDetails.name, slotDetails.count)
                    differences = true
                end
            end)
        end

        parallel.waitForAll(table.unpack(diffTasks))
    end

    if not differences then
        logger:info("No differences found")
    end

    return differences
end


---Populate the map with the items in the chests (unwrapped version)
---@param force? boolean Whether to force a repopulation
function Map:_populate(force)
    if not force and self:load() then
        return
    end

    logger:warn("Populating storage map")
    self:clear()

    ---@type function[]
    local slotEnrichmentTasks = {}

    ---@type function[]
    local chestTasks = {}
    for _, chest in ipairs(self.chests) do
        table.insert(chestTasks, function()

            local chestList = helpers.chestListRetry(chest)

            if not chestList then
                return
            end

            for slotNumber = 1, chest.size() do
                local item = chestList[slotNumber]

                if not item then
                    self:addSlotEmpty(chest, slotNumber)
                    goto continue
                end

                local newSlot = MapSlot(
                    item.name,
                    chest,
                    slotNumber,
                    item.count,
                    0,
                    nil,
                    nil,
                    nil
                )

                table.insert(slotEnrichmentTasks, function()
                    newSlot:enrich()
                end)

                self:addSlot(newSlot)

                ::continue::
            end
        end)
    end

    for batchId, chestTaskBatch in pairs(tableHelpers.batch(chestTasks, 64)) do
        logger:debug("Processing chest batch %d", batchId)
        parallel.waitForAll(table.unpack(chestTaskBatch))
    end
    -- for _, task in ipairs(chestTasks) do
    --     task()
    -- end

    for batchId, slotEnrichmentTaskBatch in pairs(tableHelpers.batch(slotEnrichmentTasks, 128)) do
        logger:debug("Processing slot batch %d", batchId)
        parallel.waitForAll(table.unpack(slotEnrichmentTaskBatch))
    end


    while self:compress(true) do
        -- keep compressing until we can't compress anymore
    end

    logger:debug("Compress complete")

    self:orderEmptySlots(true)

    logger:debug("Populate complete")
end


---Populate the map with the items in the chests (wrapped version that updates the populating flag)
---@param force? boolean Whether to force a repopulation
function Map:populate(force)
    self.populating = true
    self:_populate(force)
    self.populating = false
end


---Wait for the map to finish populating
---@return boolean _ Whether the map was populated successfully
function Map:waitIfPopulating()
    local waitedTime = 0
    local waitSlice = 0.05
    while self.populating do
        os.sleep(waitSlice)
        waitedTime = waitedTime + waitSlice
        if waitedTime % 2 == 0 then
            logger:warn("Waiting for map to populate...")
        end

        if waitedTime > 10 then
            logger:error("Waited too long for map to populate")
            return false
        end
    end

    return true
end


---Save the map to a file
function Map:save()
    self:waitIfPopulating()

    self:orderEmptySlots()

    local serialized = {}

    for name, slots in pairs(self.mapTable) do
        serialized[name] = {}
        for _, slot in ipairs(slots) do
            table.insert(serialized[name], slot:serialize())
        end
    end

    tableHelpers.saveTable(self.saveFilename, serialized)
end


---Load the map from a file
---@return boolean _ Whether the map was loaded successfully
function Map:load()
    ---@type SerializedMap?
    local serialized, loadError = tableHelpers.loadTable(self.saveFilename)

    if not serialized then
        logger:error("Failed to load storage map: %s", loadError)
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


---Order slots by putting filter slots first
---@param slots MapSlot[] The slots to order
---@return MapSlot[]
function Map:orderSlotsByFilter(slots)
    ---@type MapSlot[]
    local filterSlots = {}
    ---@type MapSlot[]
    local nonFilterSlots = {}

    for _, slot in ipairs(slots) do
        local isFilterSlot = false
        for _, filter in ipairs(self.filters) do
            if filter:appliesTo(slot.chestName) then
                isFilterSlot = true
                break
            end
        end

        if isFilterSlot then
            table.insert(filterSlots, slot)
        else
            table.insert(nonFilterSlots, slot)
        end
    end

    return tableHelpers.concat(filterSlots, nonFilterSlots)
end


---Push all items from an input chest to the storage chests, updating the map as needed
---@param inputChest ccTweaked.peripherals.Inventory The chest to push items from
---@param fromSlots? number[] The slots to push items from (default all slots)
---@return number _ The number of items pushed
function Map:push(inputChest, fromSlots)
    local totalPushedCount = 0
    local totalExpectedPushedCount = 0

    local inputChestName = peripheral.getName(inputChest)

    local inputChestList = helpers.chestListRetry(inputChest)

    if not inputChestList then
        return totalPushedCount
    end

    ---@type table<string, {pushed: number, expectedPushed: number}>
    local pushedItems = {}

    ---@type function[]
    local slotEnrichmentTasks = {}

    for inputSlot, inputItem in pairs(inputChestList) do
        logger:debug("Pushing %s, slot %s", inputItem.name, inputSlot)

        local availableSlots = self:getItemSlotsWithSpace(inputItem.name)
        availableSlots = self:orderSlotsByFilter(availableSlots)

        totalExpectedPushedCount = totalExpectedPushedCount + inputItem.count

        for _, slot in ipairs(availableSlots) do
            if slot.chestName == inputChestName then
                -- don't push to the input chest
                goto continue
            end

            local filterCheckTasks = {}
            local filterDoSkip = false

            for _, filter in ipairs(self.filters) do
                table.insert(filterCheckTasks, function()

                    if filter:appliesTo(slot.chestName) then
                        if not filter:acceptsName(inputItem.name) then
                            filterDoSkip = true
                            return
                        end

                        if not filter:acceptsSlot(slot.slot) then
                            filterDoSkip = true
                            return
                        end

                        -- enrich to check for tags
                        slot:enrich()

                        if not filter:acceptsTags(slot.tags) then
                            filterDoSkip = true
                            return
                        end
                    end
                end)
            end

            parallel.waitForAll(table.unpack(filterCheckTasks))

            if filterDoSkip then
                goto continue
            end

            logger:debug("Pushing %d %s to slot %d in chest %s", inputItem.count, inputItem.name, slot.slot, slot.chestName)
            -- local quantity = helpers.chestPushItemsRetry(
            --     inputChest,
            --     slot.chestName,
            --     inputSlot,
            --     inputItem.count,
            --     slot.slot
            -- )

            local targetChest = chestHelpers.wrapInventory(slot.chestName)
            if not targetChest then
                logger:error("Failed to wrap chest %s", slot.chestName)
                goto continue
            end

            if fromSlots and not tableHelpers.valuesContain(fromSlots, inputSlot) then
                goto continue
            end

            local quantity = helpers.chestPullItemsRetry(
                targetChest,
                inputChestName,
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

                    local newSlot = MapSlot(
                        inputItem.name,
                        slot.chest,
                        slot.slot,
                        quantity,
                        0,
                        nil
                    )

                    table.insert(slotEnrichmentTasks, function()
                        newSlot:enrich()
                    end)

                    self:addSlot(newSlot)
                    self:removeSlot(slot)
                else
                    -- slot was not empty, update the count
                    slot:addCount(quantity)
                end

                if not pushedItems[inputItem.name] then
                    pushedItems[inputItem.name] = {
                        pushed = quantity,
                        expectedPushed = inputItem.count
                    }
                else
                    pushedItems[inputItem.name] = {
                        pushed = pushedItems[inputItem.name].pushed + quantity,
                        expectedPushed = pushedItems[inputItem.name].expectedPushed + inputItem.count
                    }
                end
            end

            totalPushedCount = totalPushedCount + quantity

            if totalPushedCount >= totalExpectedPushedCount then
                break
            end

            ::continue::
        end
    end

    parallel.waitForAll(table.unpack(slotEnrichmentTasks))

    ---@type string[]
    local pushedItemsStrings = {}

    for name, countData in pairs(pushedItems) do
        table.insert(pushedItemsStrings, string.format("%d/%d %s", countData.pushed, countData.expectedPushed, MapSlot.getNameStub(name)))
    end

    local pushedItemsStrings = table.concat(pushedItemsStrings, ", ")

    if totalPushedCount < totalExpectedPushedCount then
        logger:error("Only pushed %s", pushedItemsStrings)
    else
        logger:info("Pushed %s", pushedItemsStrings)
    end

    return totalPushedCount
end


---Pull items from the storage chests to the output chest, updating the map as needed
---@param outputChest ccTweaked.peripherals.Inventory The chest to pull items to
---@param itemName string The name of the item to pull
---@param amount number The amount of the item to pull
---@param fuzzy boolean Whether to use fuzzy matching for the item name
---@param toSlot number? The slot in the output to push the items into (optional)
---@return number _ The number of items pulled
function Map:pull(outputChest, itemName, amount, fuzzy, toSlot)
    local totalPulledCount = 0
    local totalActualPulledCount = 0
    local totalExpectedPulledCount = amount

    local outputChestName = peripheral.getName(outputChest)

    ---@type MapSlot[]
    local slots = self:getSlotsBySearchString(itemName, fuzzy)

    ---@type MapSlot[]
    local mapRemovals = {}

    ---@type function[]
    local slotTasks = {}

    for _, slot in ipairs(slots) do
        if slot.chestName == outputChestName then
            -- don't pull from the output chest
            goto continue
        end

        local expectedSlotPullCount = math.min(slot.count, totalExpectedPulledCount - totalPulledCount)

        table.insert(slotTasks, function()
            logger:debug("Pulling %d %s from slot %d in chest %s", amount, slot.name, slot.slot, slot.chestName)
            -- local quantity = helpers.chestPullItemsRetry(
            --     outputChest,
            --     slot.chestName,
            --     slot.slot,
            --     expectedSlotPullCount
            -- )

            local sourceChest = chestHelpers.wrapInventory(slot.chestName)
            if not sourceChest then
                logger:error("Failed to wrap chest %s", slot.chestName)
                return
            end

            local quantity = helpers.chestPushItemsRetry(
                sourceChest,
                outputChestName,
                slot.slot,
                expectedSlotPullCount,
                toSlot
            )
            
            if not quantity then
                -- If we've pulled nil items, the slot is probs empty
                table.insert(mapRemovals, slot)
                return
            end

            if quantity ~= expectedSlotPullCount then
                -- If we've pulled an amount that doesn't match the expected amount, something's gone wrong so log it
                logger:error("Slot %d in chest %s pulled %d/%d", slot.slot, slot.chestName, quantity, expectedSlotPullCount)
            end

            if quantity > 0 then
                totalActualPulledCount = totalActualPulledCount + quantity

                -- pulled at least one item, update the map
                slot:addCount(-quantity)

                if slot.count == 0 then
                    -- slot is now empty, mark it as such
                    table.insert(mapRemovals, slot)
                end
            end
        end)

        totalPulledCount = totalPulledCount + expectedSlotPullCount

        if totalPulledCount >= totalExpectedPulledCount then
            break
        end

        ::continue::
    end

    parallel.waitForAll(table.unpack(slotTasks))

    if totalActualPulledCount < totalExpectedPulledCount then
        logger:warn("Only pulled %d/%d %s", totalActualPulledCount, totalExpectedPulledCount, itemName)
    else
        logger:info("Pulled %d/%d %s", totalActualPulledCount, totalExpectedPulledCount, itemName)
    end

    for _, slot in ipairs(mapRemovals) do
        self:addSlotEmpty(slot.chest, slot.slot)
        self:removeSlot(slot)

        if self:getTotalItemCount(slot.name) == 0 then
            self:deleteSlotList(slot.name)
        end
    end

    return totalActualPulledCount
end