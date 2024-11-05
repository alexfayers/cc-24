---Quarry mining system for cc:tweaked
package.path = package.path .. ";/usr/lib/?.lua"

local enums = require("lib-turtle.enums")
require("lib-turtle.Turtle")

local logger = require("lexicon-lib.lib-logging").getLogger("Quarry")


local turt = Turtle()

local LAYER_DEPTH = 3

local MOVEMENT_ARGS = {
    safe = true,
    autoReturn = true
}

---NOTE: strip and layer numbers are 1 indexed


---Mine a single strip of a layer of the quarry
---@param stripLength integer The length of the strip
---@return boolean _ Whether the strip was mined successfully
local function mineLevelStrip(stripLength)
    for i = 1, stripLength do
        local forwardRes, forwardErr = turt:forward(1, MOVEMENT_ARGS)
        if forwardRes == false then
            logger.error("Failed to move forward: " .. forwardErr)
            return false
        end

        local digDownRes, digDownErr = turt:digDown()
        if digDownRes == false then
            logger.error("Failed to dig down: " .. digDownErr)
            return false
        end

        local digUpRes, digUpErr = turt:digUp()

        if digUpRes == false then
            logger.error("Failed to dig up: " .. digUpErr)
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

    local forwardRes, forwardErr = turt:forward(1, MOVEMENT_ARGS)
    if forwardRes == false then
        logger.error("Failed to move forward: " .. forwardErr)
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
        local stripRes = mineLevelStrip(width)
        if stripRes == false then
            logger.error("Failed to mine strip")
            return false
        end

        local prepRes = prepareNextStrip(i)
        if prepRes == false then
            logger.error("Failed to prepare next strip")
            return false
        end
    end

    return true
end


---Go down a layer in the quarry
---@return boolean _ Whether the layer was changed successfully
local function goDownLayer()
    local downRes, downErr = turt:down(LAYER_DEPTH, MOVEMENT_ARGS)

    if downRes == false then
        logger.error("Failed to go down: " .. downErr)
        return false
    end

    turt:turnAround()

    return true
end


---Mine the quarry
---@param length integer The length of the quarry
---@param width integer The width of the quarry
---@param depth integer The depth of the quarry (blocks, not layers)
---@return boolean _ Whether the quarry was mined successfully
local function mineQuarry(length, width, depth)
    local layers = math.ceil(depth / LAYER_DEPTH)

    for i = 1, layers do
        local layerRes = mineLevel(length, width)
        if layerRes == false then
            logger.error("Failed to mine layer")
            return false
        end

        local downRes = goDownLayer()
        if downRes == false then
            logger.error("Failed to go down layer")
            return false
        end
    end

    -- Return to the origin
    turt:moveTo(Turtle.origin, {dig = true})

    return true
end


mineQuarry(4, 4, 6)
