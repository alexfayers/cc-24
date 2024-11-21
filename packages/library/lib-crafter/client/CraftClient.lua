package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

require("lib-remote.Client")

require("lib-crafter.CrafterCommandType")


---@class CraftClient: Client
---@overload fun(): CraftClient
CraftClient = Client:extend()

CraftClient.protocol = "craft-remote"


---@class getModemNameResponse
---@field localName? string
---@field error? string

---Request the modem name of the server
---@return boolean, getModemNameResponse?
function CraftClient:getLocalName()
    return self:baseSendCommand(CrafterCommandType.GET_LOCAL_NAME)
end


---Send a craft request to the server
---@param limit number
---@return boolean, nil
function CraftClient:craft(limit)
    return self:baseSendCommand(CrafterCommandType.CRAFT, {
        limit = limit,
    })
end
