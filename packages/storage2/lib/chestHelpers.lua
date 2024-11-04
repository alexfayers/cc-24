-- Storage management system for computercraft
package.path = package.path .. ";/usr/lib/?.lua"

-- imports
require("class-lua.class")

local pretty = require("cc.pretty")
local logging = require("lexicon-lib.lib-logging")

-- Local lib imports
require("storage2.lib.MapSlot")
require("storage2.lib.Settings")

local helpers = require("storage2.lib.helpers")

-- constants

local logger = logging.getLogger("storage2")
logger:setLevel(logging.LEVELS.INFO)


-- functions


---Get the wrapped input chest
---@return ccTweaked.peripherals.Inventory|nil
local function getInputChest()
    local inputChestName = settings.get("storage2.inputChest")
    local inputChest = peripheral.wrap(inputChestName)

    if not inputChest then
        logger:error("Input chest not found. You may need to change the inputChest setting (set storage2.inputChest {chest name}).")
        return
    end

    inputChest = helpers.ensureInventory(inputChest); if not inputChest then return end

    return inputChest
end

---Get the wrapped output chest
---@return ccTweaked.peripherals.Inventory|nil
local function getOutputChest()
    local outputChestName = settings.get("storage2.outputChest")
    local outputChest = peripheral.wrap(outputChestName)

    if not outputChest then
        logger:error("Output chest not found. You may need to change the outputChest setting (set storage2.outputChest {chest name}).")
        return
    end

    outputChest = helpers.ensureInventory(outputChest); if not outputChest then return end

    return outputChest
end

---Get the wrapped storage chests table
---@param inputChest table The input chest
---@param outputChest table The output chest
---@return ccTweaked.peripherals.Inventory[]|nil
local function getStorageChests(inputChest, outputChest)
    local inputChestName = peripheral.getName(inputChest)
    local outputChestName = peripheral.getName(outputChest)

    local chests = {
        peripheral.find("inventory", function(name, _)
            return name ~= inputChestName and name ~= outputChestName
        end)
    }
    ---@cast chests ccTweaked.peripherals.Inventory[]

    if #chests == 0 then
        logger:error("No storage chests found. Add more chests to the network!")
        return
    end

    return chests
end


return {
    getInputChest = getInputChest,
    getOutputChest = getOutputChest,
    getStorageChests = getStorageChests,
}
