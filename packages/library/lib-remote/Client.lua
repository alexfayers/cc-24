---storage2 Client class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-remote.Remote")
require("lib-remote.types.MessageType")

local logger = require("lexicon-lib.lib-logging").getLogger("Client")

DEFAULT_CACHE_HOSTNAME = "?"


---@class Client: Remote
---@overload fun(): Client
Client = Remote:extend()

Client.filterCommands = {
    [MessageType.CMD] = true,
}


---Initialise a new storage2 client
function Client:init()
    Remote.init(self)

    ---@type table<string, number>?
    self.serverIds = nil

    self.server_id_cache_setting_name = self.protocol .. ".server-id-map"
    settings.define(self.server_id_cache_setting_name, {
        description = self.protocol .. " server id cache",
        type = "table",
        default = {},
    })
end


---Find the server to connect to
---@param hostname string?
---@return number?
function Client:findServer(hostname)
    ---@type table<string, number>
    local serverIds = self.serverIds or settings.get(self.server_id_cache_setting_name)

    local lookupHostname = hostname or DEFAULT_CACHE_HOSTNAME

    if serverIds[lookupHostname] then
        logger:debug("Using cached server ID: %d", serverIds[lookupHostname])
        return serverIds[lookupHostname]
    end

    if not self:openModem() then
        return nil
    end

    if hostname then
        logger:info("Searching for a %s server with hostname %s...", self.protocol, hostname)
    else
        logger:info("Searching for a %s server...", self.protocol)
    end

    local foundServerIds = { rednet.lookup(self.protocol, hostname) }
    self:closeModem()

    if #foundServerIds == 0 then
        logger:error("No server found")
        return nil
    end

    if #foundServerIds > 1 then
        logger:error("Multiple servers found (%d)", #foundServerIds)
        return nil
    end

    logger:info("%s is running on %d", self.protocol, foundServerIds[1])

    serverIds[lookupHostname] = foundServerIds[1]

    self.serverIds = serverIds
    settings.set(self.server_id_cache_setting_name, serverIds)
    settings.save()

    return foundServerIds[1]
end



---Send a command to the server, handling any responses
---@param commandType string
---@param sendData? table
---@param hostname? string
---@return boolean, table?
function Client:baseSendCommand(commandType, sendData, hostname)
    local serverId = self:findServer(hostname)

    if not serverId then
        logger:error("No server to send to")
        return false
    end

    local isProcessing, messageType, messageData = self:sendDataWait(
        serverId,
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
        logger:fatal("Fatal client error: %s", err)
    end, self, ...)

    -- self:closeModem()

    if not status then
        return false
    end

    return res, data
end