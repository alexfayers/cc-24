package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local lib = require("lib-door.lib")


---@class DoorRemote: Class
---@overload fun(): DoorRemote
DoorRemote = class()

---Initialise a new door remote
function DoorRemote:init()
    self.modem = lib.getWirelessModem()
end


---Close a modem port
---@param portNumber number
function DoorRemote:closeModem(portNumber)
    self.modem.close(portNumber)
end


---Open a modem port
---@param portNumber number
function DoorRemote:openModem(portNumber)
    if not self.modem.isOpen(portNumber) then
        self.modem.open(portNumber)
    end
end


---Send data on a channel
---@param channel number
---@param data table
function DoorRemote:send(channel, replyChannel, data)
    self.modem.transmit(channel, replyChannel, lib.serialiseMessage(data))
end


---Receive data on a channel - assuming the modem is open
---@param listenPort number
---@param timeout number?
---@return table?, number?
function DoorRemote:_receive(listenPort, timeout)
    local timer = nil

    if timeout ~= nil then
        timer = os.startTimer(timeout)
    end

    while true do
        local eventData = {os.pullEvent()}

        local event = eventData[1]

        if event == "timer" and timer ~= nil then
            local timerId = eventData[2]
            if timerId ~= timer then
                goto continue
            end
            return nil
        elseif event == "modem_message" then
            local _, _, senderChannel, replyChannel, message = table.unpack(eventData)

            if senderChannel ~= listenPort then
                goto continue
            end

            local data = lib.unserialiseMessage(message)
            if data then
                return data, replyChannel
            end
        end
        ::continue::
    end
end


---Receive data on a channel
---@param listenPort number
---@param timeout number?
---@return table?, number?
function DoorRemote:receive(listenPort, timeout)
    self:openModem(listenPort)

    local data, replyChannel = self:_receive(listenPort, timeout)

    self:closeModem(listenPort)

    return data, replyChannel
end


---Receive data on a channel until a timeout, and return all of the data
---@param listenPort number
---@param timeout number
---@return table<number, table, number>
function DoorRemote:receiveAll(listenPort, timeout)
    self:openModem(listenPort)

    local data = {}

    while true do
        local receivedData, replyChannel = self:_receive(listenPort, timeout)

        if receivedData == nil then
            break
        end

        table.insert(data, receivedData)
    end

    self:closeModem(listenPort)

    return data
end
