-- Imports
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local enums = require("lib-turtle.enums")

---@type Direction
local Direction = enums.Direction

local logger = require("lexicon-lib.lib-logging").getLogger("Position")


---@class Position
---@overload fun(x: integer, y: integer, z: integer, facing: integer): Position
Position = class()


---Initialise the position
---@param x integer The x coordinate
---@param y integer The y coordinate
---@param z integer The z coordinate
---@param facing integer The direction the turtle is facing
function Position:init(x, y, z, facing)
    self.x = x
    self.y = y
    self.z = z
    self.facing = facing
end


---Return the origin position
---@return Position
function Position.getOrigin()
    return Position(0, 0, 0, Direction.NORTH)
end


---Return the position if we move up a number of blocks
---@param amount? integer The number of blocks to move (default 1)
---@return Position
function Position:up(amount)
    if amount == nil then
        amount = 1
    end

    return Position(self.x, self.y + amount, self.z, self.facing)
end


---Return the position if we move down one block
---@param amount? integer The number of blocks to move (default 1)
---@return Position
function Position:down(amount)
    if amount == nil then
        amount = 1
    end

    return Position(self.x, self.y - amount, self.z, self.facing)
end


---Return the position if we move forward one block
---@param amount? integer The number of blocks to move (default 1)
---@return Position
function Position:forward(amount)
    if amount == nil then
        amount = 1
    end

    if self.facing == Direction.NORTH then
        return Position(self.x, self.y, self.z - amount, self.facing)
    elseif self.facing == Direction.EAST then
        return Position(self.x + amount, self.y, self.z, self.facing)
    elseif self.facing == Direction.SOUTH then
        return Position(self.x, self.y, self.z + amount, self.facing)
    elseif self.facing == Direction.WEST then
        return Position(self.x - amount, self.y, self.z, self.facing)
    else
        logger:error("Invalid direction (%d)", self.facing)
        return self
    end
end


---Return the position if we move back one block
---@param amount? integer The number of blocks to move (default 1)
---@return Position
function Position:back(amount)
    if amount == nil then
        amount = 1
    end

    if self.facing == Direction.NORTH then
        return Position(self.x, self.y, self.z + amount, self.facing)
    elseif self.facing == Direction.EAST then
        return Position(self.x - amount, self.y, self.z, self.facing)
    elseif self.facing == Direction.SOUTH then
        return Position(self.x, self.y, self.z - amount, self.facing)
    elseif self.facing == Direction.WEST then
        return Position(self.x + amount, self.y, self.z, self.facing)
    else
        logger:error("Invalid direction (%d)", self.facing)
        return self
    end
end


---Return the position if we turn left
---@param amount? integer The number of times to turn (default 1)
---@return Position
function Position:rotateLeft(amount)
    if amount == nil then
        amount = 1
    end

    return Position(self.x, self.y, self.z, (self.facing - amount) % 4)
end


---Return the position if we turn right
---@param amount? integer The number of times to turn (default 1)
---@return Position
function Position:rotateRight(amount)
    if amount == nil then
        amount = 1
    end

    return Position(self.x, self.y, self.z, (self.facing + amount) % 4)
end


---Calculate the difference between the current position and another position (removing facing direction)
---@param position Position The position to compare to
---@return Position
function Position:diff(position)
    return Position(position.x - self.x, position.y - self.y, position.z - self.z, enums.Direction.NIL)
end


---Add a position vector to the current position (removing facing direction)
---@param position Position The position to add
---@return Position
function Position:add(position)
    return Position(self.x + position.x, self.y + position.y, self.z + position.z, enums.Direction.NIL)
end


---Multiply a position vector by another position (removing facing direction)
---@param position Position The position to multiply by
---@return Position
function Position:multiply(position)
    return Position(self.x * position.x, self.y * position.y, self.z * position.z, enums.Direction.NIL)
end


---Calculate the manhattan distance between the current position and another position
---@param position Position The position to compare to
---@return integer
function Position:manhattanDistance(position)
    return math.abs(position.x - self.x) + math.abs(position.y - self.y) + math.abs(position.z - self.z)
end


---Check if the current position is equal to another position
---@param position Position The position to compare to
---@param ignoreFacing? boolean If true, ignore the facing direction (default false)
---@return boolean
function Position:equals(position, ignoreFacing)
    if ignoreFacing == nil then
        ignoreFacing = false
    end

    if ignoreFacing then
        return self.x == position.x and self.y == position.y and self.z == position.z
    else
        return self.x == position.x and self.y == position.y and self.z == position.z and self.facing == position.facing
    end
end


---Convert the position to a string
---@param withFacing? boolean If true, include the facing direction (default false)
---@return string
function Position:asString(withFacing)
    if withFacing == nil then
        withFacing = false
    end

    if withFacing then
        return string.format("(%d, %d, %d, %d)", self.x, self.y, self.z, self.facing)
    else
        return string.format("(%d, %d, %d)", self.x, self.y, self.z)
    end
end


---Return a copy of the position
---@param nilFacing? boolean If true, set the facing direction to nil (default false)
---@return Position
function Position:copy(nilFacing)
    if nilFacing then
        return Position(self.x, self.y, self.z, enums.Direction.NIL)
    end

    return Position(self.x, self.y, self.z, self.facing)
end


---Serialise the position to a string
---@return string
function Position:serialise()
    return string.format("%d,%d,%d,%d", self.x, self.y, self.z, self.facing)
end


---Create a Position object from a string
---@param str string The string to parse
---@return Position?
function Position.unserialise(str)
    local invalidStr = "Invalid string (%s)"
    local xStr, yStr, zStr, facingStr = string.match(str, "(-?%d+),(-?%d+),(-?%d+),(%d+)")

    if xStr == nil or yStr == nil or zStr == nil or facingStr == nil then
        logger:error(invalidStr, str)
        return nil
    end

    local x, y, z = tonumber(xStr), tonumber(yStr), tonumber(zStr)

    if x == nil or y == nil or z == nil then
        logger:error(invalidStr, str)
        return nil
    end

    local facingNumber = tonumber(facingStr)

    if not facingNumber then
        facingNumber = enums.Direction[string.upper(facingStr)]
    end

    if not facingNumber then
        logger:error(invalidStr, str)
        return nil
    end

    return Position(x, y, z, facingNumber)
end


---Convert the position into global space from local space
---@param globalStartingPosition Position The global space starting position
---@return Position
function Position:toGlobal(globalStartingPosition)
    local localPosition = self:copy()

    -- rotate to face the correct direction in global space
    local rotationDiff = globalStartingPosition.facing

    localPosition = localPosition

    if rotationDiff == 1 then
        localPosition.x, localPosition.z = -localPosition.z, localPosition.x
    elseif rotationDiff == 2 then
        localPosition.x, localPosition.z = -localPosition.x, -localPosition.z
    elseif rotationDiff == 3 then
        localPosition.x, localPosition.z = localPosition.z, -localPosition.x
    end

    localPosition = localPosition:add(globalStartingPosition)

    return localPosition
end
