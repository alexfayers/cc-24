package.path = package.path .. ";/usr/lib/?.lua"

require("lib-crafter.client.CraftClient")
require("lib-storage2.remote.StorageClient")

local pretty = require("cc.pretty")
local tableHelpers = require("lexicon-lib.lib-table")

local logger = require("lexicon-lib.lib-logging").getLogger("Crafter")

local BASE_URL = "https://raw.githubusercontent.com/alexfayers/cc-24/refs/heads/main/helper/autocrafter/"

local craftClient = CraftClient()
local storageClient = StorageClient()


settings.define("crafter.outputChestName", {
    description = "The name of the chest to output crafted items to",
    type = "string",
})

settings.define("crafter.modemLocalName", {
    description = "The local name of the crafty turtle on it's modem",
    type = "string",
})

settings.define("crafter.cacheFolder", {
    description = "The folder to save cached recipes and tags to",
    type = "string",
    default = ".autocraft/cache/"
})

---@type ccTweaked.peripherals.Inventory?
local outputChest = nil

---@type string?
local remoteName = settings.get("crafter.modemLocalName")


---@type string
local cacheFolder = settings.get("crafter.cacheFolder")

---@type table<string, string[]>?
local recipeLoops = nil


local function getItemStub(itemName)
    return itemName:match(".*:(.*)") or itemName
end


---Get the item from the remote repo and save it to disk if it doesn't exist, or load it from disk if it does
---@param itemPath string The subpath to save the item to/load the item from
---@param itemName string The name of the item to fetch
---@return table?
local function getRemoteItem(itemPath, itemName)
    local itemFile = fs.combine(cacheFolder, itemPath, itemName .. ".json")

    local diskData = tableHelpers.loadTable(itemFile)

    if diskData ~= nil then
        if tableHelpers.tableIsEmpty(diskData) then
            -- logger:warn("Item %s %s is empty", itemPath, itemName)
            return
        end

        return diskData
    end

    local itemUrl = BASE_URL .. itemPath .. "/" .. itemName .. ".json" .. "?t=" .. os.epoch("utc")

    local response = http.get(itemUrl)

    if response == nil then
        logger:error("Failed to fetch %s %s", itemPath, itemName)
        tableHelpers.saveTable(itemFile, {})
        return
    end

    local responseCode = response.getResponseCode()

    if response == nil then

        if responseCode == 404 then
            logger:warn("Item %s %s not found", itemPath, itemName)

            tableHelpers.saveTable(itemFile, {})
            return
        else
            logger:error("Failed to fetch %s %s (%d)", itemPath, itemName, responseCode)
        end

        return
    end

    if responseCode ~= 200 then
        logger:error("Failed to fetch %s %s (%d)", itemPath, itemName, responseCode)
        response.close()
        return
    end

    local itemJson = response.readAll()
    response.close()

    if itemJson == nil then
        logger:error("Item was empty for %s %s", itemPath, itemName)
        return
    end

    local itemTable = textutils.unserializeJSON(itemJson)

    if itemTable == nil then
        logger:error("Failed to parse %s %s", itemPath, itemName)
        return
    end

    local saveRes, saveErr = tableHelpers.saveTable(itemFile, itemTable)

    if not saveRes then
        logger:error("Failed to save %s %s: %s", itemPath, itemName, saveErr)
    end

    return itemTable
end


---Convert an item tag to a list of items, recursively
---@param tag string The tag to convert
---@return string[]?
local function tag_to_items(tag)
    local items = {}

    if type(tag) ~= "string" then
        logger:error("Tag %s is not a string", tag)
        return
    end

    if tag:sub(1, 1) == "#" then
        local tagItems = getItemStub(tag:sub(2))

        local tagItemsTable = getRemoteItem("tags", tagItems)

        if tagItemsTable == nil then
            -- logger:error("Failed to get tag items for " .. tag)
            return
        end

        local tagValues = tagItemsTable.values

        if tagValues == nil then
            logger:error("Failed to parse tag values for " .. tag)
            return
        end

        for _, tagItem in pairs(tagValues) do
            local tagItemItems = tag_to_items(tagItem)

            if tagItemItems ~= nil then
                for _, tagItemItem in pairs(tagItemItems) do
                    table.insert(items, tagItemItem)
                end
            end
        end
    else
        table.insert(items, tag)
    end

    return items
end


---@class CrafterOutput
---@field id string
---@field count number

---@class Recipe
---@field input table<string, string[]>
---@field output CrafterOutput

---Fetch the recipe for an item from the remote repo
---@param itemName string The name of the item to fetch the recipe for
---@return Recipe[]?
local function fetch_recipe_remote(itemName)
    itemName = getItemStub(itemName)

    local recipeTable = getRemoteItem("recipes", itemName)

    if recipeTable == nil then
        logger:debug("Failed to get recipe for " .. itemName)
        return
    end

    local emptyRecipeIndexes = {}

    for subRecipeIndex, subRecipeTable in ipairs(recipeTable) do
        for slotStr, slotItemNames in pairs(subRecipeTable.input) do
            local slotItems = {}
    
            for _, slotItemName in pairs(slotItemNames) do
                if slotItemName:sub(1, 1) == "#" then
                    local tagItems = tag_to_items(slotItemName)
    
                    if tagItems == nil then
                        logger:error("Failed to convert tag to items")
                        return
                    end
    
                    for _, tagItem in pairs(tagItems) do
                        if tagItem ~= subRecipeTable.output.id then
                            table.insert(slotItems, tagItem)
                        end
                    end
                else
                    if slotItemName ~= subRecipeTable.output.id then
                        table.insert(slotItems, slotItemName)
                    end
                end
            end

            if tableHelpers.tableIsEmpty(slotItems) then
                emptyRecipeIndexes[subRecipeIndex] = true
            end

            subRecipeTable.input[slotStr] = slotItems
        end
    end

    for emptyRecipeIndex, _ in pairs(emptyRecipeIndexes) do
        table.remove(recipeTable, emptyRecipeIndex)
    end

    return recipeTable
end


---Wrap the output chest and return it if it's not already wrapped
---@return boolean
local function ensureOutputChest()
    if outputChest == nil then
        local outputChestName = settings.get("crafter.outputChestName")

        if outputChestName == nil then
            logger:error("No output chest defined. Set crafter.outputChestName")
            return false
        end

        local outputChestTemp = peripheral.wrap(outputChestName)

        if outputChestTemp == nil then
            logger:error("Failed to wrap output chest")
            return false
        end

        ---@diagnostic disable-next-line: cast-local-type
        outputChest = outputChestTemp
    end

    return true
end


---Push into the storage system from the outputChest
---@return boolean
local function push_output_chest()
    if not ensureOutputChest() then
        return false
    end
    ---@cast outputChest ccTweaked.peripherals.Inventory

    local outputChestName = peripheral.getName(outputChest)

    if outputChestName == nil then
        logger:error("No output chest defined. Set crafter.outputChestName")
        return false
    end

    local pushRes, pushData = storageClient:callCommand(storageClient.push, outputChestName)

    if pushRes and pushData and pushData.count > 0 then
        logger:debug("Pushed %d items to storage", pushData.count)
        return true
    else
        return false
    end
end



---Transfer a slot from the crafter to the output chest
---@param crafterName string The name of the crafter
---@param slot number The slot to transfer
---@return number
local function transfer_slot(crafterName, slot)
    if not ensureOutputChest() then
        return 0
    end
    ---@cast outputChest ccTweaked.peripherals.Inventory

    local pullCount = outputChest.pullItems(crafterName, slot)

    return pullCount
end


---Transfer all slots from the crafter to the output chest
---@param crafterName string The name of the crafter
---@return boolean
local function transfer_all_slots(crafterName)
    if not ensureOutputChest() then
        return false
    end

    local totalTransferred = 0

    local transferTasks = {}
    for slot = 1, 16 do
        table.insert(transferTasks, function ()
            local transferCount = transfer_slot(crafterName, slot)
    
            if transferCount > 0 then
                totalTransferred = totalTransferred + transferCount
            end
        end)
    end

    parallel.waitForAll(table.unpack(transferTasks))

    if totalTransferred > 0 then
        logger:info("Pulled %d item%s from turtle", totalTransferred, totalTransferred > 1 and "s" or "")
        return push_output_chest()
    end

    return false
end


---Get the recipes for a tag
---@param tag string The tag to get the recipes for
---@return Recipe[]?
local function get_tag_recipes(tag)
    local tagItems = tag_to_items(tag)

    if tagItems == nil then
        logger:error("Failed to convert tag to items")
        return
    end

    local recipes = {}

    for _, tagItem in pairs(tagItems) do
        local itemRecipes = fetch_recipe_remote(tagItem)

        if itemRecipes == nil then
            return
        end

        for _, itemRecipe in pairs(itemRecipes) do
            table.insert(recipes, itemRecipe)
        end
    end

    return recipes
end


---@alias PullCommand { itemName: string, count: number, slot: number }

---@alias StorageCountData table<string, number?>
---@alias CraftCommands (PullCommand[])[]

---Check if there are enough items for a single recipe in storage
---@param recipe Recipe The recipe to check
---@param craftCount number The number of times to repeat the recipe
---@param itemCounts StorageCountData The counts of items in storage (or not in storage)
---@param craftCommands CraftCommands The commands to craft the items
---@param cannotFillList table<string, boolean> The map of items that can't be crafted
---@return StorageCountData, CraftCommands
local function check_storage(recipe, craftCount, itemCounts, craftCommands, cannotFillList)
    craftCount = math.ceil(craftCount / recipe.output.count)

    local newItemCounts = tableHelpers.copy(itemCounts)
    local nextCraftCommands = tableHelpers.copy(craftCommands)
    local pullCommands = {}

    local totalSlots = 0
    local filledSlots = 0

    if recipeLoops == nil then
        recipeLoops = getRemoteItem("recipe_loops", "loops")
        if not recipeLoops then
            logger:error("Failed to get recipe loops")
            return itemCounts, {}
        end
    end

    local itemRecipeLoops = recipeLoops[getItemStub(recipe.output.id)]

    -- for slot in recipe inputs
    for slotStr, slotItemNames in pairs(recipe.input) do
        totalSlots = totalSlots + 1

        local slotNumber = tonumber(slotStr)
        if slotNumber == nil then
            logger:error("Failed to parse slot number")
            return itemCounts, {}
        end

        local triedPullAllItems = false

        ::retryPulls::

        -- for item in slot
        for _, slotItemName in pairs(slotItemNames) do
            if cannotFillList[slotItemName] then
                -- previously established that we craft this item, so there's no point trying
                -- we also can't pull the item - if we could, we would have done so already
                goto nextItem
            end

            if newItemCounts[slotItemName] == nil then
                -- we don't have the count for this item yet
                local itemCountRes, itemCountData = storageClient:getItemCount(slotItemName)

                if not itemCountRes or itemCountData == nil then
                    logger:error("Failed to get item count for %s", slotItemName)
                    goto nextItem
                end

                newItemCounts[slotItemName] = itemCountData.count
            end

            local didRetrySlotPull = false
            ::retrySlotPull::

            if newItemCounts[slotItemName] >= craftCount then
                -- have enough items in storage, so don't need to craft
                table.insert(pullCommands, {
                    itemName = slotItemName,
                    count = craftCount,
                    slot = slotNumber,
                })

                newItemCounts[slotItemName] = newItemCounts[slotItemName] - craftCount

                filledSlots = filledSlots + 1

                goto nextSlot
            else
                if not triedPullAllItems then
                    -- not tried all the pulls yet, so don't try crafting yet
                    goto nextItem
                end
                -- need to craft
                if itemRecipeLoops and tableHelpers.valuesContain(itemRecipeLoops, getItemStub(slotItemName)) then
                    goto nextItem
                end

                logger:debug("Not enough %s in storage (%d/%d)", slotItemName, newItemCounts[slotItemName], craftCount)

                -- need to craft the item
                local nextRecipes

                if slotItemName:sub(1, 1) == "#" then
                    nextRecipes = get_tag_recipes(slotItemName)
                else
                    nextRecipes = fetch_recipe_remote(slotItemName)
                end

                if not nextRecipes then
                    -- recipe doesn't exist, so can't craft the item
                    cannotFillList[slotItemName] = true
                    goto nextItem
                end

                for _, nextRecipe in pairs(nextRecipes) do
                    local nextRepeatCount = math.ceil(craftCount / nextRecipe.output.count)

                    local postCraftItemCounts, postCraftCraftCommands = check_storage(nextRecipe, nextRepeatCount, itemCounts, craftCommands, cannotFillList)

                    if tableHelpers.tableIsEmpty(postCraftCraftCommands) then
                        -- can't craft with this recipe
                        -- logger:error("Failed to get pre-craft commands for %s", slotItemName)
                        goto nextRecipeLoop
                    end

                    for i, command in ipairs(postCraftCraftCommands) do
                        table.insert(nextCraftCommands, i, command)
                    end

                    newItemCounts = postCraftItemCounts

                    if not didRetrySlotPull then
                        didRetrySlotPull = true
                        goto retrySlotPull
                    end
                    ::nextRecipeLoop::
                end

                -- tried all the recipes for this item
                if not tableHelpers.tableIsEmpty(nextCraftCommands) then
                    -- can craft the item
                    cannotFillList[slotItemName] = nil
                    goto nextSlot
                else
                    -- can't craft this item, try the next item
                    cannotFillList[slotItemName] = true
                    goto nextItem
                end
            end
            ::nextItem::
        end

        -- couldn't get the item from storage
        if not triedPullAllItems then
            triedPullAllItems = true
            goto retryPulls
        end

        local itemNamesString = table.concat(slotItemNames, ",")

        local logFunc = #itemCounts > 0 and logger.warn or logger.error
        logFunc(logger, "Couldn't fill slot %d with %s for %s", slotNumber, itemNamesString, getItemStub(recipe.output.id))

        do
            return itemCounts, {}
        end

        ::nextSlot::
    end

    if filledSlots >= totalSlots then
        -- have enough items in storage to craft the recipe
        newItemCounts[recipe.output.id] = (newItemCounts[recipe.output.id] or 0) + (recipe.output.count * craftCount)

        table.insert(nextCraftCommands, pullCommands)
    else
        -- not enough items in storage to craft the recipe
        return itemCounts, {}
    end

    return newItemCounts, nextCraftCommands
end


---Craft an item
---@param craftItemName string The name of the item to craft
---@param craftCount number The number of items to craft
---@param doCheck boolean Whether to only check if the item can be crafted, and not actually craft it
---@param pullAfterCraft boolean Whether to pull the crafted item into the output chest after crafting
---@return boolean
local function craft_item(craftItemName, craftCount, doCheck, pullAfterCraft)
    if remoteName == nil then
        local remoteNameRes, remoteNameData = craftClient:getLocalName()
        remoteName = remoteNameData and remoteNameData.localName or nil
        if remoteName == nil then
            logger:error("Failed to get remote name")
            return false
        end

        settings.set("crafter.modemLocalName", remoteName)
        settings.save()
    end

    if craftCount > 64 then
        logger:error("Can't craft more than 64 items at a time")
        return false
    end

    local recipes = nil

    if craftItemName:sub(1, 1) == "#" then
        recipes = get_tag_recipes(craftItemName)
    else
        recipes = fetch_recipe_remote(craftItemName)
    end

    if recipes == nil then
        return false
    end

    local didCraft = false

    for recipeNumber, recipe in ipairs(recipes) do
        local itemCounts = {}
        local craftCommands = {}
        local cannotCraftList = {}

        local recipeItemCount, recipeCraftCommands = check_storage(recipe, craftCount, itemCounts, craftCommands, cannotCraftList)

        if tableHelpers.tableIsEmpty(recipeCraftCommands) then
            logger:error("%s recipe %d/%d failed", craftItemName, recipeNumber, #recipes)

            if recipeNumber == #recipes then
                if doCheck then
                    logger:info("Can't craft %d %s", craftCount, craftItemName)
                    return true
                end

                logger:error("Failed to craft %d %s", craftCount, craftItemName)
                return false
            end

            goto nextRecipe
        end

        if doCheck then
            logger:info("Can craft %d %s", craftCount, craftItemName)
            return true
        end

        transfer_all_slots(remoteName)

        for _, commandBatch in ipairs(recipeCraftCommands) do
            for _, command in ipairs(commandBatch) do
                local pullRes, pullData = storageClient:callCommand(storageClient.pull, remoteName, command.itemName, command.count, command.slot, false)

                if pullRes and pullData and pullData.count > 0 then
                    -- got it
                else
                    logger:warn("Failed to pull " .. command.itemName .. " from storage")
                    transfer_all_slots(remoteName)
                    return false
                end
            end

            local success, craftErrors = craftClient:craft(craftCount)

            transfer_all_slots(remoteName)

            if not success then
                local errorMessage = craftErrors and craftErrors.error or "Unknown error"
                logger:error("Failed to craft %s %s", craftItemName, errorMessage)
                return false
            else
                didCraft = true
            end
        end

        if didCraft then
            break
        end

        ::nextRecipe::
    end

    if not didCraft then
        logger:error("Failed to craft %d %s", craftCount, craftItemName)
        return false
    end

    logger:info("Crafted %d %s", craftCount, craftItemName)

    if pullAfterCraft then
        local storageOutputChest = settings.get("storage2.outputChest")
        if not storageClient:pull(storageOutputChest, craftItemName, craftCount) then
            logger:error("Failed to pull %d %s from storage", craftCount, craftItemName)
        end
    end

    return true
end


return {
    fetch_recipe_remote = fetch_recipe_remote,
    getRemoteItem = getRemoteItem,
    craft_item = craft_item,
}
