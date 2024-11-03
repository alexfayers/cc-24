package.path = package.path .. ";/usr/lib/?.lua"
local logging = require("lexicon-lib.lib-logging")

local logger = logging.getLogger("storage2.helpers")

---Ensure a wrapped peripheral is an inventory
---@param wrappedPeripheral ccTweaked.peripherals.wrappedPeripheral
---@return ccTweaked.peripherals.Inventory?
local function ensureInventory(wrappedPeripheral)
    if not peripheral.getType(wrappedPeripheral) == "inventory" then
        logger:error("%s is not an inventory. Please use an inventory chest.", wrappedPeripheral)
        return
    end
    ---@type ccTweaked.peripherals.Inventory
    return wrappedPeripheral
end

return {
    ensureInventory = ensureInventory,
}
