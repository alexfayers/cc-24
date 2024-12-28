---@alias DoorDirection "down"|"up"|"front"
---@alias DoorAction "open"|"close"

local tableHelpers = require("lexicon-lib.lib-table")

local MIN_LISTEN_PORT = 1
local MAX_LISTEN_PORT = 65534
local MAGIC_NUMBER = 42

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
    local data = string.match(message, "^" .. string.gsub(PROTOCOL_NAME, "%-", "%%-") .. "|(.+)$")

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
    return PROTOCOL_NAME .. "|" .. textutils.serialise(data, {
        compact = true
    })
end



---@class ServerState
---@field previousPort number
---@field currentPort number

---Hash a string into a number between 1 and MAX_LISTEN_PORT
---@param str string
---@return number
local function hashString(str)
    local hash = 0

    for i = 1, #str do
        hash = (hash * 31) + string.byte(str, i)
    end

    return (hash % MAX_LISTEN_PORT) + MIN_LISTEN_PORT
end


---Save the current server state to a file
---@param state table
---@return boolean, string?
local function saveServerState(state)
    return tableHelpers.saveTable(".door/state", state)
end


---Load the current server state from a file
---@return ServerState?, string?
local function loadServerState()
    return tableHelpers.loadTable(".door/state")
end


---Calculate the next listening port for the servers
---@param previousPort number
---@param currentPort number
---@return number
local function calculateNextPort(previousPort, currentPort)
    ---This is basically a rolling code - the next port relies on the
    ---previous port and the current port
    ---The next port is the previous port + the current port - MAGIC_NUMBER
    ---The port must be between MIN_LISTEN_PORT and MAX_LISTEN_PORT, so the result is modded by MAX_LISTEN_PORT
    return (previousPort + currentPort - MAGIC_NUMBER) % MAX_LISTEN_PORT + MIN_LISTEN_PORT
end


---Generate and store the next port for the servers
---@param doorName string
---@return ServerState
local function updateServerPort(doorName)
    local state, _ = loadServerState()

    if not state then
        local initialPort = hashString(doorName)

        state = {
            previousPort = initialPort,
            currentPort = initialPort + 1,
        }
    end

    local nextPort = calculateNextPort(state.previousPort, state.currentPort)

    state.previousPort = state.currentPort
    state.currentPort = nextPort

    saveServerState(state)

    return state
end


---Generate the current port for the servers
---@param doorName string
---@return number
local function getServerPort(doorName)
    local state, _ = loadServerState()

    if not state then
        state = updateServerPort(doorName)
    end

    return state.currentPort
end




return {
    PROTOCOL_NAME = PROTOCOL_NAME,
    MIN_LISTEN_PORT = MIN_LISTEN_PORT,
    MAX_LISTEN_PORT = MAX_LISTEN_PORT,
    getWirelessModem = getWirelessModem,
    unserialiseMessage = unserialiseMessage,
    serialiseMessage = serialiseMessage,
    updateServerPort = updateServerPort,
    getServerPort = getServerPort,
}