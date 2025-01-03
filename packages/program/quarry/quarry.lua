---Quarry mining system for cc:tweaked
package.path = package.path .. ";/usr/lib/?.lua"

local completion = require("cc.completion")
local pretty = require("cc.pretty")
local argparse = require("metis.argparse")
local tableHelpers = require("lexicon-lib.lib-table")

local enums = require("lib-turtle.enums")
require("lib-turtle.Turtle")
require("lib-turtle.Position")
local discord = require("lib-discord.discord")

local logger = require("lexicon-lib.lib-logging").getLogger("Quarry")

local LAYER_DEPTH = 3

local MOVEMENT_ARGS = {
    dig = true,
    safe = true,
    autoReturn = true,
    autoReturnIfFull = true,
    refuelOnDig = false,
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
local xSizeStr, zSizeStr, layersStr, layersToSkipStr = string.match(args.size, "'?(-?%d+),(-?%d+),(%d+),(%d+)'?")

if not xSizeStr then
    error("Invalid size argument (should be '[-]xSize,[-]zSize,layers,layersToSkip')", 0)
    return
end

local xSizeArg, zSizeArg, layersArg = tonumber(xSizeStr), tonumber(zSizeStr), tonumber(layersStr)

local layersToSkipArg = 0
if layersToSkipStr then
    local layersToSkipArgMaybe = tonumber(layersToSkipStr)
    if not layersToSkipArgMaybe then
        error("Invalid layersToSkip argument (should be a number)", 0)
        return
    end
    layersToSkipArg = layersToSkipArgMaybe
end

if not xSizeArg or not zSizeArg or not layersArg then
    error("Invalid size argument (should be '[-]xSize,[-]zSize,layers[,layersToSkip]')", 0)
    return
end

---@type Position?
local startingPosition = nil

---split the startArgs into x, y, z and bearing (e.g. "0,0,0,north") if it exists
local startX, startY, startZ, startBearingStr = string.match(args.start or "", "'?(-?%d+),(-?%d+),(-?%d+),(%w+)'?")
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

startingPosition = turt.startingPosition

-- table.insert(turt.trashItemTags, "c:stones")
-- table.insert(turt.trashItemTags, "minecraft:sand")
-- table.insert(turt.trashItemNames, "minecraft:gravel")
-- table.insert(turt.trashItemNames, "minecraft:dirt")

---Functions

---@overload fun(self: Turtle, inspectedBlockPosition: Position, inspectedBlockData: ccTweaked.turtle.inspectInfo): nil
local function oreInspectHandler(self, inspectedBlockPosition, inspectedBlockData)
    for tag in pairs(inspectedBlockData.tags) do
        if tag == "c:ores" then
            local notification = "Found " .. string.match(inspectedBlockData.name, ".+:(.+)") .. " at " .. inspectedBlockPosition:asString()
            self.logger:info(notification)
            discord.send("Quarry", notification)
            return
        end
    end
end

---@overload fun(self: Turtle, inspectedBlockPosition: Position, inspectedBlockData: ccTweaked.turtle.inspectInfo): nil
local function bedrockInspectHandler(self, inspectedBlockPosition, inspectedBlockData)
    if inspectedBlockData.name == "minecraft:bedrock" then
        local notification = "Found bedrock at " .. inspectedBlockPosition:asString()
        self.logger:info(notification)
        discord.send("Quarry", notification)
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


---Calculate the fuel needed to mine the quarry and return to the origin
---@param path Position[] The path of the turtle through the quarry
---@param skipTo number? The index of the path to skip to (default 1)
---@return number _ The fuel needed to mine the quarry
local function calculateFuelNeededFromPath(path, skipTo)
    if not skipTo then
        skipTo = 1
    end

    local fuelNeeded = turt.position:manhattanDistance(path[skipTo])

    for i = skipTo, #path - 1 do
        local currentPos = path[i]
        local nextPos = path[i + 1]

        local distance = currentPos:manhattanDistance(nextPos)

        fuelNeeded = fuelNeeded + distance
    end

    return fuelNeeded
end


settings.define("quarry.highestIndex", {
    description = "The highest index of the quarry path that has been mined",
    type = "number",
    default = 0,
})


---Load the highest index of the quarry path that has been mined
---@return integer
local function loadHighestIndex()
    return settings.get("quarry.highestIndex", 1)
end


local highestIndex = loadHighestIndex()


---Save the current index as the highest index if it is higher than the current highest index
---@param currentIndex number
local function saveHighestIndex(currentIndex)
    if currentIndex > highestIndex then
        highestIndex = currentIndex
        settings.set("quarry.highestIndex", highestIndex)
        settings.save()
    end
end



---Do things before starting the quarry
---@param path Position[] The path of the turtle through the quarry
---@param skipTo number? The index of the path to skip to (default 1)
---@return boolean _ Whether the pre-start was successful
local function preStartQuarry(path, skipTo)
    if not skipTo or skipTo == 1 then
        skipTo = 1
    else
        logger:info("Skipping to position %d/%d", skipTo, #path)
    end

    -- if we're at the origin, push items and refuel.
    -- otherwise, we're in the middle of the quarry, so there's nothing to do

    if turt.position:equals(turt.startingPosition, true) then
        turt.inventory:pushItems(turt.inventory:findKeyItemSlots())
    
        local requiredFuel = calculateFuelNeededFromPath(path, skipTo)
    
        turt.inventory:pullFuel(requiredFuel)
    
        if requiredFuel > turtle.getFuelLevel() then
            logger:error("Not enough fuel to mine the quarry and return (need %d)", requiredFuel)
            return false
        else
            discord.send("Quarry", "Starting quarry!")
            logger:info("Starting quarry! (Predicted fuel use: %d/%d)", requiredFuel, turtle.getFuelLevel())
            return true
        end
    else
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

    turt.inventory:pushItems(turt.inventory:findKeyItemSlots())
    
    if success then
        -- celebratory spin
        discord.send("Quarry", "Quarrying completed successfully!")
        logger:info("Quarrying successful! Celebratory spin!")
        turt:turnRight(4)
    else
        discord.send("Quarry", "Quarrying failed!")
    end

end


---Calculate the path of the turtle through the quarry (as a list of Position objects)
---@param xSize integer The size of the quarry in the x direction
---@param zSize integer The size of the quarry in the z direction
---@param layers integer The depth of the quarry
---@param layersToSkip? integer The number of layers to skip (default 0)
---@return Position[]? _ The path of the turtle through the quarry
local function calculateQuarryPath(xSize, zSize, layers, layersToSkip)
    if not layersToSkip then
        layersToSkip = 0
    end

    if layers < 1 then
        logger:error("Quarry depth must be at least 1")
        return
    end

    if layersToSkip > layers then
        logger:error("Cannot skip more layers than there are")
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
    logger:info("Skipping to layer %d", layersToSkip)

    for layerNumber = 0, layers - 1 do
        if layerNumber < layersToSkip then
            table.insert(path, currentPos:add(Position(
                0,
                - layerNumber * LAYER_DEPTH,
                0,
                enums.Direction.NIL
            )))
            goto continue
        end

        if layerNumber % 2 == 0 then
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
        else
            for stripNumber = xSizeAbs - 1, 0, -1 do
                if stripNumber % 2 == 0 then
                    for blockNumber = zSizeAbs - 1, 0, -1 do
                        table.insert(path, currentPos:add(Position(
                            stripNumber * xDir,
                            - layerNumber * LAYER_DEPTH,
                            blockNumber * zDir,
                            enums.Direction.NIL
                        )))
                    end
                else
                    for blockNumber = 0, zSizeAbs - 1 do
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
        ::continue::
    end

    table.insert(path, turt.startingPosition)

    return path
end


---Check if the turtle is currently at a position along a path, and return the index of that position
---@param path Position[] The path to check
---@param positionOverride? Position The position to check against instead of the turtle's current position
---@return number? _ The index of the position the turtle is at, or nil if the turtle is not at any position
local function checkTurtlePosition(path, positionOverride)
    for i, pos in ipairs(path) do
        local currentPosition = positionOverride or turt.position
        if currentPosition:equals(pos, true) then
            return i
        end
    end

    return nil
end


---Follow a path of Positions through the quarry, digging as we go
---@param path Position[] The path to follow
---@param skipTo number? The index of the path to skip to (default 1)
---@return boolean, string? _ Whether the path was followed successfully and an error message if not
local function followQuarryPath(path, skipTo)
    if not skipTo then
        skipTo = 1
    end

    if skipTo > 1 then
        logger:info("Turtle is already in the quarry path at position %d, will skip there", skipTo)
    end

    for i = skipTo, #path do
        local pos = path[i]
        local moveRes, moveErr = turt:moveTo(pos, MOVEMENT_ARGS)
        if not moveRes then
            logger:error("Failed to move to %s: %s", pos:asString(), moveErr)
            return false, moveErr
        end

        saveHighestIndex(i)

        local digDownRes, digDownErr = turt:digDown(MOVEMENT_ARGS)
        if not digDownRes then
            logger:error("Failed to dig down at %s: %s", pos:asString(), digDownErr)
            return false, digDownErr
        end

        local digUpRes, digUpErr = turt:digUp(MOVEMENT_ARGS)
        if not digUpRes then
            logger:error("Failed to dig up at %s: %s", pos:asString(), digUpErr)
            return false, digUpErr
        end
    end

    return true
end


local quarryPath = calculateQuarryPath(xSizeArg, zSizeArg, layersArg, layersToSkipArg)

if not quarryPath then
    logger:error("Failed to calculate quarry path")
    return
end

local doQuarry = true
local quarryRes = false
local queryErr = nil

while doQuarry do
    local currentPosIndex = nil

    currentPosIndex = checkTurtlePosition(quarryPath, turt.resumePosition)

    if currentPosIndex and currentPosIndex <= 1 then
        currentPosIndex = highestIndex
    end

    if currentPosIndex and currentPosIndex >= #quarryPath then
        logger:info("Quarrying already complete!")
        return
    end

    if not preStartQuarry(quarryPath, currentPosIndex) then
        return false
    end

    if turt.resumePosition then
        local fullReturnRes, fullReturnError = turt:returnToResumeLocation(MOVEMENT_ARGS)
        if not fullReturnRes then
            logger:error("Failed to return to resume location: %s", fullReturnError)
            return
        end
    end

    quarryRes, queryErr = followQuarryPath(quarryPath, currentPosIndex)

    -- if we failed to mine the quarry, we'll try again. otherwise, we're done.
    doQuarry = not quarryRes

    if not quarryRes then
        -- we failed
        if queryErr == enums.ERRORS.NO_INVENTORY_SPACE then
            logger:warn("Restarting quarry due to error: %s", queryErr)
        else
            -- but we fatally failed
            discord.send("Quarry", "Quarrying path following failed due to error: " .. queryErr)
            logger:error("Failed to mine the quarry: %s", queryErr)
            doQuarry = false
        end
    end
end

postFinishQuarry(quarryRes)
