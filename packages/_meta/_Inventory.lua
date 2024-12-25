---@meta

require("Inventory")

---@class ItemEnchantment
---@field level number
---@field displayName string
---@field name string

---@alias ChestGetItemDetailItemItemGroups {displayName: string, id: string}[]
---@alias ChestGetItemDetailItemTags table<string, boolean>
---@alias ChestGetItemDetailItem {count: number, displayName: string, itemGroups: ChestGetItemDetailItemItemGroups, maxCount: number, name: string, tags: ChestGetItemDetailItemTags, enchantments: ItemEnchantment[]?} The details of an item in a chest

---@overload fun(slot: number): ChestGetItemDetailItem
function Inventory.getItemDetail(slot) end
