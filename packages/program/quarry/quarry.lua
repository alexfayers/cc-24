---Quarry mining system for cc:tweaked
package.path = package.path .. ";/usr/lib/?.lua"

local completion = require("cc.completion")
local argparse = require("metis.argparse")

local enums = require("lib-turtle.enums")
require("lib-turtle.Turtle")
require("lib-turtle.Position")

local logger = require("lexicon-lib.lib-logging").getLogger("Quarry")

local LAYER_DEPTH = 3

local MOVEMENT_ARGS = {
    dig = true,
    safe = true,
    autoReturn = true
}

---Argument completion for the script
---@param _ any
---@param index number The index of the argument
---@param argument string The current arguments
---@param previous table
---@return table? _ A table of possible completions
local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, {"8,8,20"}, true)
    elseif index == 2 then
        return completion.choice(argument, {"0,0,0,north"}, true)
    end

    return {}
end

shell.setCompletionFunction(shell.getRunningProgram(), complete)

---Parse args

local parser = argparse.create()

parser:add({"size"}, {
    doc = "Size of the quarry",
})

parser:add({"start"}, {
    doc = "Turtle starting coords",
    required = false,
    mvar = "[START]"
})

local args = parser:parse(table.unpack(arg))

--- split the sizeArgs into length, width and layers (e.g. "16,16,20")
local lengthStr, widthStr, layersStr = string.match(args.size, "(%d+),(%d+),(%d+)")

if not lengthStr then
    error("Invalid size argument (should be 'length,width,layers')", 0)
    return
end

local lengthArg, widthArg, layersArg = tonumber(lengthStr), tonumber(widthStr), tonumber(layersStr)

if not lengthArg or not widthArg or not layersArg then
    error("Invalid size argument (should be 'length,width,layers')", 0)
    return
end

---@type Position?
local startingPosition = nil

---split the startArgs into x, y, z and bearing (e.g. "0,0,0,north") if it exists
local startX, startY, startZ, startBearingStr = string.match(args.start or "", "(-?%d+),(-?%d+),(-?%d+),(%w+)")
local startBearing = 0

if args.start then
    if not startX then
        error("Invalid starting argument (should be 'x,y,z,[north,east,south,west]')", 0)
        return
    else
        startBearing = enums.Direction[string.upper(startBearingStr)]

        if not startBearing then
            error("Invalid starting bearing (should be 'north', 'east', 'south' or 'west')", 0)
            return
        end

    end
end

if startX then
    startingPosition = Position(startX, startY, startZ, startBearing)
end

---Initialise the turt

local turt = Turtle(startingPosition)

table.insert(turt.trashItemTags, "c:stones")
table.insert(turt.trashItemTags, "minecraft:sand")
table.insert(turt.trashItemNames, "minecraft:gravel")

---Functions

---@overload fun(self: Turtle, inspectedBlockPosition: Position, inspectedBlockData: ccTweaked.turtle.inspectInfo): nil
local function oreInspectHandler(self, inspectedBlockPosition, inspectedBlockData)
    for tag in pairs(inspectedBlockData.tags) do
        if tag == "c:ores" then
            self.logger:info("Found %s at %s", string.match(inspectedBlockData.name, ".+:(.+)"), inspectedBlockPosition:asString())
            return
        end
    end
end

---@overload fun(self: Turtle, inspectedBlockPosition: Position, inspectedBlockData: ccTweaked.turtle.inspectInfo): nil
local function bedrockInspectHandler(self, inspectedBlockPosition, inspectedBlockData)
    if inspectedBlockData.name == "minecraft:bedrock" then
        self.logger:info("Found bedrock at %s", inspectedBlockPosition:asString())
        return
    end
end

table.insert(turt.inspectHandlers, oreInspectHandler)
table.insert(turt.inspectHandlers, bedrockInspectHandler)


---Mine a single strip of a layer of the quarry
---@param stripLength integer The length of the strip
---@return boolean _ Whether the strip was mined successfully
local function mineLevelStrip(stripLength)
    for _ = 1, stripLength do
        local forwardRes, forwardErr = turt:forward(1, MOVEMENT_ARGS)
        if forwardRes == false then
            logger:error("Failed to move forward: " .. forwardErr)
            return false
        end

        local digDownRes, digDownErr = turt:digDown()
        if digDownRes == false then
            logger:error("Failed to dig down: " .. digDownErr)
            return false
        end

        local digUpRes, digUpErr = turt:digUp()

        if digUpRes == false then
            logger:error("Failed to dig up: " .. digUpErr)
            return false
        end
    end

    return true
end


---Prepare to mine the next strip of a layer of the quarry
---@param stripNumber integer The number of the strip (used to determine if we should turn left or right)
---@return boolean _ Whether the preparation was successful
local function prepareNextStrip(stripNumber)
    local turnFunc = turt.turnRight

    if stripNumber % 2 == 0 then
        turnFunc = turt.turnLeft
    end

    turnFunc(turt)

    if not mineLevelStrip(1) then
        return false
    end

    turnFunc(turt)

    return true
end


---Mine a layer of the quarry
---@param length integer The length of the quarry
---@param width integer The width of the quarry
---@return boolean _ Whether the layer was mined successfully
local function mineLevel(length, width)
    for i = 1, length do
        local stripRes = mineLevelStrip(width - 1)
        if stripRes == false then
            logger:error("Failed to mine strip")
            return false
        end

        if i == length then
            break
        end

        local prepRes = prepareNextStrip(i)
        if prepRes == false then
            logger:error("Failed to prepare next strip")
            return false
        end
    end

    -- turn around or right depending on the length of the quarry
    if length % 2 == 0 then
        turt:turnRight()
    else
        turt:turnAround()
    end

    return true
end


---Go down a layer in the quarry
---@return boolean _ Whether the layer was changed successfully
local function goDownLayer()
    local downRes, downErr = turt:down(LAYER_DEPTH, MOVEMENT_ARGS)

    if downRes == false then
        logger:error("Failed to go down: " .. downErr)
        return false
    end

    return true
end


---Calculate the fuel needed to mine the quarry and return to the origin
---@param length integer The length of the quarry
---@param width integer The width of the quarry
---@param layers integer The depth of the quarry
---@return number _ The fuel needed to mine the quarry
local function calculateFuelNeeded(length, width, layers)
    local fuelNeeded = 0

    -- fuel needed to mine the quarry
    fuelNeeded = fuelNeeded + (length * width * (layers * LAYER_DEPTH))

    -- fuel needed to return to the origin, assuming we end in the far bottom corner
    fuelNeeded = fuelNeeded + (length + width + (layers * LAYER_DEPTH))

    return fuelNeeded
end


---Mine the quarry
---@param length integer The length of the quarry
---@param width integer The width of the quarry
---@param layers integer The depth of the quarry (layers, so blocks will be {LAYER_DEPTH}x this)
---@return boolean _ Whether the quarry was mined successfully
local function mineQuarry(length, width, layers)
    if length < 2 then
        logger:error("Quarry length must be at least 2")
        return false
    end

    if width < 2 then
        logger:error("Quarry width must be at least 2")
        return false
    end

    if layers < 1 then
        logger:error("Quarry depth must be at least 1")
        return false
    end

    turt.inventory:pushItems()

    local requiredFuel = calculateFuelNeeded(length, width, layers)

    turt.inventory:pullFuel(requiredFuel)

    if requiredFuel > turt.fuel then
        logger:error("Not enough fuel to mine the quarry and return (need %d)", requiredFuel)
        return false
    else
        logger:info("Starting quarry! (Predicted fuel use: %d/%d)", requiredFuel, turt.fuel)
    end

    local retVal = true

    for i = 1, layers do
        -- dig down a block before starting, otherwise it gets missed
        local digDownRes, digDownErr = turt:digDown()
        if not digDownRes then
            logger:error("Failed to dig down: " .. digDownErr)
            return false
        end

        local layerRes = mineLevel(length, width)
        if layerRes == false then
            logger:error("Failed to mine layer")
            retVal = false
            goto returnToOrigin
        end

        if i == layers then
            break
        end

        local downRes = goDownLayer()
        if downRes == false then
            logger:error("Failed to go down layer")
            retVal = false
            goto returnToOrigin
        end

        if length % 2 == 0 then
            -- swap the values of length and width for the next layer
            -- if we just turned right instead of turning around
            length, width = width, length
        end
    end

    ::returnToOrigin::

    -- Return to the origin
    turt:returnToOrigin()

    if retVal then
        -- celebratory spin
        turt:turnRight(4)
    end

    turt.inventory:discardItems(turt.trashItemNames, turt.trashItemTags)

    turt.inventory:pushItems()

    return retVal
end


-- Start quarrying!
if not mineQuarry(lengthArg, widthArg, layersArg) then
    logger:error("Failed to mine quarry")
end
