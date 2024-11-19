---storage2 Client class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local pretty = require("cc.pretty")

local enums = require("lib-storage2.remote.enums")
require("lib-storage2.remote.Remote")

local logger = require("lexicon-lib.lib-logging").getLogger("Client")

local MessageType = enums.MessageType


local SERVER_ID_SETTING_NAME = "storage2-remote.server-id"

settings.define(SERVER_ID_SETTING_NAME, {
    description = "The ID of the storage2 server to connect to",
    type = "number",
    default = nil,
})


---@class Client: Remote
---@overload fun(): Client
Client = Remote:extend()

Client.protocol = "storage2-remote"


---Initialise a new storage2 client
function Client:init()
    Remote.init(self)
    ---@type number?
    self.serverId = self:findServer()
end


---Find the server to connect to
---@return number?
function Client:findServer()
    local serverId = settings.get(SERVER_ID_SETTING_NAME)
    if serverId then
        logger:debug("Using server ID from settings: %d", serverId)
        return serverId
    end

    if not self:openModem() then
        return nil
    end

    logger:info("Searching for a %s server...", self.protocol)

    serverId = rednet.lookup(self.protocol)
    self:closeModem()

    if not serverId then
        logger:error("No server found")
        return nil
    end

    logger:info("%s is running on %d", self.protocol, serverId)

    settings.set(SERVER_ID_SETTING_NAME, serverId)

    return serverId
end



---Send a command to the server, handling any responses
---@param sendMessageType MessageType
---@param sendData? table
---@return boolean, table?
function Client:baseSendCommand(sendMessageType, sendData)
    if not self.serverId then
        logger:error("No server to send to")
        return false
    end

    local isProcessing, messageType, messageData = self:sendCommandWait(self.serverId, sendMessageType, sendData)

    if not isProcessing then
        if not messageType then
            logger:error("Server is busy")
            return false
        end

        logger:error("Error: " .. messageType)
        return false
    end

    if messageType == MessageType.DONE then
        return true, messageData
    end

    logger:error("Unexpected response: " .. messageType)
    return false
end


---Send a refresh request to the server
---@return boolean, nil
function Client:refresh()
    local res, _ = self:baseSendCommand(MessageType.CMD_REFRESH)

    if res then
        return true
    end

    return false
end


---Get the input and output chest names from the server
---@return boolean, table?
function Client:getChestNames()
    return self:baseSendCommand(MessageType.CMD_DATA_IO_CHESTS)
end


---Ping the server, printing how long it took
---@return boolean, table?
function Client:ping()
    local start = os.clock()
    local res, data = self:baseSendCommand(MessageType.CMD_PING)
    local duration = os.clock() - start

    if res then
        logger:info("Pong! Took %.2f seconds", duration)
    end

    return res, data
end


---Pull items from the storage chests to an inventory
---@param outputChestName string The name of the inventory to pull to
---@param item string
---@param count number
---@param toSlot number?
---@return boolean, table?
function Client:pull(outputChestName, item, count, toSlot)
    local res, data = self:baseSendCommand(MessageType.CMD_PULL, {
        item = item,
        count = count,
        invName = outputChestName,
        toSlot = toSlot,
    })

    return res, data
end


---Push items from an inventory to the storage chests
---@param inputChestName string The name of the inventory to push from
---@param slots? number[]
---@return boolean, table?
function Client:push(inputChestName, slots)
    local res, data = self:baseSendCommand(MessageType.CMD_PUSH, {
        invName = inputChestName,
        fromSlots = slots,
    })

    return res, data
end


---Safely call a command, closing the connection if there are any issues
---@param func fun(...): boolean, table?
---@return boolean, table?
function Client:callCommand(func, ...)
    local status, res, data = xpcall(func, function(err)
        logger:error("Error: %s", err)
    end, self, ...)

    self:closeModem()

    if not status then
        return false
    end

    return res, data
end