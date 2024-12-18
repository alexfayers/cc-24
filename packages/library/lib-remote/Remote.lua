---storage2 Remote class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-remote.types.MessageErrorCode")
require("lib-remote.types.MessageType")
require("lib-remote.types.MessageTypeArgs")

local logger = require("lexicon-lib.lib-logging").getLogger("Remote")


---@class Remote: Class
---@overload fun(): Remote
Remote = class()

Remote.protocol = "lexicon-remote"

---@type table<string, boolean>
Remote.filterCommands = {}
Remote.wired = true


---Initialise a new storage2 client
function Remote:init()
    self.processing = false
    ---@type string?
    self.modemName = nil
end


---Generate a random ID for a conversation
---@return number
function Remote:generateId()
    return os.epoch("utc") + (math.random(100000, 999999) * 10)
end


---Deserialise a message received over the network
---@param message string
---@return MessageType?, MessageData?
function Remote:unserialiseMessage(message)
    ---Messages are in the following format:
    ---<messageType>|<serialised data...>
    ---or
    ---<messageType>
    ---
    ---(The data is optional)

    local split = string.find(message, "|")
    if not split then
        return MessageType[message], nil
    end

    local messageTypeRaw = string.sub(message, 1, split - 1)
    local dataRaw = string.sub(message, split + 1)

    ---@type MessageType?
    local messageType = MessageType[messageTypeRaw]
    if not messageType then
        return nil, nil
    end

    local messageTypeArgs = MessageTypeArgs[messageType]

    if messageTypeArgs then
        local data = textutils.unserialize(dataRaw)
        if not data then
            return nil, nil
        end

        for _, arg in ipairs(messageTypeArgs) do
            local receivedArgType = type(data[arg.name])
            local argType = arg.type

            if type(argType) == "table" then
                local valid = false
                for _, t in ipairs(argType) do
                    if receivedArgType == t then
                        valid = true
                        break
                    end
                end

                if not valid then
                    return nil, nil
                end
            else
                if receivedArgType ~= argType then
                    return nil, nil
                end
            end
        end

        return messageType, data
    end

    return messageType, nil
end


---Serialise a message to be sent over the network
---@param messageType MessageType
---@param data? MessageData
---@return string?
function Remote:serialiseMessage(messageType, data)
    if not MessageType[messageType] then
        logger:warn("Can't serialise type: %s", messageType)
        return nil
    end

    return messageType .. (data and (
        "|" .. (textutils.serialize(data, {compact=true}) or "")
    ) or "")
end


---Find a modem and open it with rednet, returning true if successful
---@return boolean
function Remote:_findAndAddModem()
    local modem = nil
    if self.wired then
        modem = peripheral.find("modem", function (name, wrapped)
            return not wrapped.isWireless()
        end)
    else
        modem = peripheral.find("modem", function (name, wrapped)
            return wrapped.isWireless()
        end)
    end

    if not modem then
        logger:error("No modem found. Remote will not work.")
        return false
    end

    if not peripheral.hasType(modem, "modem") then
        return false
    end

    ---@cast modem ccTweaked.peripherals.Modem
    local modemName = peripheral.getName(modem)

    self.modemName = modemName

    return true
end


---Remove the modem
---@return boolean
function Remote:removeModem()
    if not self.modemName then
        return false
    end

    self.modemName = nil

    return true
end


---Open the modem
---@return boolean
function Remote:openModem()
    if not self.modemName then
        if not self:_findAndAddModem() then
            return false
        end
    end

    rednet.open(self.modemName)

    return true
end


---Close the modem
---@return boolean
function Remote:closeModem()
    if not self.modemName then
        return false
    end

    rednet.close(self.modemName)
    self:removeModem()

    return true
end


---Send data to a computer
---@param remoteId number
---@param message MessageType
---@return boolean
function Remote:sendDataRaw(remoteId, message)
    if not self:openModem() then
        return false
    end

    return rednet.send(remoteId, message, self.protocol)
end


---Send a command to a computer
---@param remoteId number
---@param messageType MessageType
---@param data? MessageData
---@return boolean
function Remote:sendData(remoteId, messageType, data)
    local message = self:serialiseMessage(messageType, data)
    if not message then
        return false
    end
    local res = self:sendDataRaw(remoteId, message)

    local chatId = data and data.chat_id or nil
    local chatIdStr = chatId and (" (chat id: %d)"):format(chatId) or ""
    if res then
        logger:debug(">%d|Sent %s%s", remoteId, messageType, chatIdStr)
    else
        logger:warn(">%d|Send failed: %s%s", remoteId, message, chatIdStr)
    end

    return res
end


---Send an error message to a computer
---@param remoteId number
---@param chatId? number
---@param errorCode MessageErrorCode
---@param message? string
function Remote:sendError(remoteId, chatId, errorCode, message, ...)
    if message then
        message = string.format(message, ...)
    end

    local payload = {
        code = errorCode,
    }

    if message then
        payload.message = message
    end

    if chatId then
        payload.chat_id = chatId
    end

    self:sendData(remoteId, MessageType.ERR, payload)
end


---Send command to a computer and wait for a response.
---Handles the ACKNOWLEDGE and then waits for a DONE message.
---@param remoteId number
---@param messageType MessageType
---@param data? MessageData
---@return boolean, MessageType?, MessageEndData?
function Remote:sendDataWait(remoteId, messageType, data)
    local chat_id = self:generateId()

    if not data then
        data = {}
    end

    data.chat_id = chat_id

    if not self:sendData(remoteId, messageType, data) then
        return false, nil
    end

    local senderId, responseMessageType, responseData = self:receiveData(remoteId, chat_id, MessageType.ACK, 1)

    if not senderId then
        -- no response
        return false, nil
    end

    --- we got an ACK, now wait for the actual response
    senderId, responseMessageType, responseData = self:receiveData(remoteId, chat_id, nil, 10)

    if not senderId then
        -- no response
        return false, nil
    end

    if responseMessageType ~= MessageType.END then
        logger:warn("<%d|Expected END, got %s", senderId, responseMessageType)
        return false, responseMessageType, responseData
    end

    return true, responseMessageType, responseData
end


---Receive data from a computer
---@param expectedSender? number
---@param expectedChatId? number
---@param expectedMessageType? MessageType
---@param timeout? number
---@return number, MessageType?, table?
function Remote:receiveData(expectedSender, expectedChatId, expectedMessageType, timeout)
    local senderId, message
    ---@type MessageType?, MessageData?
    local messageType, data
    local chatId = nil
    if not self:openModem() then
        goto nilReturn
    end

    self.processing = false

    ::receive::

    senderId, message = rednet.receive(self.protocol, timeout)

    self.processing = true

    if not senderId then
        goto nilReturn
    end

    if expectedSender and senderId ~= expectedSender then
        logger:debug("<%d|Expected id: %d", senderId, expectedSender)
        goto receive
    end

    --- make sure the message is a string
    if type(message) ~= "string" then
        logger:warn("<%d|Non-string: %s", senderId, message)

        self:sendData(senderId, MessageType.ERR, {
            chat_id = expectedChatId,
            code = MessageErrorCode.INVALID_DATA_TYPE
        })
        goto nilReturn
    end
    ---@cast message string

    messageType, data = self:unserialiseMessage(message)

    if not messageType then
        logger:warn("<%d|Unknown message type: %s", senderId, messageType)
        self:sendError(senderId, expectedChatId, MessageErrorCode.UNKNOWN_COMMAND, messageType)
        goto nilReturn
    end

    if self.filterCommands[messageType] then
        goto receive
    end

    chatId = data and data.chat_id

    if expectedChatId then
        if not chatId or chatId ~= expectedChatId then
            logger:debug("<%d|Expected chat id: %d, got %s", senderId, expectedChatId, chatId)
            goto receive
        end
    end

    if messageType == MessageType.ERR then
        ---@cast data MessageErrorData
        logger:warn("<%d|Error: %s", senderId, data.message and ("%s (%s)"):format(data.code, data.message) or data.code)
        goto nilReturn
    end

    if expectedMessageType and messageType ~= expectedMessageType then
        logger:debug("<%d|Expected %s, got %s", senderId, expectedMessageType, messageType)
        goto receive
    end

    logger:debug("<%d|Valid: %s (chat %s)", senderId, messageType, chatId)

    if messageType == MessageType.CMD and not self:sendData(senderId, MessageType.ACK, {chat_id = chatId}) then
        goto nilReturn
    end

    do
        return senderId, messageType, data
    end

    ::nilReturn::
    self.processing = false
    return senderId, nil, nil
end
