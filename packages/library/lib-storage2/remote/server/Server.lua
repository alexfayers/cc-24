---storage2 Server class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local enums = require("lib-storage2.remote.enums")
local chestHelpers = require("lib-storage2.chestHelpers")
require("lib-storage2.Map")
require("lib-storage2.remote.Remote")

local logger = require("lexicon-lib.lib-logging").getLogger("Server")

local MessageType = enums.MessageType


---@alias CommandHandler fun(clientId: number, data?: table): boolean, table?

-- Class definition

---@class Server: Remote
---@overload fun(): Server
Server = Remote:extend()

Server.filterCommands = {
    [MessageType.ACK] = true,
    [MessageType.DONE] = true,
    [MessageType.ERR_UNKNOWN_COMMAND] = true,
    [MessageType.ERR_UNKNOWN] = true,
}

---Initialise a new storage2 server
function Server:init()
    Remote.init(self)
    self.hostname = self.protocol .. "-" .. os.getComputerID()

    self.commandHandlers = {
        [MessageType.CMD_REFRESH] = self.handleRefresh,
        [MessageType.CMD_DATA_IO_CHESTS] = self.handleDataIoChests,
    }

    self:startUp()
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
    self:initPeripherals()

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


---Listen for commands
---@return boolean
function Server:_listen()
    if not self.modemName then
        return false
    end

    logger:info("Starting up...", self.protocol, self.hostname)
    rednet.host(self.protocol, self.hostname)

    logger:info("%s server started!", self.protocol)

    while true do
        local senderId, messageType, data = self:receiveData()
        if not messageType then
            goto continue
        end

        local handler = self.commandHandlers[messageType]

        if not handler then
            logger:warn("<%d|No handler for %s", senderId, messageType)
            self:sendData(senderId, MessageType.ERR_UNKNOWN_COMMAND)
            goto continue
        end

        local handlerRes, handlerData = handler(self, senderId, data)

        if not handlerRes then
            logger:warn("<%d|Failed to handle %s", senderId, messageType)
            self:sendData(senderId, MessageType.ERR_UNKNOWN)
            goto continue
        else
            self:sendCommand(senderId, MessageType.DONE, handlerData)
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
