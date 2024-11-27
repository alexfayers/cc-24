---Simple remote for the door server
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")
require("lib-door.DoorRemote")
local lib = require("lib-door.lib")


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
---@param group string
---@param action string
---@return boolean, number?, number?
function DoorClient:sendCommand(group, action)
    local serverPort = lib.getServerPort()
    local serverReplyChannel = math.random(1, 65534)
    if serverReplyChannel == serverPort then
        serverReplyChannel = serverReplyChannel + 1
    end

    self:send(serverPort, serverReplyChannel, {
        group = group,
        action = action,
    })

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
---@param group string
---@return boolean, number?, number?
function DoorClient:open(group)
    return self:sendCommand(group, "open")
end


---Close the door
---@param group string
---@return boolean, number?, number?
function DoorClient:close(group)
    return self:sendCommand(group, "close")
end
