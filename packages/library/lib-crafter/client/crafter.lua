package.path = package.path .. ";/usr/lib/?.lua"

require("lib-crafter.client.CraftClient")
require("lib-storage2.remote.StorageClient")

local tableHelpers = require("lexicon-lib.lib-table")

local logger = require("lexicon-lib.lib-logging").getLogger("Crafter")

local BASE_RECIPE_URL = "https://raw.githubusercontent.com/alexfayers/cc-24/refs/heads/main/helper/autocrafter/recipes/"
local BASE_TAG_URL = "https://raw.githubusercontent.com/alexfayers/cc-24/refs/heads/autocrafter/helper/autocrafter/tags/"

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

---@type ccTweaked.peripherals.Inventory?
local outputChest = nil

---@type string?
local remoteName = settings.get("crafter.modemLocalName")


local function getItemStub(itemName)
    return itemName:match(".*:(.*)") or itemName
end


---Convert an item tag to a list of items, recursively
---@param tag string The tag to convert
---@return string[]?
local function tag_to_items(tag)
    local items = {}

    if tag:sub(1, 1) == "#" then
        local tagItems = getItemStub(tag:sub(2))
        local tagItemsUrl = BASE_TAG_URL .. tagItems .. ".json" .. "?token=" .. os.epoch("utc")
        local response = http.get(tagItemsUrl)

        if response == nil then
            logger:error("Failed to fetch tag items for " .. tag)
            return
        end

        local responseCode = response.getResponseCode()

        if responseCode ~= 200 then
            logger:error("Failed to fetch tag items for " .. tag .. " (" .. responseCode .. ")")
            response.close()
            return
        end

        local tagItemsJson = response.readAll()
        response.close()

        if tagItemsJson == nil then
            logger:error("Tag items was empty for " .. tag)
            return
        end

        local tagItemsTable = textutils.unserializeJSON(tagItemsJson)

        if tagItemsTable == nil then
            logger:error("Failed to parse tag items for " .. tag)
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
    itemName = itemName:match(".*:(.*)") or itemName

    local url = BASE_RECIPE_URL .. itemName .. ".json" .. "?token=" .. os.epoch("utc")
    local response = http.get(url)

    local doReturn = false

    if response == nil then
        logger:error("Failed to fetch recipe for " .. itemName)
        return
    end

    local responseCode = response.getResponseCode()

    if responseCode == 404 then
        logger:warn("Recipe for " .. itemName .. " not found")
        doReturn = true
    elseif responseCode ~= 200 then
        logger:error("Failed to fetch recipe for " .. itemName .. " (" .. responseCode .. ")")
        doReturn = true
    end

    if doReturn == true then
        response.close()
        return
    end

    local recipe = response.readAll()
    response.close()

    if recipe == nil then
        logger:error("Recipe was empty for " .. itemName)
        return
    end

    local recipeTable = textutils.unserializeJSON(recipe)

    if recipeTable == nil then
        logger:error("Failed to parse recipe for " .. itemName)
        return
    end

    for _, subRecipeTable in ipairs(recipeTable) do
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
                        table.insert(slotItems, tagItem)
                    end
                else
                    table.insert(slotItems, slotItemName)
                end
            end
    
            subRecipeTable.input[slotStr] = slotItems
        end
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
        logger:info("Pushed %d items to storage", pushData.count)
        return true
    else
        return false
    end
end



---Transfer a slot from the crafter to the output chest
---@param crafterName string The name of the crafter
---@param slot number The slot to transfer
---@return boolean
local function transfer_slot(crafterName, slot)
    if not ensureOutputChest() then
        return false
    end
    ---@cast outputChest ccTweaked.peripherals.Inventory

    local pullCount = outputChest.pullItems(crafterName, slot)

    if pullCount > 0 then
        logger:info("Pulled %d items from crafter", pullCount)
        return true
    else
        return false
    end
end


---Transfer all slots from the crafter to the output chest
---@param crafterName string The name of the crafter
---@return boolean
local function transfer_all_slots(crafterName)
    if not ensureOutputChest() then
        return false
    end

    local didTransfer = false

    local transferTasks = {}
    for slot = 1, 16 do
        table.insert(transferTasks, function ()
            local success = transfer_slot(crafterName, slot)
    
            if success and not didTransfer then
                didTransfer = true
            end
        end)
    end

    parallel.waitForAll(table.unpack(transferTasks))

    if didTransfer then
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


---Craft an item
---@param craftItemName string The name of the item to craft
---@param craftCount number The number of items to craft
---@param previousCraftAttemptItems string[]? The items that have already been attempted to craft
---@param previousPullFailedItems string[]? The items that have failed to pull
---@return boolean
local function craft_item(craftItemName, craftCount, previousCraftAttemptItems, previousPullFailedItems)
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

    if previousCraftAttemptItems == nil then
        previousCraftAttemptItems = {}
    end

    if previousPullFailedItems == nil then
        previousPullFailedItems = {}
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

    local filledSlots = 0
    local totalSlots = 0

    for _, recipe in pairs(recipes) do
        filledSlots = 0
        totalSlots = 0

        local outputCount = recipe.output.count
        local repeatCount = math.ceil(craftCount / outputCount)

        for slotStr, slotItemNames in pairs(recipe.input) do
            totalSlots = totalSlots + 1

            local slotNumber = tonumber(slotStr)
            if slotNumber == nil then
                logger:error("Failed to parse slot number")
                return false
            end

            local doCraftBeforePull = false
            ::retryPulls::
            for _, slotItemName in pairs(slotItemNames) do
                if doCraftBeforePull  then
                    if tableHelpers.valuesContain(previousCraftAttemptItems, slotItemName) then
                        goto nextItem
                    end

                    table.insert(previousCraftAttemptItems, slotItemName)
                    if not craft_item(slotItemName, repeatCount, previousCraftAttemptItems, previousPullFailedItems) then
                        goto nextItem
                    else
                        --- Remove the item from the previousCraftAttemptItems list if it was successfully crafted
                        for previousPullFailedItemsIndex, previousPullFailedItem in pairs(previousPullFailedItems) do
                            if previousPullFailedItem == slotItemName then
                                table.remove(previousPullFailedItems, previousPullFailedItemsIndex)
                            end
                        end
                    end
                end

                if tableHelpers.valuesContain(previousPullFailedItems, slotItemName) then
                    goto nextItem
                end

                local pullRes, pullData = storageClient:callCommand(storageClient.pull, remoteName, slotItemName, repeatCount, slotNumber, false)

                if pullRes and pullData and pullData.count > 0 then
                    -- logger:info("Pulled " .. slotItemName .. " from storage")
                    filledSlots = filledSlots + 1
                    goto nextSlot
                else
                    logger:warn("Failed to pull " .. slotItemName .. " from storage")
                    table.insert(previousPullFailedItems, slotItemName)
                    goto nextItem
                end
                ::nextItem::
            end
            if not doCraftBeforePull then
                doCraftBeforePull = true
                transfer_all_slots(remoteName)
                goto retryPulls
            end

            ::nextSlot::
        end

        if filledSlots == totalSlots then
            logger:info("Pulled %d %s ", filledSlots, craftItemName)
            break
        end
    end

    if filledSlots < totalSlots then
        logger:error("Can't craft %s", craftItemName)
        transfer_all_slots(remoteName)
        return false
    end

    local success, craftErrors = craftClient:craft(craftCount)

    transfer_all_slots(remoteName)

    if not success then
        local errorMessage = craftErrors and craftErrors.error or "Unknown error"
        logger:error("Failed to craft %s %s", craftItemName, errorMessage)
        return false
    end

    logger:info("Crafted " .. craftItemName)
    return true
end


return {
    fetch_recipe_remote = fetch_recipe_remote,
    craft_item = craft_item,
}
