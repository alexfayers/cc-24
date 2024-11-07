---storage2 Client class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local enums = require("lib-storage2.remote.enums")
require("lib-storage2.remote.Remote")

local logger = require("lexicon-lib.lib-logging").getLogger("Client")

---@type _MessageType
local MessageType = enums.MessageType

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
    local serverName = rednet.lookup(self.protocol)

    if not serverName then
        logger:error("No server found")
        return nil
    end

    return serverName
end


---Send a refresh request to the server
---@return boolean
function Client:refresh()
    if not self.serverId then
        logger:error("No server found")
        return false
    end

    local isProcessing, messageType, _ = self:sendCommandWait(self.serverId, MessageType.COMMAND_REFRESH)

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