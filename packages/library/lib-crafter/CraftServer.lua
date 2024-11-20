---Server for the autocrafter
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-remote.Server")
require("lib-crafter.CrafterCommandType")


-- Class definition

---@class CraftServer: Server
---@overload fun(): CraftServer
CraftServer = Server:extend()

CraftServer.protocol = "craft-remote"

function CraftServer:init()
    Server.init(self)

    self.commandHandlers = {
        [CrafterCommandType.GET_LOCAL_NAME] = self.getLocalName,
        [CrafterCommandType.CRAFT] = self.handleCraft,
    }
end


---Handle a modem name request
---@param clientId number
---@param data? table
---@return boolean, table
function CraftServer:getLocalName(clientId, data)
    local modem = peripheral.wrap(self.modemName)

    if not modem then
        return false, {error = "No modem found"}
    end

    local localName = modem.getNameLocal()

    if not localName then
        return false, {error = "No local name found"}
    end

    return true, { localName = localName }
end


---Handle a craft command
---@param clientId number
---@param data table
---@return boolean
function CraftServer:handleCraft(clientId, data)
    return turtle.craft(data.limit)
end
