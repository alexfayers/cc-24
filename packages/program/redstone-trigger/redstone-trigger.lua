---Trigger a given command when a redstone signal is received on the specified side.
package.path = package.path .. ";/usr/lib/?.lua"
local argparse = require("metis.argparse")
local completion = require("cc.completion")


---Argument completion for the script
---@param _ any
---@param index number The index of the argument
---@param argument string The current arguments
---@param previous table
---@return table? _ A table of possible completions
local function complete(_, index, argument, previous)
    local sides = redstone.getSides()
    if index == 1 then
        return completion.choice(argument, sides, true)
    elseif index == 2 then
        return completion.choice(argument, {'""'}, false)
    end

    return {}
end

shell.setCompletionFunction(shell.getRunningProgram(), complete)

local parser = argparse.create()

parser:add({"side"}, {
    doc = "The side to listen for the redstone signal on",
})

parser:add({"command"}, {
    doc = "The command to run when the redstone signal is received",
})

local args = parser:parse(table.unpack(arg))

local targetSide = args.side
local command = args.command

local sides = redstone.getSides()

local validSide = false
for _, side in ipairs(sides) do
    if side == targetSide then
        validSide = true
        break
    end
end

if not validSide then
    error("Invalid side: " .. targetSide, 0)
end


while true do
    -- wait for a redstone signal
    print("Waiting for redstone signal on " .. targetSide)
    os.pullEvent("redstone")

    if redstone.getInput(targetSide) then
        print("Got input on " .. targetSide .. ", running command")
        shell.run(command)
    end
end
