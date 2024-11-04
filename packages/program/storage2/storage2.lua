-- Cli interface for the storage2 module
package.path = package.path .. ";/usr/lib/?.lua"

local chestHelpers = require("lib-storage2.chestHelpers")
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

local storageChests = chestHelpers.getStorageChests(inputChest, outputChest)
if not storageChests then
    return
end

local storageMap = Map(storageChests)
storageMap:save()


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
---@return table? _ A table of possible completions
local function complete(_, index, argument, previous)
    local previousArg = previous[#previous]

    if index == 1 then
        return completion.choice(argument, {"pull", "push", "search", "usage", "help"}, true)
    elseif index == 2 then
        if previousArg == "pull" then
            return completion.choice(argument, storageMap:getAllItemStubs(), previousArg == "pull")
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
    local matches = storageMap:searchItemNames(item)

    if #matches == 0 then
        print("No matches found for '" .. item .. "'")
        return
    end

    print("Matches for '" .. item .. "':")
    for _, match in pairs(matches) do
        local count = storageMap:getTotalItemCount(match)
        print("  " .. match .. " (" .. count .. ")")
    end
end


---Show the usage and capacity of the storage chests
---@return nil
local function showUsage()
    local allSlots = storageMap:getAllSlots()
    local fullSlotCount = #storageMap:getFullSlots()
    local allSlotsCount = #allSlots

    print("Usage:")

    print(
        "  Slots: " .. fullSlotCount .. "/" .. allSlotsCount ..
        " (" .. math.floor(fullSlotCount / allSlotsCount * 100) .. "%)"
    )

    local itemCount = storageMap.getTotalCount(allSlots)
    local maxItemCount = storageMap.getTotalMaxCount(allSlots)
    print(
        "  Items:  " .. itemCount .. "/" .. maxItemCount ..
        " (" .. math.floor(itemCount / maxItemCount * 100) .. "%)"
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
        storageMap:push(inputChest)
        storageMap:save()
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
        local amountStr = arg[3]
        local amount = 0

        if not amountStr then
            showItemMatches(item)
            return
        end

        if amountStr == "all" then
            amount = storageMap:getTotalItemCount(item, true)
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

        storageMap:pull(outputChest, item, amount, true)
        storageMap:save()
    elseif command == "help" then
        help()
    else
        help()
    end
end

main()
