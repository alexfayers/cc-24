---storage2 Client class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

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
    if not self.modemName then
        return nil
    end

    local serverId = settings.get(SERVER_ID_SETTING_NAME)
    if serverId then
        logger:debug("Using server ID from settings: %d", serverId)
        return serverId
    end

    logger:info("Searching for a %s server...", self.protocol)
    serverId = rednet.lookup(self.protocol)

    if not serverId then
        logger:error("No server found")
        return nil
    end

    logger:info("%s is running on %d", self.protocol, serverId)

    settings.set(SERVER_ID_SETTING_NAME, serverId)

    return serverId
end


---Send a refresh request to the server
---@return boolean, nil
function Client:refresh()
    if not self.serverId then
        return false
    end

    local isProcessing, messageType, _ = self:sendCommandWait(self.serverId, MessageType.CMD_REFRESH)

    if not isProcessing then
        if not messageType then
            logger:error("Server is busy")
            return false
        end

        logger:error("Error: " .. messageType)
        return false
    end

    if messageType == MessageType.DONE then
        -- Really should only return a DONE so this is a bit redundant.
        -- worth checking tho.
        logger:info("Refresh complete")
        return true
    end

    logger:error("Unexpected response: " .. messageType)
    return false
end


---Safely call a command, closing the connection if there are any issues
---@param func fun(): boolean, table?
---@return boolean, table?
function Client:callCommand(func)
    local status, res, data = xpcall(func, function(err)
        logger:error("Error: %s", err)
    end, self)

    self:closeModem()

    if not status then
        return false
    end

    return res, data
end