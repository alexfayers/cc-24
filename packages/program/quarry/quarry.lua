---Quarry mining system for cc:tweaked
package.path = package.path .. ";/usr/lib/?.lua"

local enums = require("lib-turtle.enums")
require("lib-turtle.Turtle")

local logger = require("lexicon-lib.lib-logging").getLogger("Quarry")


local turt = Turtle()

local LAYER_DEPTH = 3

local MOVEMENT_ARGS = {
    dig = true,
    safe = true,
    autoReturn = true
}

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

    -- turn left or right depending on the length of the quarry
    if length % 2 == 0 then
        turt:turnRight()
    else
        turt:turnLeft()
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

    -- dig down an extra block, otherwise it gets missed
    local digDownRes, digDownErr = turt:digDown()
    if not digDownRes then
        logger:error("Failed to dig down: " .. digDownErr)
        return false
    end

    return true
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

    local retVal = true

    for i = 1, layers do
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

        -- swap the values of length and width for the next layer
        length, width = width, length
    end

    ::returnToOrigin::

    -- Return to the origin
    turt:returnToOrigin()

    if retVal then
        -- celebratory spin
        turt:turnRight(4)
    end

    return retVal
end


mineQuarry(5, 4, 2)
