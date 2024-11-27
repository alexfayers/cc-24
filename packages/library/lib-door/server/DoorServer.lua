---Simple door server that runs on a turtle
---When the turtle receives a modem command, it will place/remove a block below/in front/above it
---The direction for breaking is set via a setting
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")
require("lib-door.DoorRemote")
local lib = require("lib-door.lib")

local logger = require("lexicon-lib.lib-logging").getLogger("DoorServer")

local DIRECTION_SETTING = "door.direction"
local NAME_SETTING = "door.name"

---Types

---@class DoorServerData
---@field action DoorDirection
---@field name string


---Class

---@class DoorServer: DoorRemote
---@overload fun(): DoorServer
DoorServer = DoorRemote:extend()

---Initialise a new door server
function DoorServer:init()
    DoorRemote.init(self)

    settings.define(DIRECTION_SETTING, {
        description = "The direction to break blocks in. Can be 'down', 'up', 'front'",
        type = "string",
        default = "down",
    })

    settings.define(NAME_SETTING, {
        description = "The name of the door",
        type = "string",
    })

    self.direction = self:getDirection()
    self.name = settings.get(NAME_SETTING) or error(NAME_SETTING .. " must be set", 0)
end


---Validate the direction
---@param direction string?
---@return boolean
function DoorServer:validateDirection(direction)
    return direction == "down" or direction == "up" or direction == "front"
end


---Validate an action
---@param action string?
---@return boolean
function DoorServer:validateAction(action)
    return action == "open" or action == "close"
end


---Get the door direction from the settings
---@return DoorDirection
function DoorServer:getDirection()
    local direction = settings.get(DIRECTION_SETTING)
    if self:validateDirection(direction) then
        return direction
    end

    error("Invalid direction. Must be 'down', 'up', or 'front'", 0)
end


---Validate the data received from the modem is correct, and return it
---@param data table
---@return boolean
function DoorServer:validateData(data)
    if not self:validateAction(data.action) then
        logger:error("Invalid action received: %s", data.action)
        return false
    end

    if not data.name then
        logger:error("No name received")
        return false
    end

    return true
end


---Return if the turtle is in the door group
---@param data table
---@return boolean
function DoorServer:isCorrectName(data)
    return data.name == self.name or data.name == "all"
end


---Handle a message from the modem
---@param replyChannel number
---@param data table
function DoorServer:handleMessage(replyChannel, data)

    if not self:validateData(data) then
        return
    end
    ---@cast data DoorServerData

    if not self:isCorrectName(data) then
        return
    end

    local result = false
    if data.action == "open" then
        result = self:openDoor()
    elseif data.action == "close" then
        result = self:closeDoor()
    else
        ---This should never be reached as the action is validated
        logger:error("Invalid action: %s", data.action)
    end

    if replyChannel == 0 then
        return
    end

    logger:info("Sending response: %s", result)

    self:send(replyChannel, 0, {
        result = result,
    })
end


---Open the door
---@return boolean
function DoorServer:openDoor()
    local direction = self.direction
    logger:info("Opening door in direction: %s", direction)

    if direction == "down" then
        return turtle.digDown()
    elseif direction == "up" then
        return turtle.digUp()
    elseif direction == "front" then
        return turtle.dig()
    end

    ---This should never be reached as the direction is validated
    return false
end


---Close the door
---@return boolean
function DoorServer:closeDoor()
    local direction = self.direction
    logger:info("Closing door in direction: %s", direction)

    if direction == "down" then
        return turtle.placeDown()
    elseif direction == "up" then
        return turtle.placeUp()
    elseif direction == "front" then
        return turtle.place()
    end

    ---This should never be reached as the direction is validated
    return false
end


---Listen for open commands on the modem
---@return boolean
function DoorServer:listen()
    local listenPort = lib.getServerPort()
    logger:info("%s listening on port %d...", lib.PROTOCOL_NAME, listenPort)

    while true do
        local data, replyChannel = self:receive(listenPort)

        if data == nil then
            -- not the right protocol or timeout
            goto continue
        end
        ---@cast replyChannel number

        self:handleMessage(replyChannel, data)

        ::continue::
    end
end
