package.path = package.path .. ";/usr/lib/?.lua"

local crafter = require("lib-crafter.client.crafter")
local argparse = require("metis.argparse")
local completion = require("cc.completion")


---Argument completion for the script
---@param _ any
---@param index number The index of the argument
---@param argument string The current arguments
---@param previous table
---@return table? _ A table of possible completions
local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, {"diamond_pickaxe"}, true)
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

local args = parser:parse(table.unpack(arg))

local item_name = args.item_name
local countRaw = args.count

if not countRaw then
    countRaw = "1"
end

local count = tonumber(countRaw)
if not count then
    error("Invalid count: " .. countRaw, 0)
end

crafter.craft_item(item_name, count)
