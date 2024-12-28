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
---@param name string
---@param action string
---@return boolean, number?, number?
function DoorClient:sendCommand(name, action)
    local serverPort = lib.getServerPort(name)
    local serverReplyChannel = math.random(lib.MIN_LISTEN_PORT, lib.MAX_LISTEN_PORT)
    if serverReplyChannel == serverPort then
        serverReplyChannel = serverReplyChannel + 1
    end

    self:send(serverPort, serverReplyChannel, {
        name = name,
        action = action,
        code = lib.getServerCode(name),
    })

    lib.updateServerCode(name)

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

    local success = totalComponents > 0 and successfulComponents == totalComponents

    return success, successfulComponents, totalComponents
end


---Open the door
---@param name string
---@return boolean, number?, number?
function DoorClient:open(name)
    return self:sendCommand(name, "open")
end


---Close the door
---@param name string
---@return boolean, number?, number?
function DoorClient:close(name)
    return self:sendCommand(name, "close")
end
