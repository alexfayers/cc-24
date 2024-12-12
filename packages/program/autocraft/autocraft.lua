package.path = package.path .. ";/usr/lib/?.lua"

local crafter = require("lib-crafter.client.crafter")
local argparse = require("metis.argparse")
local completion = require("cc.completion")


---Get possible completions for the script
---@return string[]
local function complete_item_names()
    local res = crafter.getRemoteItem("recipes", "_complete")

    if not res then
        return {}
    end

    return res
end


---Argument completion for the script
---@param _ any
---@param index number The index of the argument
---@param argument string The current arguments
---@param previous table
---@return table? _ A table of possible completions
local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, complete_item_names(), true)
    elseif index == 2 then
        if previous[2] == "-c" or previous[2] == "--check" then
            return completion.choice(argument, complete_item_names(), true)
        else
            return completion.choice(argument, {"1"}, false)
        end
    elseif index == 3 then
        if previous[2] == "-c" or previous[2] == "--check" then
            return completion.choice(argument, {"1"}, false)
        end
    end

    return {}
end

shell.setCompletionFunction(shell.getRunningProgram(), complete)

local parser = argparse.create()

parser:add({"item_name"}, {
    doc = "The name of the item to craft",
})

parser:add({"count"}, {
    doc = "The number of items to craft (default 1)",
    required = false,
})

parser:add({"-c", "--check"}, {
    doc = "Only check if the item can be crafted",
    required = false,
})

parser:add({"-p", "--pull"}, {
    doc = "Pull the crafted item into the output chest after crafting",
    required = false,
})

local args = parser:parse(table.unpack(arg))

local item_name = args.item_name
local countRaw = args.count
local doCheck = args.c
local doPull = args.p

if not countRaw then
    countRaw = "1"
end

local count = tonumber(countRaw)
if not count then
    error("Invalid count: " .. countRaw, 0)
end

local remainingCount = count
while remainingCount > 0 do
    local thisCount = math.min(remainingCount, 64)

    if not crafter.craft_item(item_name, thisCount, doCheck, doPull) then
        error("Crafting failed", 0)
    end

    remainingCount = remainingCount - thisCount
end
