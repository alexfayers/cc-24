---Program to repeatedly attack on a turtle that has a sword, for use with farms


local TURTLE_SLOTS = 16
local FULL_THRESHOLD = 8


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
        turtle.drop()
    end
end


print("im so angry!")
while true do
    turtle.attack() -- will wait until something's there

    clearInventory()
end
