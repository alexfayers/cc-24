---Simple farm program
---This program will farm a field of crops, and replant them as it goes.
---The turtle will farm the field in a serpentine pattern, starting from the bottom left.
---The turtle will return to the starting position when it is done.
---The turtle will stop if it runs out of fuel, or if it runs out of inventory space (returning to the starting position).
---The turtle will also return if it runs out of seeds to plant.

package.path = package.path .. ";/usr/lib/?.lua"

local discord = require("lib-discord.discord")
require("lib-turtle.Turtle")
require("lib-turtle.Position")
local enums = require("lib-turtle.enums")
local Direction = enums.Direction

settings.define("farm.height", {
    description = "The height of the farm",
    type = "number",
    default = 0,
})

settings.define("farm.width", {
    description = "The width of the farm",
    type = "number",
    default = 0,
})

settings.define("farm.seeds", {
    description = "The item name of the seeds to plant",
    type = "string",
    default = "",
})

---@type number
local farmHeight = settings.get("farm.height")
if farmHeight == 0 then
    error("Farm height must be set", 0)
end
if farmHeight < 0 then
    error("Farm height must be positive", 0)
end


---@type number
local farmWidth = settings.get("farm.width")
if farmWidth == 0 then
    error("Farm width must be set", 0)
end
if farmWidth <= 0 then
    error("Farm width must be positive", 0)
end


---@type string
local seeds = settings.get("farm.seeds")
if seeds == "" then
    error("Seeds must be set", 0)
end


local MOVEMENT_ARGS = {
    dig = false,
    safe = true,
    autoReturn = true,
    autoReturnIfFull = true,
}


turt = Turtle()


---@overload fun(self: Turtle, inspectedBlockPosition: Position, inspectedBlockData: ccTweaked.turtle.inspectInfo): boolean
local function inspectWheat(self, inspectedBlockPosition, inspectedBlockData)
    if inspectedBlockData.name ~= "minecraft:wheat" then
        return false
    end

    if inspectedBlockData.state.age == 7 then
        return true
    end

    return false
end

table.insert(turt.inspectHandlers, inspectWheat)


---Farm a field of crops
---@param height number The height of the field
---@param width number The width of the field
---@return boolean, string? # Whether the farm was successful
local function farm(height, width)
    --- move to the first farmland
    discord.send("Farm", "Starting farm")

    for x = 0, width do
        for y = 1, height + 1 do
            local thisY
            if x % 2 == 0 then
                thisY = y
            else
                thisY = height + 1 - y
            end

            print(x .. ", " .. y) -- Debugging
            
            local moveRes, moveError = turt:moveTo(Position(x, 0, -thisY, Direction.NIL), MOVEMENT_ARGS)
            if not moveRes then
                return false, moveError
            end
            turt:digDown(MOVEMENT_ARGS)

            if not turt.inventory:selectItem(seeds) then
                return false, "Out of seeds"
            end

            turt:placeDown(MOVEMENT_ARGS)
        end
    end

    return true
end

local farmArea = farmHeight * farmWidth
local worstCaseFuel = farmArea + farmHeight + farmWidth

turt.inventory:pullFuel(worstCaseFuel)

local currentFuel = turtle.getFuelLevel()

if currentFuel < worstCaseFuel then
    discord.send("Farm", "Not enough fuel to farm (" .. currentFuel .. "/" .. worstCaseFuel .. ")")
    error("Not enough fuel to farm (" .. currentFuel .. "/" .. worstCaseFuel .. ")", 0)
end

local farmRes, farmError = farm(farmHeight, farmWidth)

local originRes, originErr = turt:returnToOrigin()
if not originRes then
    error("Failed to return to origin! " .. originErr, 0)
end

local seedSlotNumber, _ = turt.inventory:findItem(seeds)
local keepSlots = seedSlotNumber and {seedSlotNumber} or nil

turt.inventory:pushItems(keepSlots)

if not farmRes then
    discord.send("Farm", "Farm failed :( - " .. farmError)
    error(farmError, 0)
end

discord.send("Farm", "Farm done")
print("Farm successful")
