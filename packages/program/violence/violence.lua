---Program to repeatedly attack on a turtle that has a sword, for use with farms


local TURTLE_SLOTS = 16
local FULL_THRESHOLD = 0
local MISSED_ATTACK_CLEAR_THRESHOLD = 5


---Clear all of the items in the turtle's inventory
local function clearInventory()
    ---@type number[]
    local toDrop = {}

    for i = 1, TURTLE_SLOTS do
        if turtle.getItemCount(i) > 0 then
            table.insert(toDrop, i)
        end
    end

    if #toDrop <= FULL_THRESHOLD then
        return
    end

    for i = 1, #toDrop do
        turtle.select(toDrop[i])
        turtle.dropDown()
    end
end


print("im so angry!")

local missedAttacks = 0
while true do
    local didAttack = turtle.attack()

    if not didAttack then
        missedAttacks = missedAttacks + 1
    else
        missedAttacks = 0
    end
    
    if missedAttacks >= MISSED_ATTACK_CLEAR_THRESHOLD then
        clearInventory()
    end
end
