---Quarry mining system for cc:tweaked
package.path = package.path .. ";/usr/lib/?.lua"

local completion = require("cc.completion")

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

local turt = Turtle()

table.insert(turt.trashItemTags, "c:stones")
table.insert(turt.trashItemTags, "minecraft:sand")
table.insert(turt.trashItemNames, "minecraft:gravel")

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


local function help()
    print("Usage: quarry <starting x> <starting y> <starting z> <starting bearing> <length> <width> <layers>")
end


---Argument completion for the script
---@param _ any
---@param index number The index of the argument
---@param argument string The current arguments
---@param previous table
---@return table? _ A table of possible completions
local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, {"0"}, true)
    elseif index == 2 then
        return completion.choice(argument, {"0"}, true)
    elseif index == 3 then
        return completion.choice(argument, {"0"}, true)
    elseif index == 4 then
        return completion.choice(argument, {"north", "east", "south", "west"}, true)
    elseif index == 5 then
        return completion.choice(argument, {"16"}, true)
    elseif index == 6 then
        return completion.choice(argument, {"16"}, true)
    elseif index == 7 then
        return completion.choice(argument, {"20"}, true)
    end

    return {}
end

shell.setCompletionFunction(shell.getRunningProgram(), complete)


if #arg < 7 then
    help()
    return
end

local startX = tonumber(arg[1])
local startY = tonumber(arg[2])
local startZ = tonumber(arg[3])
local startBearing = enums.Direction[string.upper(arg[4])]
local length = tonumber(arg[5])
local width = tonumber(arg[6])
local layers = tonumber(arg[7])

if not startX then
    logger:error("Invalid starting x")
    return
end

if not startY then
    logger:error("Invalid starting y")
    return
end

if not startZ then
    logger:error("Invalid starting z")
    return
end

if not startBearing then
    logger:error("Invalid starting bearing")
    return
end

if not length then
    logger:error("Invalid length")
    return
end

if not width then
    logger:error("Invalid width")
    return
end

if not layers then
    logger:error("Invalid layers")
    return
end

turt:initPosition(Position(startX, startY, startZ, startBearing))

if not mineQuarry(length, width, layers) then
    logger:error("Failed to mine quarry")
end
