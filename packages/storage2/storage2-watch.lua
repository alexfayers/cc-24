-- Use the storage2 module to pull items from the input chest, forever
package.path = package.path .. ";/usr/lib/?.lua"

-- Import the storage2 module
local storage = require("storage2.lib-storage2")

local pretty = require("cc.pretty")

local function main()
    local inputChest = storage.getInputChest()
    if not inputChest then
        return
    end

    local outputChest = storage.getOutputChest()
    if not outputChest then
        return
    end

    local storageChests = storage.getStorageChests(inputChest, outputChest)
    if not storageChests then
        return
    end

    while true do
        while true do
            -- Wait for items to be in the chest
            local items = inputChest.list()

            local hasItems = false
            for _, item in pairs(items) do
                if item.count > 0 then
                    hasItems = true
                    break
                end
            end

            -- if there are items in the chest, break the loop
            if hasItems then
                break
            end
        end

        -- Load the storage map
        local storageMap = storage.loadOrPopulateStorageMap("storageMap.json", storageChests)

        -- Pull items from the chest into storage
        storageMap = storage.pushItems(storageMap, inputChest)

        -- Save the storage map
        storage.saveStorageMap("storageMap.json", storageMap)
    end
end

main()
