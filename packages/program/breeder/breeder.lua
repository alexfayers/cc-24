--- Breed animals using wheat from a storage2 system
--- To be installed on a turtle

package.path = package.path .. ";/usr/lib/?.lua"

require("lib-turtle.Turtle")
local logger = require("lexicon-lib.lib-logging").getLogger("Quarry")
local discord = require("lib-discord.discord")

local BREEDING_ITEM = "minecraft:wheat"

turt = Turtle()


---Selects the breeding item from the turtle's inventory, if it exists
---@return boolean
local function selectBreedingItem()
    return turt.inventory:selectItem(BREEDING_ITEM)
end


---Pull a stack of the breeding item from the storage2 system
---@return boolean, number?
local function pullBreedingItem()
    return turt.inventory:pullItems(BREEDING_ITEM, 64)
end


---Feed the animals in below the turtle with the breeding item until it runs out
---@return boolean
local function feedAnimals()
    if not selectBreedingItem() then
        return false
    end

    while true do
        if not turt:placeDown() then
            return true
        end
    end
end


---Main loop
---@return nil
local function main()
    logger:info("Starting breeding program")

    while true do
        if not feedAnimals() then
            logger:warn("No breeding items in inventory, trying to pull")
            if not pullBreedingItem() then
                logger:warn("Out of breeding items")
                discord.send("Breeder", "Out of breeding items")
                return
            end
        end
    end
end


main()
