-- Imports
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local enums = require("lib-turtle.enums")

---@type Direction
local Direction = enums.Direction
---@type ERRORS
local ERRORS = enums.ERRORS
---@type ACTION_DIRECTION
local ACTION_DIRECTION = enums.ACTION_DIRECTION

local logger = require("lexicon-lib.lib-logging").getLogger("Turtle")


--- Error messages


---@class Turtle
---@overload fun(): Turtle
Turtle = class()

function Turtle:init()
    self.position = Position(0, 0, 0, Direction.NORTH)
    self.fuel = turtle.getFuelLevel()
end


---Check if the turtle has enough fuel to move a number of blocks
---@param amount number The number of blocks to move
---@return boolean
function Turtle:hasFuel(amount)
    return self.fuel - amount >= 0
end


---Use up some fuel (if possible)
---@param amount? number The amount of fuel to use
---@return boolean
function Turtle:useFuel(amount)
    if amount == nil then
        amount = 1
    end

    self.fuel = self.fuel - amount

    return true
end


---Dig a block in a given direction
---@param direction number The direction to dig
---@return boolean, string?
function Turtle:_digDirection(direction)
    local func = nil

    if direction == ACTION_DIRECTION.UP then
        logger:debug("Dig up")
        func = turtle.digUp
    elseif direction == ACTION_DIRECTION.DOWN then
        logger:debug("Dig down")
        func = turtle.digDown
    elseif direction == ACTION_DIRECTION.FORWARD then
        logger:debug("Dig forward")
        func = turtle.dig
    else
        return false, "Invalid direction"
    end

    local res, errorMessage = func()

    if not res then
        if errorMessage ~= ERRORS.NOTHING_TO_DIG then
            logger:warn("Dig failed: %s", errorMessage)
        end
        return false, errorMessage
    end

    return true
end


---Dig out a block in front of the turtle
---@return boolean, string?
function Turtle:dig()
    return self:_digDirection(ACTION_DIRECTION.FORWARD)
end


---Dig out a block above the turtle
---@return boolean, string?
function Turtle:digUp()
    return self:_digDirection(ACTION_DIRECTION.UP)
end


---Dig out a block below the turtle
---@return boolean, string?
function Turtle:digDown()
    return self:_digDirection(ACTION_DIRECTION.DOWN)
end


---Turn the turtle to the left
---@param amount? number The number of times to turn (default 1)
---@return nil
function Turtle:turnLeft(amount)
    if amount == nil then
        amount = 1
    end

    for _ = 1, amount do
        turtle.turnLeft()
    end

    self.position = self.position:rotateLeft(amount)
end


---Turn the turtle to the right
---@param amount? number The number of times to turn (default 1)
---@return nil
function Turtle:turnRight(amount)
    if amount == nil then
        amount = 1
    end

    for _ = 1, amount do
        turtle.turnRight()
    end

    self.position = self.position:rotateRight(amount)
end


---Turn the turtle around
---@return nil
function Turtle:turnAround()
    if math.random() then
        self:turnLeft(2)
    else
        self:turnRight(2)
    end
end


---Move the turtle in a given direction
---@param direction number The direction to move
---@param amount? number The number of blocks to move (default 1)
---@param dig? boolean If true, dig out any blocks in the way
---@return boolean, string?
function Turtle:_moveDirection(direction, amount, dig)
    if amount == nil then
        amount = 1
    end

    ---@type function[]
    local funcs = {nil, nil, nil}

    if direction == ACTION_DIRECTION.UP then
        logger:debug("Move up")
        funcs = {self.digUp, turtle.up, self.position.up}
    elseif direction == ACTION_DIRECTION.DOWN then
        logger:debug("Move down")
        funcs = {self.digDown, turtle.down, self.position.down}
    elseif direction == ACTION_DIRECTION.FORWARD then
        logger:debug("Move forward")
        funcs = {self.dig, turtle.forward, self.position.forward}
    elseif direction == ACTION_DIRECTION.BACK then
        logger:debug("Move back")
        if dig then
            return false, "Cannot dig backwards"
        end
        funcs = {nil, turtle.back, self.position.back}
    else
        return false, "Invalid direction"
    end

    for _ = 1, amount do
        if funcs[0] ~= nil then
            local res, errorMessage = funcs[0](self)

            if not res and errorMessage ~= ERRORS.NOTHING_TO_DIG then
                return false, errorMessage
            end
        end

        local res, errorMessage = funcs[1]()

        if not res then
            logger:warn("Move failed: %s", errorMessage)
            return false, errorMessage
        end

        self.position = funcs[2](self)
        self:useFuel()
    end

    return true
end


---Move the turtle up a number of blocks
---@param amount? number The number of blocks to move (default 1)
---@param dig? boolean If true, dig out any blocks in the way
---@return boolean, string?
function Turtle:up(amount, dig)
    return self:_moveDirection(ACTION_DIRECTION.UP, amount, dig)
end


---Move the turtle down a number of blocks
---@param amount? number The number of blocks to move (default 1)
---@param dig? boolean If true, dig out any blocks in the way
---@return boolean, string?
function Turtle:down(amount, dig)
    return self:_moveDirection(ACTION_DIRECTION.DOWN, amount, dig)
end


---Move the turtle forward a number of blocks
---@param amount? number The number of blocks to move (default 1)
---@param dig? boolean If true, dig out any blocks in the way
---@return boolean, string?
function Turtle:forward(amount, dig)
    return self:_moveDirection(ACTION_DIRECTION.FORWARD, amount, dig)
end


---Move the turtle back a number of blocks (by turning around and moving forward)
---@param amount? number The number of blocks to move (default 1)
---@param dig? boolean If true, dig out any blocks in the way
---@return boolean, string?
function Turtle:back(amount, dig)
    self:turnAround()
    return self:forward(amount, dig)
end


---Move the turtle left a number of blocks (by turning left and moving forward)
---@param amount? number The number of blocks to move (default 1)
---@param dig? boolean If true, dig out any blocks in the way
---@return boolean, string?
function Turtle:left(amount, dig)
    self:turnLeft()
    return self:forward(amount, dig)
end


---Move the turtle right a number of blocks (by turning right and moving forward)
---@param amount? number The number of blocks to move (default 1)
---@param dig? boolean If true, dig out any blocks in the way
---@return boolean, string?
function Turtle:right(amount, dig)
    self:turnRight()
    return self:forward(amount, dig)
end


---Rotate the turtle to face a given direction
---@param direction number The direction to face
---@return nil
function Turtle:face(direction)
    local diff = direction - self.position.facing

    if diff == 0 then
        return
    elseif diff == 1 or diff == -3 then
        self:turnRight()
    elseif diff == 2 or diff == -2 then
        self:turnAround()
    elseif diff == 3 or diff == -1 then
        self:turnLeft()
    else
        logger:error("Invalid direction (%d)", direction)
    end
end
