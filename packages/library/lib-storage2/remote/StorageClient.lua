---storage2 Client class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-remote.Client")
require("lib-storage2.remote.CommandType")


---@class StorageClient: Client
---@overload fun(): StorageClient
StorageClient = Client:extend()

StorageClient.protocol = "storage2-remote"


---Send a refresh request to the server
---@return boolean, nil
function StorageClient:refresh()
    return self:baseSendCommand(CommandType.REFRESH)
end


---Get the input and output chest names from the server
---@return boolean, table?
function StorageClient:getChestNames()
    return self:baseSendCommand(CommandType.DATA_IO_CHESTS)
end


---Ping the server, printing how long it took
---@return boolean, table?
function StorageClient:ping()
    local start = os.clock()
    local res, data = self:baseSendCommand(CommandType.PING)
    local duration = os.clock() - start

    if res then
        print(string.format("Pong! Took %.2f seconds", duration))
    end

    return res, data
end


---Pull items from the storage chests to an inventory
---@param outputChestName string The name of the inventory to pull to
---@param item string
---@param count number
---@param toSlot number?
---@return boolean, table?
function StorageClient:pull(outputChestName, item, count, toSlot)
    return self:baseSendCommand(CommandType.PULL, {
        item = item,
        count = count,
        invName = outputChestName,
        toSlot = toSlot,
    })
end


---Push items from an inventory to the storage chests
---@param inputChestName string The name of the inventory to push from
---@param slots? number[]
---@return boolean, table?
function StorageClient:push(inputChestName, slots)
    return self:baseSendCommand(CommandType.PUSH, {
        invName = inputChestName,
        fromSlots = slots,
    })
end
