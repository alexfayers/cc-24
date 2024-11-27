---Control a door server!
package.path = package.path .. ";/usr/lib/?.lua"

local argparse = require("metis.argparse")
local completion = require("cc.completion")
require("lib-door.client.DoorClient")


---Argument completion for the script
---@param _ any
---@param index number The index of the argument
---@param argument string The current arguments
---@param previous table
---@return table? _ A table of possible completions
local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, {"open", "close"}, false)
    end

    return {}
end


shell.setCompletionFunction(shell.getRunningProgram(), complete)

local parser = argparse.create()

parser:add({"action"}, {
    doc = "The action to perform on the door server",
})

local args = parser:parse({...})

local doorClient = DoorClient()

if args.action == "open" then
    if doorClient:open() then
        print("Door opened")
    else
        print("Failed to open door")
    end
elseif args.action == "close" then
    if doorClient:close() then
        print("Door closed")
    else
        print("Failed to close door")
    end
end
