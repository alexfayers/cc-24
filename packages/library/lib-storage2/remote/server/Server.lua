---storage2 Server class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local enums = require("lib-storage2.remote.enums")
local chestHelpers = require("lib-storage2.chestHelpers")
require("lib-storage2.Map")
require("lib-storage2.remote.Remote")

local logger = require("lexicon-lib.lib-logging").getLogger("Server")

---@type _MessageType
local MessageType = enums.MessageType

---@alias CommandHandler fun(clientId: number, data?: table): boolean

-- Class definition

---@class Server: Remote
---@overload fun(): Server
Server = Remote:extend()

Server.filterCommands = {
    [MessageType.ACKNOWLEDGE] = true,
    [MessageType.DONE] = true,
    [MessageType.UNKNOWN_COMMAND] = true,
    [MessageType.UNKNOWN_ERROR] = true,
}
Server.commandHandlers = {
    [MessageType.COMMAND_REFRESH] = Server.handleRefresh,
}

---Initialise a new storage2 server
function Server:init()
    Remote.init(self)
    self.hostname = self.protocol .. "-" .. os.getComputerID()
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

    rednet.host(self.protocol, self.hostname)

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


---Listen for commands
---@return boolean
function Server:listen()
    if not self.modemName then
        return false
    end

    logger:info("Started listening for %s commands...", self.protocol)

    while true do
        local senderId, messageType, data = self:receiveData()
        if not messageType then
            goto continue
        end

        local handler = self.commandHandlers[messageType]

        if not handler then
            logger:warn("No handler for message type %s", messageType)
            self:sendData(senderId, MessageType.UNKNOWN_COMMAND)
            goto continue
        end

        if not handler(self, senderId, data) then
            logger:warn("Failed to handle message type %s", messageType)
            self:sendData(senderId, MessageType.UNKNOWN_ERROR)
            goto continue
        else
            self:sendData(senderId, MessageType.DONE)
        end

        logger:info("Handled %s from %s", messageType, senderId)

        ::continue::
    end
end
