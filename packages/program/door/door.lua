---Control a door server!
package.path = package.path .. ";/usr/lib/?.lua"

local argparse = require("metis.argparse")
local completion = require("cc.completion")
require("lib-door.client.DoorClient")


settings.define("door.names", {
    description = "Known door names",
    type = "table",
    default = {"main"},
})

local knownDoorNames = settings.get("door.names")


---Argument completion for the script
---@param _ any
---@param index number The index of the argument
---@param argument string The current arguments
---@param previous table
---@return table? _ A table of possible completions
local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, knownDoorNames, true)
    elseif index == 2 then
        return completion.choice(argument, {"open", "close"}, false)
    end

    return {}
end


shell.setCompletionFunction(shell.getRunningProgram(), complete)

local parser = argparse.create()

parser:add({"name"}, {
    doc = "The door to control",
})

parser:add({"action"}, {
    doc = "The action to perform on the door server",
})

local args = parser:parse(table.unpack(arg))

local doorClient = DoorClient()

local success, successCount, totalCount

local group = args.name

if args.action == "open" then
    success, successCount, totalCount = doorClient:open(group)
elseif args.action == "close" then
    success, successCount, totalCount = doorClient:close(group)
end

local countString = successCount .. "/" .. totalCount
local actionSting = args.action == "open" and "Open" or "Close"

if success then
    print(actionSting .. " success (" .. countString .. ")")

    table.insert(knownDoorNames, group)
    settings.set("door.names", knownDoorNames)
    settings.save()
else
    print(actionSting .. " failed (" .. countString .. ")")
end
