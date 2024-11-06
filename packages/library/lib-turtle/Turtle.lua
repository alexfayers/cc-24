-- Imports
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-turtle.Position")
require("lib-turtle.TurtleInventory")

local helpers = require("lib-turtle.helpers")
local tableHelpers = require("lexicon-lib.lib-table")
local enums = require("lib-turtle.enums")

---@type Direction
local Direction = enums.Direction
---@type ERRORS
local ERRORS = enums.ERRORS
---@type ACTION_DIRECTION
local ACTION_DIRECTION = enums.ACTION_DIRECTION

local logging = require("lexicon-lib.lib-logging")

---Settings
settings.define("turtle.stateFile", {
    description = "The file to save the turtle state to",
    type = "string",
    default = "/.turtle/state.json"
})

--- Error messages

---@class Turtle
---@field logger table The logger for the turtle
---@field position Position The current position of the turtle
---@field fuel number|string The current fuel level of the turtle
---@overload fun(startingPosition?: Position): Turtle
Turtle = class()

Turtle.origin = Position(0, 0, 0, Direction.NORTH)
Turtle.MAX_BREAK_ATTEMPTS = 30
Turtle.trashItemTags = {}
Turtle.trashItemNames = {}
Turtle.trashMinStackSize = 8

---@alias inspectHandler fun(self: Turtle, inspectedBlockPosition: Position, inspectData: ccTweaked.turtle.inspectInfo): nil

---@type inspectHandler[] The functions to call when inspecting a block.
Turtle.inspectHandlers = {}


---Initialise the turtle
---@param startingPosition? Position The starting position of the turtle
function Turtle:init(startingPosition)
    self.logger = logging.getLogger("Turtle")
    self.logger:setLevel(logging.LEVELS.INFO)

    self:loadState()

    self.fuel = self.fuel or turtle.getFuelLevel()

    self.startingPosition = startingPosition or self.startingPosition or Turtle.origin
    self.position = self.position or self.startingPosition

    ---@type TurtleInventory
    self.inventory = TurtleInventory()
    self.inventory:refuel()

    self:saveState()
end


---@alias TurtleStateSerialised {position: string, startingPosition: string, fuel: number|string}

---Load the turtle state from the statefile
---@return nil
function Turtle:loadState()
    local stateFile = settings.get("turtle.stateFile")

    if fs.exists(stateFile) then
        ---@type TurtleStateSerialised?
        local state = tableHelpers.loadTable(stateFile)
        if state == nil then
            return nil
        end

        local position = Position.unserialise(state.position)
        if not position then
            self.logger:error("Failed to load position from state file")
            return
        end

        local startingPosition = Position.unserialise(state.startingPosition)
        if not startingPosition then
            self.logger:error("Failed to load starting position from state file")
            return
        end
        local fuel = state.fuel

        self.position = position
        self.startingPosition = startingPosition
        self.fuel = fuel
    end
end


---Save the turtle state to the statefile
---@return nil
function Turtle:saveState()
    local stateFile = settings.get("turtle.stateFile")

    local state = {
        position = self.position:serialise(),
        startingPosition = self.startingPosition:serialise(),
        fuel = self.fuel
    }

    tableHelpers.saveTable(stateFile, state)
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
    local inspectFunc = nil
    local func = nil

    local targetBlockCoords = nil

    if direction == ACTION_DIRECTION.UP then
        self.logger:debug("Dig up")
        inspectFunc = turtle.inspectUp
        func = turtle.digUp
        targetBlockCoords = self.position:up()
    elseif direction == ACTION_DIRECTION.DOWN then
        self.logger:debug("Dig down")
        inspectFunc = turtle.inspectDown
        func = turtle.digDown
        targetBlockCoords = self.position:down()
    elseif direction == ACTION_DIRECTION.FORWARD then
        self.logger:debug("Dig forward")
        inspectFunc = turtle.inspect
        func = turtle.dig
        targetBlockCoords = self.position:forward()
    else
        return false, "Invalid direction"
    end

    local isBlock, inspectData = inspectFunc()
    if not isBlock then
        return true
    end
    ---@cast inspectData ccTweaked.turtle.inspectInfo
    
    ---@type function[]
    local inspectTasks = {}
    for _, inspectHandler in pairs(self.inspectHandlers) do
        table.insert(inspectTasks, function ()
            inspectHandler(self, targetBlockCoords, inspectData)
        end)
    end

    parallel.waitForAll(table.unpack(inspectTasks))

    if helpers.isBlockReplaceable(inspectData) then
        return true
    end

    local digAttempts = 0
    ::doDig::

    local res, errorMessage = func()

    if not res then
        if errorMessage ~= ERRORS.NOTHING_TO_DIG then
            self.logger:warn("Dig failed: %s", errorMessage)
            return false, errorMessage
        end
        -- Nothing to dig, but that's fine
    end

    ---Update the inventory because we've dug something
    self.inventory:updateSlots()

    self.inventory:compress()

    self.inventory:discardItems(self.trashItemNames, self.trashItemTags, self.trashMinStackSize)

    local refuelMadeChanges = false
    refuelMadeChanges, self.fuel = self.inventory:refuel()

    if refuelMadeChanges then
        --- If we made changes to the inventory, update the slots (again)
        self.inventory:updateSlots()
    end

    isBlock, inspectData = inspectFunc()
    if isBlock then
        ---@cast inspectData ccTweaked.turtle.inspectInfo
        if helpers.isBlockReplaceable(inspectData) then
            return true
        end

        digAttempts = digAttempts + 1

        if digAttempts >= self.MAX_BREAK_ATTEMPTS then
            self.logger:warn("Broken block at %s %d times", targetBlockCoords:asString(), self.MAX_BREAK_ATTEMPTS)
            return false, ERRORS.TOO_MANY_BREAK_ATTEMPTS
        end
        goto doDig
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
    self:saveState()
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
    self:saveState()
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
        self.logger:debug("Move up %d", amount)
        funcs = {self.digUp, turtle.up, self.position.up}
        newPosition = newPosition:up(amount)
    elseif direction == ACTION_DIRECTION.DOWN then
        self.logger:debug("Move down %d", amount)
        funcs = {self.digDown, turtle.down, self.position.down}
        newPosition = newPosition:down(amount)
    elseif direction == ACTION_DIRECTION.FORWARD then
        self.logger:debug("Move forward %d", amount)
        funcs = {self.dig, turtle.forward, self.position.forward}
        newPosition = newPosition:forward(amount)
    elseif direction == ACTION_DIRECTION.BACK then
        self.logger:debug("Move back %d", amount)
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
    if argsExtra.safe and not self:canReturnToOriginIfMoveTo(newPosition) then
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

        self:saveState()

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

    self.logger:debug("Moving to %s", position:asString())

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


---Check if the turtle will have enough fuel to return to the starting position if we travel to a given position
---@param position Position The position to start from
---@return boolean
function Turtle:canReturnToOriginIfMoveTo(position)
    local distanceToPosition = self.position:manhattanDistance(position)
    local distanceToOrigin = position:manhattanDistance(self.startingPosition)

    return self:hasFuel(distanceToPosition + distanceToOrigin)
end
