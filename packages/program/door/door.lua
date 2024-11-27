---Control a door server!
package.path = package.path .. ";/usr/lib/?.lua"

local argparse = require("metis.argparse")
local completion = require("cc.completion")
require("lib-door.client.DoorClient")


settings.define("door.names", {
    description = "Known door names",
    type = "table",
    default = {"all"},
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

local name = args.name

if args.action == "open" then
    success, successCount, totalCount = doorClient:open(name)
elseif args.action == "close" then
    success, successCount, totalCount = doorClient:close(name)
end

if success then
    print(string.format("%s %s (%d)",
        args.action == "open" and "Opened" or "Closed",
        name,
        totalCount
    ))

    for _, doorName in ipairs(knownDoorNames) do
        if doorName == name then
            return
        end
    end
    table.insert(knownDoorNames, name)
    settings.set("door.names", knownDoorNames)
    settings.save()
else
    if totalCount == 0 then
        printError(string.format(
            "No door called %s",
            name
        ))
        return
    end

    if successCount == 0 then
        printError(string.format(
            "%s already %s (%d)",
            name,
            args.action == "open" and "open" or "closed",
            totalCount
        ))
        return
    else
        printError(string.format(
            "Only %s %d/%d for %s",
            args.action == "open" and "opened" or "closed",
            successCount,
            totalCount,
            name
        ))
    end
end
