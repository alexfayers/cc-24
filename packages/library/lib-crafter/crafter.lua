package.path = package.path .. ";/usr/lib/?.lua"

require("lib-crafter.CraftClient")
require("lib-storage2.remote.StorageClient")

local logger = require("lexicon-lib.lib-logging").getLogger("Crafter")

local BASE_RECIPE_URL = "https://raw.githubusercontent.com/alexfayers/cc-24/refs/heads/main/helper/autocrafter/recipes/"

local craftClient = CraftClient()
local storageClient = StorageClient()


settings.define("crafter.outputChestName", {
    description = "The name of the chest to output crafted items to",
    type = "string",
})

local outputChestName = settings.get("crafter.outputChestName")

if outputChestName == nil then
    logger:error("No output chest defined. Set crafter.outputChestName")
    return
end

local outputChest = peripheral.wrap(outputChestName)

if outputChest == nil then
    logger:error("Failed to wrap output chest")
    return
end
---@cast outputChest ccTweaked.peripherals.Inventory


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

    return recipeTable
end


---Transfer a slot from the crafter to the output chest
---@param crafterName string The name of the crafter
---@param slot number The slot to transfer
---@return boolean
local function transfer_slot(crafterName, slot)
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
    for slot = 1, 16 do
        local success = transfer_slot(crafterName, slot)

        if not success then
            return false
        end
    end

    return true
end


---Craft an item
---@param craftItemName string The name of the item to craft
---@param craftCount number The number of items to craft
---@return boolean
local function craft_item(craftItemName, craftCount)
    local recipes = fetch_recipe_remote(craftItemName)

    if recipes == nil then
        return false
    end

    local remoteNameRes, remoteNameData = craftClient:getLocalName()
    local remoteName = remoteNameData and remoteNameData.localName or nil
    if remoteName == nil then
        logger:error("Failed to get remote name")
        return false
    end

    local filledSlots = 0
    local totalSlots = 0
    for _, recipe in pairs(recipes) do
        filledSlots = 0
        totalSlots = 0

        local outputCount = recipe["output"]["count"]
        local repeatCount = math.ceil(craftCount / outputCount)

        for slotStr, slotItemNames in pairs(recipe.input) do
            totalSlots = totalSlots + 1

            local slotNumber = tonumber(slotStr)
            if slotNumber == nil then
                logger:error("Failed to parse slot number")
                return false
            end

            for _, slotItemName in pairs(slotItemNames) do
                local pullRes, pullData = storageClient:callCommand(storageClient.pull, remoteName, slotItemName, craftCount, slotNumber)

                if pullRes and pullData and pullData.count > 0 then
                    -- logger:info("Pulled " .. slotItemName .. " from storage")
                    filledSlots = filledSlots + 1
                    goto nextSlot
                else
                    -- logger:error("Failed to pull " .. slotItemName .. " from storage")
                    goto nextItem
                end
                ::nextItem::
            end
            ::nextSlot::
        end

        if filledSlots == totalSlots then
            logger:info("Pulled all items for " .. craftItemName)
            break
        end
    end

    if filledSlots < totalSlots then
        logger:error("Failed to pull all items for " .. craftItemName)
        transfer_all_slots(remoteName)
        return false
    end

    local success, craftErrors = craftClient:craft(craftCount)

    if craftErrors then
        logger:error("Failed to craft %s: %s", craftItemName, craftErrors.error)
        return false
    end

    transfer_all_slots(remoteName)

    if not success then
        logger:error("Failed to craft " .. craftItemName)
        return false
    end

    logger:info("Crafted " .. craftItemName)
    return true
end


return {
    fetch_recipe_remote = fetch_recipe_remote,
    craft_item = craft_item,
}
