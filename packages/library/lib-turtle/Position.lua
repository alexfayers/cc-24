-- Imports
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-turtle.enums.Direction")

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