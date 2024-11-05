-- Imports
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-turtle.Position")

local enums = require("lib-turtle.enums")

---@type Direction
local Direction = enums.Direction
---@type ERRORS
local ERRORS = enums.ERRORS
---@type ACTION_DIRECTION
local ACTION_DIRECTION = enums.ACTION_DIRECTION

local logging = require("lexicon-lib.lib-logging")


--- Error messages

---@class Turtle
---@field logger table The logger for the turtle
---@field position Position The current position of the turtle
---@field fuel number|string The current fuel level of the turtle
---@overload fun(): Turtle
Turtle = class()

Turtle.origin = Position(0, 0, 0, Direction.NORTH)


---Initialise the turtle
---@param startingPosition? Position The starting position of the turtle
function Turtle:init(startingPosition)
    self.logger = logging.getLogger("Turtle")
    self.logger:setLevel(logging.LEVELS.DEBUG)
    self.fuel = turtle.getFuelLevel()

    if startingPosition == nil then
        self.position = Turtle.origin
    else
        self.position = startingPosition
    end

    self.startingPosition = self.position

    self.logger:info("Initialised turtle at %s", self.position:asString())
end


---Check if the turtle has enough fuel to move a number of blocks
---@param amount number The number of blocks to move
---@return boolean
function Turtle:hasFuel(amount)
    if self.fuel == "unlimited" then
        return true
    end
    return self.fuel - amount >= 0
end


---Use up some fuel (if possible)
---@param amount? number The amount of fuel to use
---@return nil
function Turtle:useFuel(amount)
    if self.fuel == "unlimited" then
        return
    end

    if amount == nil then
        amount = 1
    end

    self.fuel = self.fuel - amount
end


---Dig a block in a given direction
---@param direction number The direction to dig
---@return boolean, string?
function Turtle:_digDirection(direction)
    local func = nil

    if direction == ACTION_DIRECTION.UP then
        self.logger:debug("Dig up")
        func = turtle.digUp
    elseif direction == ACTION_DIRECTION.DOWN then
        self.logger:debug("Dig down")
        func = turtle.digDown
    elseif direction == ACTION_DIRECTION.FORWARD then
        self.logger:debug("Dig forward")
        func = turtle.dig
    else
        return false, "Invalid direction"
    end

    local res, errorMessage = func()

    if not res then
        if errorMessage ~= ERRORS.NOTHING_TO_DIG then
            self.logger:warn("Dig failed: %s", errorMessage)
            return false, errorMessage
        end
        -- Nothing to dig, but that's fine
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


---@class MovementArgsExtra
---@field dig? boolean If true, dig out any blocks in the way (default false)
---@field safe? boolean If true, don't perform this move if we won't have enough fuel to return to the starting position (default true)
---@field autoReturn? boolean If true, return to the starting position if we wont't have enough fuel to return after the move. Only used if in safe mode (default false)


---Move the turtle in a given direction
---@param direction number The direction to move
---@param amount? number The number of blocks to move (default 1)
---@param argsExtra? MovementArgsExtra Extra arguments for the move
---@return boolean, string?
function Turtle:_moveDirection(direction, amount, argsExtra)
    if amount == nil then amount = 1 end
    if argsExtra == nil then argsExtra = {} end

    if argsExtra.dig == nil then argsExtra.dig = false end
    if argsExtra.safe == nil then argsExtra.safe = true end
    if argsExtra.autoReturn == nil then argsExtra.autoReturn = false end

    ---This will be the new position of the turtle after the move
    ---if all goes well
    local newPosition = self.position:copy()

    ---@type function[]
    local funcs = {nil, nil, nil}

    if direction == ACTION_DIRECTION.UP then
        self.logger:debug("Move up")
        funcs = {self.digUp, turtle.up, self.position.up}
        newPosition = newPosition:up(amount)
    elseif direction == ACTION_DIRECTION.DOWN then
        self.logger:debug("Move down")
        funcs = {self.digDown, turtle.down, self.position.down}
        newPosition = newPosition:down(amount)
    elseif direction == ACTION_DIRECTION.FORWARD then
        self.logger:debug("Move forward")
        funcs = {self.dig, turtle.forward, self.position.forward}
        newPosition = newPosition:forward(amount)
    elseif direction == ACTION_DIRECTION.BACK then
        self.logger:debug("Move back")
        if argsExtra.dig then
            return false, "Cannot dig backwards"
        end
        funcs = {nil, turtle.back, self.position.back}
        newPosition = self.position:back(amount)
    else
        return false, "Invalid direction"
    end

    ---Check if the turtle has enough fuel to return to the starting position
    ---if we do this move
    if argsExtra.safe and not self:willHaveFuelToEmergencyReturn(newPosition) then
        --- If we won't have enough fuel to return to the starting position
        
        if argsExtra.autoReturn then
            return self:returnToOrigin(true)
        else
            --- not in safe mode so yolo it
            return false, ERRORS.NOT_ENOUGH_FUEL_FOR_EMERGENCY
        end
    end

    for _ = 1, amount do
        if argsExtra.dig and funcs[1] ~= nil then
            local res, errorMessage = funcs[1](self)

            if not res and errorMessage ~= ERRORS.NOTHING_TO_DIG then
                return false, errorMessage
            end
        end

        local res, errorMessage = funcs[2]()

        if not res then
            self.logger:warn("Move failed: %s", errorMessage)
            return false, errorMessage
        end

        self.position = funcs[3](self.position)
        self:useFuel()

        self.logger:debug("Moved to %s", self.position:asString())
    end

    return true
end


---Move the turtle up a number of blocks
---@param amount? number The number of blocks to move (default 1)
---@param argsExtra? MovementArgsExtra Extra arguments for the move
---@return boolean, string?
function Turtle:up(amount, argsExtra)
    return self:_moveDirection(ACTION_DIRECTION.UP, amount, argsExtra)
end


---Move the turtle down a number of blocks
---@param amount? number The number of blocks to move (default 1)
---@param argsExtra? MovementArgsExtra Extra arguments for the move
---@return boolean, string?
function Turtle:down(amount, argsExtra)
    return self:_moveDirection(ACTION_DIRECTION.DOWN, amount, argsExtra)
end


---Move the turtle forward a number of blocks
---@param amount? number The number of blocks to move (default 1)
---@param argsExtra? MovementArgsExtra Extra arguments for the move
---@return boolean, string?
function Turtle:forward(amount, argsExtra)
    return self:_moveDirection(ACTION_DIRECTION.FORWARD, amount, argsExtra)
end


---Move the turtle back a number of blocks (by turning around and moving forward)
---@param amount? number The number of blocks to move (default 1)
---@param argsExtra? MovementArgsExtra Extra arguments for the move
---@return boolean, string?
function Turtle:back(amount, argsExtra)
    self:turnAround()
    return self:forward(amount, argsExtra)
end


---Move the turtle left a number of blocks (by turning left and moving forward)
---@param amount? number The number of blocks to move (default 1)
---@param argsExtra? MovementArgsExtra Extra arguments for the move
---@return boolean, string?
function Turtle:left(amount, argsExtra)
    self:turnLeft()
    return self:forward(amount, argsExtra)
end


---Move the turtle right a number of blocks (by turning right and moving forward)
---@param amount? number The number of blocks to move (default 1)
---@param argsExtra? MovementArgsExtra Extra arguments for the move
---@return boolean, string?
function Turtle:right(amount, argsExtra)
    self:turnRight()
    return self:forward(amount, argsExtra)
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
        self.logger:error("Invalid direction (%d)", direction)
    end
end


---Move the turtle to a given position
---@param position Position The position to move to
---@param argsExtra? MovementArgsExtra Extra arguments for the move
---@return boolean, string?
function Turtle:moveTo(position, argsExtra)
    local diff = self.position:diff(position)

    ---Check if the turtle has enough fuel to move to the position
    if not self:hasFuel(self.position:manhattanDistance(diff)) then
        return false, ERRORS.NOT_ENOUGH_FUEL
    end

    self.logger:info("Moving to %s", position:asString())

    ---@type boolean
    local res
    ---@type string?
    local errorMessage

    if diff.x ~= 0 then
        if diff.x > 0 then
            self:face(Direction.EAST)
        else
            self:face(Direction.WEST)
        end

        res, errorMessage = self:forward(math.abs(diff.x), argsExtra)

        if not res then
            return false, errorMessage
        end
    end

    if diff.y ~= 0 then
        if diff.y > 0 then
            res, errorMessage = self:up(math.abs(diff.y), argsExtra)
        else
            res, errorMessage = self:down(math.abs(diff.y), argsExtra)
        end

        if not res then
            return false, errorMessage
        end
    end

    if diff.z ~= 0 then
        if diff.z > 0 then
            self:face(Direction.SOUTH)
        else
            self:face(Direction.NORTH)
        end

        res, errorMessage = self:forward(math.abs(diff.z), argsExtra)

        if not res then
            return false, errorMessage
        end
    end

    self:face(position.facing)

    return true
end


---Return the turtle to the starting position, digging out any blocks in the way
---@param emergency? boolean If true, we're returning to the starting position due to fuel constraints
---@return boolean, string?
function Turtle:returnToOrigin(emergency)
    local res, err = self:moveTo(self.startingPosition, {dig = true})

    if res then
        if emergency then
            return false, ERRORS.DID_EMERGENCY_RETURN
        else
            return true
        end
    else
        return false, err
    end
end


---Check if the turtle will have enough fuel to return to the starting position from a given position
---@param position Position The position to start from
---@return boolean
function Turtle:willHaveFuelToEmergencyReturn(position)
    local manhattanDistance = position:manhattanDistance(self.startingPosition)

    return self:hasFuel(manhattanDistance)
end
