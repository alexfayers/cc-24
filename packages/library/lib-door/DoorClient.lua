---Simple remote for the door server
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")
require("lib-door.DoorRemote")
local lib = require("lib-door.lib")

local logger = require("lexicon-lib.lib-logging").getLogger("DoorClient")

---@class DoorClient: DoorRemote
---@overload fun(): DoorClient
DoorClient = DoorRemote:extend()


---Initialise a new door client
function DoorClient:init()
    DoorRemote:init()
end


---Validate the data received from the modem is correct, and return it
---@param data table
---@return boolean
function DoorClient:validateData(data)
    if data.result == nil then
        return false
    end

    return true
end


---Send a command to the door servers
---@param action string
function DoorClient:sendCommand(action)
    local serverPort = lib.getServerPort()
    local serverReplyChannel = math.random(1, 65534)
    if serverReplyChannel == serverPort then
        serverReplyChannel = serverReplyChannel + 1
    end

    self:send(serverPort, serverReplyChannel, {action = action})

    local responseData, _ = self:receive(serverReplyChannel, 5)

    if responseData == nil then
        return false
    end

    if not self:validateData(responseData) then
        return false
    end

    return responseData.result
end


---Open the door
---@return boolean
function DoorClient:open()
    return self:sendCommand("open")
end


---Close the door
---@return boolean
function DoorClient:close()
    return self:sendCommand("close")
end
