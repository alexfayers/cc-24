---storage2 Server class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-remote.Remote")
require("lib-remote.types.MessageErrorCode")
require("lib-remote.types.MessageType")

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

---@alias CommandHandler fun(clientId: number, data?: table): boolean, table?

---@type table<string, CommandHandler>[]
Server.commandHandlers = {}

---Initialise a new storage2 server
function Server:init()
    Remote.init(self)
    self.hostname = self.protocol .. "-" .. os.getComputerID()
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


---Listen for commands
---@return boolean
function Server:_listen()
    if not self:startUp() then
        return false
    end

    while true do
        local senderId, messageType, data = self:receiveData(nil, nil, MessageType.CMD)
        if not messageType then
            goto continue
        end
        ---@cast data MessageCommandData

        local commandType = data.type
        local commandData = data.data
        local chatId = data.chat_id

        local handler = self.commandHandlers[commandType]

        if not handler then
            logger:warn("<%d|No handler for %s", senderId, commandType)
            self:sendError(
                senderId,
                chatId,
                MessageErrorCode.UNKNOWN_COMMAND,
                "No handler for %s",
                commandType
            )
            goto continue
        end

        local handlerRes, handlerData = handler(self, senderId, commandData)

        if not handlerRes then
            logger:warn("<%d|Failed to handle %s", senderId, commandType)
            self:sendError(
                senderId,
                chatId,
                MessageErrorCode.UNKNOWN,
                "Failed to handle %s",
                commandType
            )
            goto continue
        else
            if not handlerData then
                handlerData = {}
            end

            handlerData.chat_id = chatId

            self:sendData(senderId, MessageType.END, handlerData)
        end

        logger:info("<%d|Handled %s (%s)", senderId, messageType, commandType)

        ::continue::
    end
end


---Listen for commands and safely shutdown the server on error/exit using xpcall
---@return boolean
function Server:listen()
    local status, listenRes = xpcall(self._listen, function (err)
        logger:fatal("Fatal server error: %s", err)
    end, self)

    self:shutDown()

    if not status or not listenRes then
        return false
    end

    return true
end
