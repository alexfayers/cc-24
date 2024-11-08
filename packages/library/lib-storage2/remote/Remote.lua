---storage2 Remote class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local enums = require("lib-storage2.remote.enums")

local logger = require("lexicon-lib.lib-logging").getLogger("Remote")

local MessageType = enums.MessageType


---@class Remote: Class
---@overload fun(): Remote
Remote = class()

Remote.protocol = "storage2-remote"
---@type table<string, boolean>
Remote.filterCommands = {}


---Initialise a new storage2 client
function Remote:init()
    self.processing = false
    ---@type string?
    self.modemName = nil

    self:findAndOpenModem()
end


---Deserialise a message received over the network
---@param message string
---@return MessageType?, table?
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

    local messageType = string.sub(message, 1, split - 1)
    local data = string.sub(message, split + 1)

    return MessageTypeInverted[messageType], textutils.unserialize(data)
end


---Serialise a message to be sent over the network
---@param messageType MessageType
---@param data? table
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
function Remote:findAndOpenModem()
    local modem = peripheral.find("modem")
    if not modem then
        logger:error("No modem found. Remote will not work.")
        return false
    end

    if not peripheral.hasType(modem, "modem") then
        return false
    end

    ---@cast modem ccTweaked.peripherals.Modem
    local modemName = peripheral.getName(modem)

    rednet.open(modemName)
    self.modemName = modemName

    return true
end


---Close the modem
---@return boolean
function Remote:closeModem()
    if not self.modemName then
        return false
    end

    rednet.close(self.modemName)
    self.modemName = nil

    return true
end


---Send data to a computer
---@param remoteId number
---@param message MessageType
---@return boolean
function Remote:sendData(remoteId, message)
    if not self.modemName then
        return false
    end

    local res = rednet.send(remoteId, message, self.protocol)
    if not res then
        logger:warn(">%d|Send failed: %s", remoteId, message)
    end

    return res
end


---Send a command to a computer
---@param remoteId number
---@param messageType MessageType
---@param data? table
---@return boolean
function Remote:sendCommand(remoteId, messageType, data)
    local message = self:serialiseMessage(messageType, data)
    if not message then
        return false
    end
    local res = self:sendData(remoteId, message)
    if res then
        logger:debug(">%d|Sent %s", remoteId, messageType)
    end

    return res
end


---Send command to a computer and wait for a response.
---Handles the ACKNOWLEDGE and then waits for a DONE message.
---@param remoteId number
---@param messageType MessageType
---@param data? table
---@return boolean, MessageType?, table?
function Remote:sendCommandWait(remoteId, messageType, data)
    if not self:sendCommand(remoteId, messageType, data) then
        return false, nil
    end

    local senderId, responseMessageType, responseData = self:receiveData(remoteId, 1)

    if not senderId then
        -- no response
        return false, nil
    end

    if responseMessageType ~= MessageType.ACK then
        return false, responseMessageType, responseData
    end

    --- we got an ACK, now wait for the actual response
    senderId, responseMessageType, responseData = self:receiveData(remoteId)

    if not senderId then
        -- no response
        return false, nil
    end

    if responseMessageType ~= MessageType.DONE then
        return false, responseMessageType, responseData
    end

    return true, responseMessageType, responseData
end


---Receive data from a computer
---@param expectedSender? number
---@param timeout? number
---@return number, MessageType?, table?
function Remote:receiveData(expectedSender, timeout)
    local senderId, message
    ---@type MessageType?
    local messageType, data

    if not self.modemName then
        goto nilReturn
    end

    self.processing = false

    ::receive::

    senderId, message = rednet.receive(self.protocol, timeout)

    self.processing = true

    if not senderId then
        goto nilReturn
    end

    if self.filterCommands[message] then
        goto nilReturn
    end

    if expectedSender and senderId ~= expectedSender then
        logger:debug("<%d|Expected: %d", senderId, expectedSender)
        goto receive
    end

    --- make sure the message is a string
    if type(message) ~= "string" then
        logger:warn("<%d|Non-string: %s", senderId, message)
        self:sendData(senderId, MessageType.ERR_INVALID_DATA_TYPE)
        goto nilReturn
    end
    ---@cast message string

    messageType, data = self:unserialiseMessage(message)

    if not messageType then
        logger:warn("<%d|Unknown message type: %s", senderId, message)
        self:sendData(senderId, MessageType.ERR_UNKNOWN_COMMAND)
        goto nilReturn
    end

    logger:debug("<%d|Valid: %s", messageType, senderId)

    if message ~= MessageType.ACK and not self:sendData(senderId, MessageType.ACK) then
        goto nilReturn
    end

    do
        return senderId, messageType, data
    end

    ::nilReturn::
    self.processing = false
    return senderId, nil
end
