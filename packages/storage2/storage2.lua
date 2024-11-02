-- Cli interface for the storage2 module
package.path = package.path .. ";/usr/lib/?.lua"

local storage = require("storage2.lib-storage2")
local terminal = require("lexicon-lib.lib-term")
local completion = require("cc.completion")

-- consts

local inputChest = storage.getInputChest()
if not inputChest then
    return
end

local outputChest = storage.getOutputChest()
if not outputChest then
    return
end

local storageChests = storage.getStorageChests(inputChest, outputChest)
if not storageChests then
    return
end

local storageMapPath = storage.getStorageMapPath()

local storageMap = storage.loadOrPopulateStorageMap(storageMapPath, storageChests)
storage.saveStorageMap(storageMapPath, storageMap)


-- functions

local function help()
    print("Usage: storage2 <command>")
    print("Commands:")
    print("  pull <item> [amount]")
    print("    Pull items from the storage chests to the output chest")
    print("  push")
    print("    Push items from the input chest to the storage chests")
    print("  search <regex>")
    print("    Search storage using a regex")
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
---@return table _ A table of possible completions
local function complete(_, index, argument, previous)
    local previousArg = previous[#previous]

    if index == 1 then
        return completion.choice(argument, {"pull", "push", "search", "usage", "help"}, true)
    elseif index == 2 then
        if previousArg == "pull" then
            return completion.choice(argument, storage.getAllItemStubs(storageMap), previousArg == "pull")
        end
    elseif index == 3 then
        if previousArg == "pull" then
            return completion.choice(argument, {"all"}, false)
        end
    end
    
    return {}
end

shell.setCompletionFunction(shell.getRunningProgram(), complete)


---Show the amount of a specific item in the storage chests
---@param item string The item to check
---@return nil
local function checkItem(item)
    local itemCount = storage.getTotalItemCount(storageMap, item, false)

    if itemCount > 0 then
        print("Item: " .. item)
        print("Amount: " .. itemCount)
    else
        print("'" .. item .. "' is not available")
    end
end


---Show all item matches for a given item stub/search
---@param item string The item stub to search for
---@return nil
local function showItemMatches(item)
    local matches = storage.getAllMatches(storageMap, item)

    if #matches == 0 then
        print("No matches found for '" .. item .. "'")
        return
    end

    print("Matches for '" .. item .. "':")
    for _, match in pairs(matches) do
        local count = storage.getTotalItemCount(storageMap, match, false)
        print("  " .. match .. " (" .. count .. ")")
    end
end


---Show the usage and capacity of the storage chests
---@return nil
local function showUsage()
    local allSlots = storage.getAllSlots(storageMap)
    local fullSlotCount = storage.getFullSlots(allSlots)
    local allSlotsCount = #allSlots

    print("Usage:")

    print(
        "  Slots: " .. fullSlotCount .. "/" .. allSlotsCount ..
        " (" .. math.floor(fullSlotCount / allSlotsCount * 100) .. "%)"
    )

    local itemCount = storage.getTotalCount(allSlots)
    local maxItemPrediction = storage.CHEST_SLOT_MAX * allSlotsCount
    print(
        "  Items:  " .. itemCount .. "/" .. maxItemPrediction ..
        " (" .. math.floor(itemCount / maxItemPrediction * 100) .. "%)"
    )
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
        storageMap = storage.pushItems(storageMap, inputChest)
        storage.saveStorageMap(storageMapPath, storageMap)
    elseif command == "search" then
        if #arg < 2 then
            help()
            return
        end

        showItemMatches(arg[2])
    elseif command == "usage" then
        showUsage()
    elseif command == "pull" then
        if #arg < 2 then
            help()
            return
        end

        local item = arg[2]
        -- item = storage.convertItemNameStub(item)
        local amountStr = arg[3]
        local amount = 0

        if not amountStr then
            showItemMatches(item)
            return
        end

        if amountStr == "all" then
            amount = storage.getTotalItemCount(storageMap, item, true)
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

        storageMap = storage.pullItems(storageMap, item, amount, outputChest, true)
        storage.saveStorageMap(storageMapPath, storageMap)
    elseif command == "help" then
        help()
    else
        help()
    end
end

main()
