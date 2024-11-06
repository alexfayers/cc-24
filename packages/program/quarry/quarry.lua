---Quarry mining system for cc:tweaked
package.path = package.path .. ";/usr/lib/?.lua"

local completion = require("cc.completion")
local pretty = require("cc.pretty")
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
local xSizeStr, zSizeStr, layersStr = string.match(args.size, "(-?%d+),(-?%d+),(%d+)")

if not xSizeStr then
    error("Invalid size argument (should be '[-]xSize,[-]zSize,layers')", 0)
    return
end

local xSizeArg, zSizeArg, layersArg = tonumber(xSizeStr), tonumber(zSizeStr), tonumber(layersStr)

if not xSizeArg or not zSizeArg or not layersArg then
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


---Calculate the fuel needed to mine the quarry and return to the origin
---@param xSize integer The length of the quarry
---@param zSize integer The width of the quarry
---@param layers integer The depth of the quarry
---@return number _ The fuel needed to mine the quarry
local function calculateFuelNeeded(xSize, zSize, layers)
    local fuelNeeded = 0

    -- fuel needed to mine the quarry
    fuelNeeded = fuelNeeded + math.abs(xSize * zSize * (layers * LAYER_DEPTH))

    -- fuel needed to return to the origin, assuming we end in the far bottom corner
    fuelNeeded = fuelNeeded + math.abs(xSize + zSize + (layers * LAYER_DEPTH))

    return fuelNeeded
end


---Do things before starting the quarry
---@param xSize integer The size of the quarry in the x direction
---@param zSize integer The size of the quarry in the z direction
---@param layers integer The depth of the quarry
---@return boolean _ Whether the pre-start was successful
local function preStartQuarry(xSize, zSize, layers)
    -- make sure we're at the origin
    local originRes, originErr = turt:returnToOrigin()

    if not originRes then
        logger:error("Failed to return to origin! " .. originErr)
        return false
    end

    turt.inventory:pushItems()

    local requiredFuel = calculateFuelNeeded(xSize, zSize, layers)

    turt.inventory:pullFuel(requiredFuel)

    if requiredFuel > turt.fuel then
        logger:error("Not enough fuel to mine the quarry and return (need %d)", requiredFuel)
        return false
    else
        logger:info("Starting quarry! (Predicted fuel use: %d/%d)", requiredFuel, turt.fuel)
        return true
    end
end


---Do things after finishing the quarry
---@param success boolean Whether the quarry was mined successfully
---@return nil
local function postFinishQuarry(success)
    -- make sure we're at the origin
    logger:info("Quarrying finished, going home")
    local originRes, originErr = turt:returnToOrigin()

    if not originRes then
        logger:error("Failed to return to origin! " .. originErr)
        return
    end

    turt.inventory:discardItems(turt.trashItemNames, turt.trashItemTags)

    turt.inventory:pushItems()
    
    if success then
        -- celebratory spin
        turt:turnRight(4)
    end

end


---Calculate the path of the turtle through the quarry (as a list of Position objects)
---@param xSize integer The size of the quarry in the x direction
---@param zSize integer The size of the quarry in the z direction
---@param layers integer The depth of the quarry
---@return Position[]? _ The path of the turtle through the quarry
local function calculateQuarryPath(xSize, zSize, layers)
    if layers < 1 then
        logger:error("Quarry depth must be at least 1")
        return
    end

    local xSizeAbs, zSizeAbs = math.abs(xSize), math.abs(zSize)
    if xSizeAbs < 1 then
        logger:error("Quarry xSize abs must be at least 1")
        return
    end

    if zSizeAbs < 1 then
        logger:error("Quarry zSize abs must be at least 1")
        return
    end

    local xDir, zDir = 1, 1

    if xSize < 0 then
        xDir = -1
    end

    if zSize < 0 then
        zDir = -1
    end

    ---@type Position[]
    local path = {}

    local currentPos = turt.startingPosition:copy(true)

    -- movement goes like this:
    -- dig forward (xSizeAbs) blocks
    -- move to the next strip
    -- dig backwards (xSizeAbs) blocks
    -- move to the next strip
    -- repeat until we've done all the strips
    -- move down a layer
    -- repeat until we've done all the layers

    for layerNumber = 0, layers - 1 do
        for stripNumber = 0, xSizeAbs - 1 do
            if stripNumber % 2 == 0 then
                for blockNumber = 0, zSizeAbs - 1 do
                    table.insert(path, currentPos:add(Position(
                        stripNumber * xDir,
                        - layerNumber * LAYER_DEPTH,
                        blockNumber * zDir,
                        enums.Direction.NIL
                    )))
                end
            else
                for blockNumber = zSizeAbs - 1, 0, -1 do
                    table.insert(path, currentPos:add(Position(
                        stripNumber * xDir,
                        - layerNumber * LAYER_DEPTH,
                        blockNumber * zDir,
                        enums.Direction.NIL
                    )))
                end
            end
        end
    end

    return path
end


---Follow a path of Positions through the quarry, digging as we go
---@param path Position[] The path to follow
---@return boolean _ Whether the path was followed successfully
local function followQuarryPath(path)
    for _, pos in ipairs(path) do
        local moveRes, moveErr = turt:moveTo(pos, MOVEMENT_ARGS)
        if not moveRes then
            logger:error("Failed to move to %s: %s", pos:asString(), moveErr)
            return false
        end

        local digDownRes, digDownErr = turt:digDown()
        if not digDownRes then
            logger:error("Failed to dig down at %s: %s", pos:asString(), digDownErr)
            return false
        end

        local digUpRes, digUpErr = turt:digUp()
        if not digUpRes then
            logger:error("Failed to dig up at %s: %s", pos:asString(), digUpErr)
            return false
        end
    end

    return true
end


local quarryPath = calculateQuarryPath(xSizeArg, zSizeArg, layersArg)

if not quarryPath then
    logger:error("Failed to calculate quarry path")
    return
end

for _, pos in ipairs(quarryPath) do
    print(pos:asString())
end


if not preStartQuarry(xSizeArg, zSizeArg, layersArg) then
    return false
end

local quarryRes = followQuarryPath(quarryPath)

postFinishQuarry(quarryRes)
