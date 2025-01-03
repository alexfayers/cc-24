---@class Direction
local Direction = {
    NIL = -1,
    NORTH = 0,
    EAST = 1,
    SOUTH = 2,
    WEST = 3,
}

---@class ERRORS
local ERRORS = {
    MOVEMENT_OBSTRUCTED = "Movement obstructed",
    OUT_OF_FUEL = "Out of fuel",
    NOT_ENOUGH_FUEL = "Not enough fuel",
    NOT_ENOUGH_FUEL_FOR_EMERGENCY = "Not enough fuel to make it back to start",
    DID_EMERGENCY_RETURN = "Did emergency return",
    NOTHING_TO_DIG = "Nothing to dig here",
    CANNOT_BREAK_UNBREAKABLE = "Cannot break unbreakable block",
    TOO_MANY_BREAK_ATTEMPTS = "Broken block in same place too many times",
    NO_INVENTORY_SPACE = "No inventory space",
    NO_INVENTORY_FULL_LAST_LOCATION = "Previous location from before inventory was full is not set",
}

---@class ACTION_DIRECTION
local ACTION_DIRECTION = {
    UP = 0,
    DOWN = 1,
    FORWARD = 2,
    BACK = 3,
}


return {
    Direction = Direction,
    ERRORS = ERRORS,
    ACTION_DIRECTION = ACTION_DIRECTION
}