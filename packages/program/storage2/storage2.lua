-- Cli interface for the storage2 module
package.path = package.path .. ";/usr/lib/?.lua"

local chestHelpers = require("lib-storage2.chestHelpers")
local storageHelpers = require("lib-storage2.helpers")
local terminal = require("lexicon-lib.lib-term")
require("lib-storage2.Map")
local completion = require("cc.completion")

-- consts

local inputChest = chestHelpers.getInputChest()
if not inputChest then
    return
end

local outputChest = chestHelpers.getOutputChest()
if not outputChest then
    return
end

local storageMap = nil

---Get the cached storage map
---@return Map
local function cachedStorageMap()
    if storageMap then
        return storageMap
    end

    local storageChests = chestHelpers.getStorageChests(inputChest, outputChest)
    if not storageChests then
        error("Failed to get storage chests", 0)
    end

    storageMap = Map(storageChests)
    storageMap:save()

    return storageMap
end


-- functions

local function help()
    print("Usage: storage2 <command>")
    print("Commands:")
    print("  pull <item> [amount]")
    print("    Pull items from the storage chests to the output chest")
    print("  push [shulker]")
    print("    Push items from the input chest to the storage chests")
    print("  remap")
    print("    Force a remap the storage chests")
    print("  undo")
    print("    Push items from the output chest back to the storage chests")
    print("  check")
    print("    Check the storage chests for any differences from the storage map")
    print("  usage")
    print("    Display the usage and capacity of the storage chests")
    print("  help")
    print("    Display this help message")
end

---Argument completion for the script
---@param _ any
---@param index number The index of the argument
---@param argument string The current arguments
---@param previous table A table of the previous arguments
---@return table? _ A table of possible completions
local function complete(_, index, argument, previous)
    local previousArg = previous[#previous]

    if index == 1 then
        return completion.choice(argument, {"pull", "push", "remap", "undo", "check", "usage", "help"}, true)
    elseif index == 2 then
        if previousArg == "pull" then
            
            return completion.choice(argument, cachedStorageMap():getAllItemStubs(), previousArg == "pull")
        elseif previousArg == "push" then
            return completion.choice(argument, {"shulker"}, false)
        end
    elseif index == 3 then
        if previousArg == "pull" then
            return completion.choice(argument, {"all"}, false)
        end
    end
    
    return {}
end

shell.setCompletionFunction(shell.getRunningProgram(), complete)


---Show all item matches for a given item stub/search
---@param item string The item stub to search for
---@return nil
local function showItemMatches(item)
    local matches = cachedStorageMap():searchItemNames(item)

    if #matches == 0 then
        print("No matches found for '" .. item .. "'")
        return
    end

    print("Matches for '" .. item .. "':")
    for _, match in pairs(matches) do
        local count = cachedStorageMap():getTotalItemCount(match)
        print("  " .. match .. " (" .. count .. ")")
    end
end


---Show the usage and capacity of the storage chests
---@return nil
local function showUsage()
    local allSlots = cachedStorageMap():getAllSlots()
    local fullSlotCount = #cachedStorageMap():getFullSlots()
    local allSlotsCount = #allSlots

    print("Usage:")

    print(
        "  Slots: " .. fullSlotCount .. "/" .. allSlotsCount ..
        " (" .. math.floor(fullSlotCount / allSlotsCount * 100) .. "%)"
    )

    local itemCount = cachedStorageMap().getTotalCount(allSlots)
    local maxItemCount = cachedStorageMap().getTotalMaxCount(allSlots)
    print(
        "  Items:  " .. itemCount .. "/" .. maxItemCount ..
        " (" .. math.floor(itemCount / maxItemCount * 100) .. "%)"
    )
end


---Wrap a shulker box if it exists
---@return ccTweaked.peripherals.Inventory?
local function wrapShulkerIfExists()
    local wrappedShulker = peripheral.find("inventory", function(name, wrapped)
        return string.match(name, "shulker_box")
    end)

    if wrappedShulker then
        return storageHelpers.ensureInventory(wrappedShulker)
    end

    return
end



---Main function for the script. Handles the command line interface.
---@return nil
local function main()
    if #arg == 0 then
        help()
        return
    end

    local command = arg[1]

    if command == "push" then
        local chestType = arg[2]
        if chestType == "shulker" then
            local shulker = wrapShulkerIfExists()
            if not shulker then
                print("No shulker box found")
                return
            end

            inputChest = shulker
        end
            
        cachedStorageMap():push(inputChest)
        cachedStorageMap():save()
    elseif command == "usage" then
        showUsage()
    elseif command == "remap" then
        cachedStorageMap():populate(true)
        cachedStorageMap():save()
    elseif command == "check" then
        cachedStorageMap():checkDiffs()
    elseif command == "pull" then
        if #arg < 2 then
            help()
            return
        end

        local item = arg[2]
        local amountStr = arg[3]
        local amount = 0

        if not amountStr then
            showItemMatches(item)
            return
        end

        if amountStr == "all" then
            amount = cachedStorageMap():getTotalItemCount(item, true)
        else
            local amountMaybe = tonumber(amountStr)
            if amountMaybe == nil then
                amountMaybe = 0
            end
            amount = amountMaybe
        end

        if not amount then
            help()
            return
        end

        cachedStorageMap():pull(outputChest, item, amount, true)
        cachedStorageMap():save()
    elseif command == "undo" then
        cachedStorageMap():push(outputChest)
        cachedStorageMap():save()
    elseif command == "help" then
        help()
    else
        help()
    end
end

main()
