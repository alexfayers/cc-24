---@alias DoorDirection "down"|"up"|"front"
---@alias DoorAction "open"|"close"

local PROTOCOL_NAME = "door-server"


---Find and wrap a wireless modem on the computer
---@return ccTweaked.peripherals.Modem
local function getWirelessModem()
    local modem = peripheral.find("modem", function (name, wrapped)
        return wrapped.isWireless()
    end)

    if not modem then
        error("No modem attached", 0)
    end

    ---@type ccTweaked.peripherals.Modem
    return modem
end


---Unserialise a message from the modem
---@param message string
---@return table?
local function unserialiseMessage(message)
    -- Messages are in the format `protocol|serialised_data`
    local data = string.match(message, "^" .. PROTOCOL_NAME .. "|(.+)$")

    if not data then
        return
    end

    data = textutils.unserialise(data)

    if not data then
        return
    end

    return data
end


---Serialise a message to send to the modem
---@param data table
---@return string
local function serialiseMessage(data)
    return PROTOCOL_NAME .. "|" .. textutils.serialise(data)
end


---Generate the current port for the servers
---@return number
local function getServerPort()
    -- TODO: make this non-static!
    return 1337
end




return {
    PROTOCOL_NAME = PROTOCOL_NAME,
    getWirelessModem = getWirelessModem,
    unserialiseMessage = unserialiseMessage,
    serialiseMessage = serialiseMessage,
    getServerPort = getServerPort,
}