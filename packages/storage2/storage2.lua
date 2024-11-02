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
    print("  push")
    print("    Push items from the input chest to the storage chests")
    print("  check <item>")
    print("    Check the contents of the storage chests")
    print("  pull <item> [amount]")
    print("    Pull items from the storage chests to the output chest")
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
        return completion.choice(argument, {"pull", "push", "check", "help"}, true)
    elseif index == 2 then
        if previousArg == "check" or previousArg == "pull" then
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
    local itemCount = storage.getTotalItemCount(storageMap, item)

    if itemCount > 0 then
        print("Item: " .. item)
        print("Amount: " .. itemCount)
    else
        print("'" .. item .. "' is not available")
    end
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
    elseif command == "check" then
        if #arg < 2 then
            help()
            return
        end

        local item = storage.convertItemNameStub(arg[2])
        item = storage.getFirstMatch(storageMap, item)
        checkItem(item)
    elseif command == "pull" then
        if #arg < 2 then
            help()
            return
        end

        local item = storage.convertItemNameStub(arg[2])
        item = storage.getFirstMatch(storageMap, item)
        local amountStr = arg[3]
        local amount = 0

        if not amountStr then
            checkItem(item)
            return
        end

        if amountStr == "all" then
            amount = storage.getTotalItemCount(storageMap, item)
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

        storageMap = storage.pullItems(storageMap, item, amount, outputChest)
        storage.saveStorageMap(storageMapPath, storageMap)
    elseif command == "help" then
        help()
    else
        help()
    end
end

main()
