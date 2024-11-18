---A chest filter for the map
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

---@class ChestFilter
---@field public name string The name of the chest to apply the filter to. Can be a pattern.
---@field public itemNames string[]? The item names to filter by
---@field public itemTags string[]? The item tags to filter by
---@field public slotNumbers number[]? The slot numbers that this filter applies to (default is all slots in the inventory)


---@class ChestFilter
---@overload fun(name: string, itemNames: string[]?, itemTags: string[]?, slotNumbers: number[]?): ChestFilter
ChestFilter = class()


---@class SerializedChestFilter
---@field name string
---@field itemNames string[]?
---@field itemTags string[]?
---@field slotNumbers number[]?


---Initialise a new ChestFilter
---@param name string The name of the chest to apply the filter to. Can be a pattern.
---@param itemNames string[]? The item names to filter by
---@param itemTags string[]? The item tags to filter by
---@param slotNumbers number[]? The slot numbers that this filter applies to (default is all slots in the inventory)
function ChestFilter:init(name, itemNames, itemTags, slotNumbers)
    self.name = name
    self.itemNames = itemNames
    self.itemTags = itemTags
    self.slotNumbers = slotNumbers or nil
end


---Check if the filter applies to the given chest
---@param chestName string The name of the chest
---@return boolean
function ChestFilter:appliesTo(chestName)
    return string.match(chestName, self.name) ~= nil
end


---Check if a slot is allowed by the filter
---@param slot number The slot number
---@return boolean
function ChestFilter:acceptsSlot(slot)
    if self.slotNumbers == nil then
        return true
    end

    for _, v in ipairs(self.slotNumbers) do
        if v == slot then
            return true
        end
    end

    return false
end


---Check if an item name is allowed by the filter
---@param itemName string The name of the item
---@return boolean
function ChestFilter:acceptsName(itemName)
    if self.itemNames == nil then
        return true
    end

    for _, v in ipairs(self.itemNames) do
        if string.match(itemName, v) then
            return true
        end
    end

    return false
end


---Check if any tags allowed by the filter
---@param tags table<string, boolean> The tags of the item
---@return boolean
function ChestFilter:acceptsTags(tags)
    if self.itemTags == nil then
        return true
    end

    for _, v in ipairs(self.itemTags) do
        if tags[v] then
            return true
        end
    end

    return true
end


---Check if an item can be accepted by the filter
---@param itemName string The name of the item
---@param tags string[] The tags of the item
---@param slot number The slot number
---@return boolean
function ChestFilter:acceptsItem(itemName, tags, slot)
    if not self:acceptsSlot(slot) then
        return false
    end

    if not self:acceptsName(itemName) then
        return false
    end

    if not self:acceptsTags(tags) then
        return false
    end

    return true
end
