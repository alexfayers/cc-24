---Will mine the column above the turtle until it runs out of blocks,
---or runs out of space, and then return to the starting position.
package.path = package.path .. ";/usr/lib/?.lua"
require("lib-turtle.Turtle")

turt = Turtle()

local movementArgs = {
    dig = true,
    safe = true,
    autoReturnIfFull = true,
}


while true do
    local beforeDigCount = turt.inventory:totalItemCount()
    local digRes, digErr = turt:digUp(movementArgs)
    if not digRes then
        error(digErr, 0)
    end
    local afterDigCount = turt.inventory:totalItemCount()

    if beforeDigCount == afterDigCount then
        -- No blocks were mined
        break
    end

    local moveRes, moveErr = turt:up(1, movementArgs)

    if not moveRes then
        error(moveErr, 0)
    end
end


turt:returnToOrigin()

print("Finished mining column")
