---storage2 Server class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local chestHelpers = require("lib-storage2.chestHelpers")
require("lib-storage2.Map")
require("lib-storage2.remote.Remote")
require("lib-storage2.remote.RemoteMessageType")
require("lib-storage2.remote.CommandType")

local logger = require("lexicon-lib.lib-logging").getLogger("Server")


-- Class definition

---@class Server: Remote
---@overload fun(): Server
Server = Remote:extend()

Server.filterCommands = {
    [MessageType.ACK] = true,
    [MessageType.END] = true,
    [MessageType.ERR] = true,
}

---Initialise a new storage2 server
function Server:init()
    Remote.init(self)
    self.hostname = self.protocol .. "-" .. os.getComputerID()

    self.commandHandlers = {
        [CommandType.REFRESH] = self.handleRefresh,
        [CommandType.DATA_IO_CHESTS] = self.handleDataIoChests,
        [CommandType.PING] = self.handlePing,
        [CommandType.PULL] = self.handlePull,
        [CommandType.PUSH] = self.handlePush,
    }

    self:initPeripherals()
end


---Initialise the storage-related peripherals
---@return boolean
function Server:initPeripherals()
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


---Start up the server
---@return boolean
function Server:startUp()
    logger:info("Starting up...", self.protocol, self.hostname)
    if not self:openModem() then
        return false
    end

    rednet.host(self.protocol, self.hostname)

    logger:info("%s server started!", self.protocol)

    return true
end


---Shut down the server
---@return boolean
function Server:shutDown()
    if not self.modemName then
        return false
    end

    rednet.unhost(self.protocol)

    self:closeModem()

    return true
end


---Handle a refresh request from a client
---@param clientId number
---@param data? table
---@return boolean
function Server:handleRefresh(clientId, data)
    self.storageMap:populate(true)
    self.storageMap:save()

    return true
end


---Handle an input/output chests request from a client
---@param clientId number
---@param data? table
---@return boolean, table?
function Server:handleDataIoChests(clientId, data)
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
function Server:handlePing(clientId, data)
    return true, {pong = true}
end


---Handle a pull request from a client
---@param clientId number
---@param data? table
---@return boolean, table?
function Server:handlePull(clientId, data)
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

    local pulledCount = self.storageMap:pull(pullToChest, data.item, data.count, true, data.toSlot)

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
function Server:handlePush(clientId, data)
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


---Listen for commands
---@return boolean
function Server:_listen()
    if not self:startUp() then
        return false
    end

    while true do
        local senderId, messageType, data = self:receiveData(nil, MessageType.CMD)
        if not messageType then
            goto continue
        end
        ---@cast data MessageCommandData

        local commandType = data.type
        local commandData = data.data

        local handler = self.commandHandlers[commandType]

        if not handler then
            logger:warn("<%d|No handler for %s", senderId, messageType)
            self:sendError(
                senderId,
                MessageErrorCode.UNKNOWN_COMMAND,
                "No handler for %s",
                messageType
            )
            goto continue
        end

        local handlerRes, handlerData = handler(self, senderId, commandData)

        if not handlerRes then
            logger:warn("<%d|Failed to handle %s", senderId, messageType)
            self:sendError(
                senderId,
                MessageErrorCode.UNKNOWN,
                "Failed to handle %s",
                messageType
            )
            goto continue
        else
            self:sendData(senderId, MessageType.END, handlerData)
        end

        logger:info("<%d|Handled %s", senderId, messageType)

        ::continue::
    end
end


---Listen for commands and safely shutdown the server on error/exit using xpcall
---@return boolean
function Server:listen()
    local status, listenRes = xpcall(self._listen, function (err)
        logger:error("Error: %s", err)
    end, self)

    self:shutDown()

    if not status or not listenRes then
        return false
    end

    return true
end
