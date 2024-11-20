---storage2 Client class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-remote.Remote")
require("lib-remote.types.MessageType")

local logger = require("lexicon-lib.lib-logging").getLogger("Client")


---@class Client: Remote
---@overload fun(): Client
Client = Remote:extend()


---Initialise a new storage2 client
function Client:init()
    Remote.init(self)
    ---@type number?
    self.serverId = self:findServer()
end


---Find the server to connect to
---@return number?
function Client:findServer()
    local SERVER_ID_SETTING_NAME = self.protocol .. ".server-id"

    settings.define(SERVER_ID_SETTING_NAME, {
        description = "The ID of the " .. self.protocol .. " server to connect to",
        type = "number",
        default = nil,
    })

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
---@param commandType string
---@param sendData? table
---@return boolean, table?
function Client:baseSendCommand(commandType, sendData)
    if not self.serverId then
        logger:error("No server to send to")
        return false
    end

    local isProcessing, messageType, messageData = self:sendDataWait(
        self.serverId,
        MessageType.CMD,
        {
            type = commandType,
            data = sendData,
        }
    )

    if not isProcessing then
        if not messageType then
            logger:error("Server is busy")
            return false
        end

        logger:error("Error: " .. messageType)
        return false
    end

    if messageType == MessageType.END then
        return true, messageData
    end

    if messageType ~= nil then
        logger:error("Unexpected response: %s", messageType)
        return false
    end

    return false
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