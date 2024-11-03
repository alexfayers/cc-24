---@meta

require("Inventory")

---@alias ChestGetItemDetailItemItemGroups {displayName: string, id: string}[]
---@alias ChestGetItemDetailItemTags table<string, boolean>
---@alias ChestGetItemDetailItem {count: number, displayName: string, itemGroups: ChestGetItemDetailItemItemGroups, maxCount: number, name: string, tags: ChestGetItemDetailItemTags} The details of an item in a chest

---@overload fun(slot: number): ChestGetItemDetailItem
function Inventory.getItemDetail(slot) end
