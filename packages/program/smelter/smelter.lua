--- Auto smelter
package.path = package.path .. ";/usr/lib/?.lua"

local completion = require("cc.completion")

local logger = require("lexicon-lib.lib-logging").getLogger("smelter")
local discord = require("lib-discord.discord")

--- types

---@class furnaceMapItem 
---@field currentFuelCount number
---@field currentFuelPower number
---@field pendingSmeltItems number
---@field smeltedItems number
---@field wrappedFurnace ccTweaked.peripherals.Inventory
---@field wrappedFurnaceName string


--- Constants

local FURNACE_TYPE = "minecraft:furnace"

local FURNANCE_SMELT_TIME_SECS = 10

local FURNACE_SLOT_MAX = 64

local FUEL_MAP = {
    ["minecraft:coal"] = 8,
    ["minecraft:charcoal"] = 8,
}

local FURNACE_INPUT_SLOT = 1
local FURNACE_FUEL_SLOT = 2
local FURNACE_OUTPUT_SLOT = 3

---@type table<number, furnaceMapItem>
local FURNACE_MAP = {}


---@diagnostic disable-next-line: param-type-mismatch
local inputOutputChest = peripheral.find("minecraft:chest")

if not inputOutputChest then
    logger:error("Input/output chest not found")
    return
end

--- functions

---Initialise the furnace map
local function initSingleFurnace(furnaceIndex, furnace)
    local itemList = furnace.list()
    local inputItem = itemList[FURNACE_INPUT_SLOT]
    local fuelItem = itemList[FURNACE_FUEL_SLOT]
    local outputItem = itemList[FURNACE_OUTPUT_SLOT]

    local fuelPower = 0

    if fuelItem then
        fuelPower = FUEL_MAP[fuelItem.name] or 0
    end

    FURNACE_MAP[furnaceIndex] = {
        currentFuelCount = fuelItem and fuelItem.count or 0,
        currentFuelPower = fuelPower,
        pendingSmeltItems = inputItem and inputItem.count or 0,
        smeltedItems = outputItem and outputItem.count or 0,
        wrappedFurnace = furnace,
        wrappedFurnaceName = peripheral.getName(furnace),
    }
end


---Populate the furnace map
---@return boolean # Whether the map was populated successfully
local function populateFurnaceMap()
    ---@diagnostic disable-next-line: param-type-mismatch
    local furnaces = { peripheral.find(FURNACE_TYPE) }
    ---@cast furnaces ccTweaked.peripherals.Inventory[]

    if #furnaces == 0 then
        logger:error("No furnaces found")
        return false
    end

    local threads = {}

    for furnaceIndex, furnace in ipairs(furnaces) do
        table.insert(threads, function ()
            initSingleFurnace(furnaceIndex, furnace)
        end)
    end

    parallel.waitForAll(table.unpack(threads))

    return true
end


---Process a smelt that uses a single fuel for a furnace
---@param furnace furnaceMapItem The index of the furnace
local function doSmeltSingleFuel(furnace)
    if furnace.currentFuelCount <= 0 then
        logger:warn("%s out of fuel", furnace.wrappedFurnaceName)
        return
    end

    furnace.currentFuelCount = furnace.currentFuelCount - 1

    for i = 1, furnace.currentFuelPower do
        os.sleep(FURNANCE_SMELT_TIME_SECS)
        furnace.pendingSmeltItems = furnace.pendingSmeltItems - 1
        furnace.smeltedItems = furnace.smeltedItems + 1

        if furnace.pendingSmeltItems <= 0 then
            logger:info("%s smelted %d items", furnace.wrappedFurnaceName, furnace.smeltedItems)
            break
        end
    end
end


---Process all the fuel ticks for a furnace
---@param furnace furnaceMapItem The index of the furnace
local function doFuelTicks(furnace)
    if furnace.currentFuelCount <= 0 then
        logger:info("%s has no fuel", furnace.wrappedFurnaceName)
        return
    end

    for _ = 1, furnace.currentFuelCount do
        doSmeltSingleFuel(furnace)
    end
end


---Process all the fuel ticks for all furnaces, in parallel
local function doAllFuelTicks()
    local threads = {}

    for _, furnace in pairs(FURNACE_MAP) do
        table.insert(threads, function ()
            doFuelTicks(furnace)
        end)
    end

    parallel.waitForAll(table.unpack(threads))
end


---Get the number of furnaces in the map
---@return number # The number of furnaces
local function getFurnaceCount()
    local count = 0

    for _ in pairs(FURNACE_MAP) do
        count = count + 1
    end

    return count
end


---Distribute fuel from the IO chest to the furnaces
---@return number # The number of fuel items distributed
local function distributeFuel()
    local totalTransferred = 0

    local fuelItems = inputOutputChest.list()

    local threads = {}

    local furnaceCount = getFurnaceCount()

    for fuelItemSlot, fuelItem in pairs(fuelItems) do
        if FUEL_MAP[fuelItem.name] then
            local maxFuelPerFurnace = math.ceil(fuelItem.count / furnaceCount)

            for _, furnace in pairs(FURNACE_MAP) do
                table.insert(threads, function ()
                    local fuelToTransfer = math.min(maxFuelPerFurnace, fuelItem.count)
                    local transferred = inputOutputChest.pushItems(furnace.wrappedFurnaceName, fuelItemSlot, fuelToTransfer, FURNACE_FUEL_SLOT)

                    if transferred then
                        furnace.currentFuelCount = furnace.currentFuelCount + transferred

                        totalTransferred = totalTransferred + transferred
                    end
                end)
            end
        end
    end

    parallel.waitForAll(table.unpack(threads))

    logger:info("Distributed %d fuel items", totalTransferred)

    return totalTransferred
end


---Distribute items from the IO chest to the furnaces
---@return number # The number of items distributed
local function distributeItems()
    local totalTransferred = 0

    local itemSlots = inputOutputChest.list()

    local threads = {}

    local furnaceCount = getFurnaceCount()

    for itemSlot, item in pairs(itemSlots) do
        local maxItemsPerFurnace = math.ceil(item.count / furnaceCount)

        for _, furnace in pairs(FURNACE_MAP) do
            table.insert(threads, function ()
                local itemsToTransfer = math.min(maxItemsPerFurnace, item.count)
                local transferred = inputOutputChest.pushItems(furnace.wrappedFurnaceName, itemSlot, itemsToTransfer, FURNACE_INPUT_SLOT)

                if transferred then
                    furnace.pendingSmeltItems = furnace.pendingSmeltItems + transferred

                    totalTransferred = totalTransferred + transferred
                end
            end)
        end
    end

    parallel.waitForAll(table.unpack(threads))

    logger:info("Distrubuted %d items", totalTransferred)

    return totalTransferred
end


---Pull all smelted items from the furnaces to the IO chest
---@return number # The number of items pulled
local function pullItems()
    local totalTransferred = 0

    local threads = {}

    for _, furnace in pairs(FURNACE_MAP) do
        table.insert(threads, function ()
            local smeltedItems = furnace.wrappedFurnace.list()[FURNACE_OUTPUT_SLOT]

            if smeltedItems then
                local transferred = inputOutputChest.pullItems(furnace.wrappedFurnaceName, FURNACE_OUTPUT_SLOT, smeltedItems.count)

                if transferred then
                    furnace.smeltedItems = furnace.smeltedItems - transferred

                    totalTransferred = totalTransferred + transferred
                end
            end
        end)
    end

    parallel.waitForAll(table.unpack(threads))

    logger:info("Pulled %d items", totalTransferred)

    return totalTransferred
end


---Refuel
---@return number? # The number of fuel items distributed
local function refuel()
    if not populateFurnaceMap() then
        return
    end

    return distributeFuel()
end


---Smelt items in the furnaces, wait for all to finish, then pull the smelted items
---@return number? # The number of items smelted
local function smelt()
    if not populateFurnaceMap() then
        return
    end

    local distrubuted = distributeItems()

    doAllFuelTicks()

    local pulled = pullItems()

    logger:info("Smelted %d/%d items", pulled, distrubuted)
    discord.send("Smelter", "Smelted " .. pulled .. "/" .. distrubuted .. " items")

    return pulled
end


---Argument completion for the script
---@param _ any
---@param index number The index of the argument
---@param argument string The current arguments
---@param previous table
---@return table? _ A table of possible completions
local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, {"refuel", "smelt"}, false)
    end

    return {}
end


---Help message
local function help()
    print("Usage: smelter <command>")
    print("Commands:")
    print("  refuel")
    print("    Distribute fuel from the input chest to the furnaces")
    print("  smelt")
    print("    Smelt items in the furnaces")
end


---Main
local function main()
    if #arg == 0 then
        help()
        return
    end

    local command = arg[1]

    if command == "refuel" then
        refuel()
    elseif command == "smelt" then
        smelt()
    else
        help()
    end
end


shell.setCompletionFunction(shell.getRunningProgram(), complete)

main()