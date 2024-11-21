---storage2 Server class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local chestHelpers = require("lib-storage2.chestHelpers")
require("lib-storage2.Map")
require("lib-remote.Server")
require("lib-storage2.remote.CommandType")


-- Class definition

---@class StorageServer: Server
---@overload fun(): StorageServer
StorageServer = Server:extend()

StorageServer.protocol = "storage2-remote"


---Initialise a new storage2 server
function StorageServer:init()
    Server.init(self)

    self.commandHandlers = {
        [CommandType.REFRESH] = self.handleRefresh,
        [CommandType.DATA_IO_CHESTS] = self.handleDataIoChests,
        [CommandType.PING] = self.handlePing,
        [CommandType.PULL] = self.handlePull,
        [CommandType.PUSH] = self.handlePush,
        [CommandType.ITEM_COUNT] = self.handleCount,
    }

    self:initPeripherals()
end


---Initialise the storage-related peripherals
---@return boolean
function StorageServer:initPeripherals()
    local inputChest = chestHelpers.getInputChest()
    if not inputChest then
        return false
    end
    self.inputChest = inputChest

    local outputChest = chestHelpers.getOutputChest()
    if not outputChest then
        return false
    end
    self.outputChest = outputChest

    local storageChests = chestHelpers.getStorageChests(inputChest, outputChest)
    if not storageChests then
        return false
    end
    self.storageChests = storageChests

    self.storageMap = Map(self.storageChests)

    return true
end


---Handle a refresh request from a client
---@param clientId number
---@param data? table
---@return boolean
function StorageServer:handleRefresh(clientId, data)
    self.storageMap:populate(true)
    self.storageMap:save()

    return true
end


---Handle an input/output chests request from a client
---@param clientId number
---@param data? table
---@return boolean, table?
function StorageServer:handleDataIoChests(clientId, data)
    local res = {
        inputChest = peripheral.getName(self.inputChest),
        outputChest = peripheral.getName(self.outputChest),
    }

    return true, res
end


---Handle an ping request from a client
---@param clientId number
---@param data? table
---@return boolean, table
function StorageServer:handlePing(clientId, data)
    return true, {pong = true}
end


---Handle a pull request from a client
---@param clientId number
---@param data? table
---@return boolean, table?
function StorageServer:handlePull(clientId, data)
    if not data then
        return false
    end

    if not data.invName or not data.item or not data.count then
        return false
    end

    local pullToChest = chestHelpers.wrapInventory(data.invName)

    if not pullToChest then
        return false
    end

    self.storageMap:populate()

    local fuzzy = true
    if data.fuzzy ~= nil then
        fuzzy = data.fuzzy
    end

    local pulledCount = self.storageMap:pull(pullToChest, data.item, data.count, fuzzy, data.toSlot)

    if pulledCount > 0 then
        self.storageMap:save()
    end

    local res = {
        count = pulledCount,
    }

    return true, res
end


---Handle a push request from a client
---@param clientId number
---@param data? table
---@return boolean, table?
function StorageServer:handlePush(clientId, data)
    if not data then
        return false
    end

    if not data.invName then
        return false
    end

    local pushFromChest = chestHelpers.wrapInventory(data.invName)

    if not pushFromChest then
        return false
    end

    self.storageMap:populate()

    local pushedCount = self.storageMap:push(pushFromChest, data.fromSlots)

    if pushedCount > 0 then
        self.storageMap:save()
    end

    local res = {
        count = pushedCount,
    }

    return true, res
end


---Handle a count request from a client
---@param clientId number
---@param data table
---@return boolean, table?
function StorageServer:handleCount(clientId, data)
    if not data.item then
        return false
    end

    self.storageMap:populate()

    local count = self.storageMap:getTotalItemCount(data.item, false)

    local res = {
        count = count,
    }

    return true, res
end