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
    DoorRemote.init(self)
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
---@return boolean, number?, number?
function DoorClient:sendCommand(action)
    local serverPort = lib.getServerPort()
    local serverReplyChannel = math.random(1, 65534)
    if serverReplyChannel == serverPort then
        serverReplyChannel = serverReplyChannel + 1
    end

    self:send(serverPort, serverReplyChannel, {action = action})

    local responses = self:receiveAll(serverReplyChannel, 0.1)

    if responses == nil then
        return false
    end

    local totalComponents = 0
    local successfulComponents = 0

    for _, responseData, _ in pairs(responses) do
        if not self:validateData(responseData) then
            goto continue
        end

        totalComponents = totalComponents + 1

        if responseData.result then
            successfulComponents = successfulComponents + 1
        end
        ::continue::
    end

    local success = successfulComponents == totalComponents

    return success, successfulComponents, totalComponents
end


---Open the door
---@return boolean, number?, number?
function DoorClient:open()
    return self:sendCommand("open")
end


---Close the door
---@return boolean, number?, number?
function DoorClient:close()
    return self:sendCommand("close")
end
