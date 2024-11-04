-- Imports
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local helpers = require("storage2.lib.helpers")

local logger = require("lexicon-lib.lib-logging").getLogger("storage2.ItemDetailCache")

-- Class definition

---@class ItemDetailCache
---@overload fun(cachePath: string): ItemDetailCache
ItemDetailCache = class()

---Initialise a new ItemDetailCache
function ItemDetailCache:init(cachePath)
    self.cachePath = cachePath
    self.cache = self:loadCache()
end


---Load the cache from the cache file if it exists, otherwise return an empty table
---@return ItemDetailCacheTable
function ItemDetailCache:loadCache()
    return helpers.loadTable(self.cachePath) or {}
end


---Save the cache to the cache file
function ItemDetailCache:saveCache()
    helpers.saveTable(self.cachePath, self.cache)
end


---Checks the cache for the details of an item
---@param itemName string The name of the item
---@return itemDetailCacheItem|nil
function ItemDetailCache:getCachedItemDetails(itemName)
    return self.cache[itemName]
end


---Serialise the results of getItemDetail, ready to be cached
---@param itemDetail ChestGetItemDetailItem
---@return itemDetailCacheItem
function ItemDetailCache:serialiseItemDetail(itemDetail)
    return {
        displayName = itemDetail.displayName,
        itemGroups = itemDetail.itemGroups,
        maxCount = itemDetail.maxCount,
        name = itemDetail.name,
        tags = itemDetail.tags,
    }
end


---Lookup details of an item in a chest, checking the cache first
---@param chest ccTweaked.peripherals.Inventory The chest to check
---@param slot number The slot to check
---@param itemName? string The name of the item (used to check the cache)
---@return itemDetailCacheItem?
function ItemDetailCache:getItemDetail(chest, slot, itemName)
    if itemName then
        local cacheHit = self:getCachedItemDetails(itemName)
        if cacheHit then
            return cacheHit
        end
    end

    local itemDetail = helpers.chestGetItemDetailRetry(chest, slot)

    if not itemDetail then
        return nil
    end

    self.cache[itemDetail.name] = self:serialiseItemDetail(itemDetail)

    self:saveCache()

    return self.cache[itemDetail.name]
end