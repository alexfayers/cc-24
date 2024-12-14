---storage2 Server class
package.path = package.path .. ";/usr/lib/?.lua"
require("class-lua.class")

local chestHelpers = require("lib-storage2.chestHelpers")
require("lib-storage2.Map")
require("lib-remote.Server")
require("lib-storage2.remote.CommandType")

local logger = require("lexicon-lib.lib-logging").getLogger("StorageServer")


-- Class definition

---@class StorageServer: Server
---@overload fun(): StorageServer
StorageServer = Server:extend()

StorageServer.protocol = "storage2-remote"


---Initialise a new storage2 server
function StorageServer:init()
    Server.init(self)

    self.commandHandlers = {
        [CommandType.REFRESH] = self.handleRefresh,
        [CommandType.DATA_IO_CHESTS] = self.handleDataIoChests,
        [CommandType.PING] = self.handlePing,
        [CommandType.PULL] = self.handlePull,
        [CommandType.PUSH] = self.handlePush,
        [CommandType.ITEM_COUNT] = self.handleCount,
    }

    self.backgroundTasks = {
        function ()
            self:backgroundSave()
        end,
    }

    self:initPeripherals()

    self.lastRefresh = os.clock()
    self.needSave = false

    self.checkRefreshRate = 30
    self.checkSaveRate = 2
end


---Initialise the storage-related peripherals
---@return boolean
function StorageServer:initPeripherals()
    local inputChest = chestHelpers.getInputChest()
    if not inputChest then
        return false
    end
    self.inputChest = inputChest

    local outputChest = chestHelpers.getOutputChest()
    if not outputChest then
        return false
    end
    self.outputChest = outputChest

    local storageChests = chestHelpers.getStorageChests(inputChest, outputChest)
    if not storageChests then
        return false
    end
    self.storageChests = storageChests

    self.storageMap = Map(self.storageChests)

    return true
end


---Handle a refresh request from a client
---@param clientId number
---@param data? table
---@return boolean, RefreshData
function StorageServer:handleRefresh(clientId, data)
    if self.storageMap.populating then
        return true
    end

    self.storageMap:populate(true)

    self.lastRefresh = os.clock()

    self.needSave = true

    return true
end


---Check if the storage map needs to be refreshed
---@return boolean
function StorageServer:needsRefresh()
    return os.clock() - self.lastRefresh > self.checkRefreshRate
end


---Refresh the storage map if the last refresh was more than 10 seconds ago
---@return boolean
function StorageServer:refreshIfNeeded()
    if self:needsRefresh() then
        self:handleRefresh(0, nil)
    end

    return true
end


---Wait for refresh to finish
---@return boolean
function StorageServer:waitForRefresh()
    local waitedTime = 0
    while self.storageMap.populating do
        os.sleep(0.05)
        waitedTime = waitedTime + 0.05

        if waitedTime > 10 then
            logger:error("Waited too long for refresh to finish")
            return false
        end
    end

    return true
end


---Ensure the storage map is up to date
---@return boolean
function StorageServer:ensureUpToDate()
    self:refreshIfNeeded()
    self:waitForRefresh()

    return true
end


---Save the storage map if it needs saving
---@return boolean
function StorageServer:saveIfNeeded()
    if self.needSave then
        logger:warn("Saving storage map...")
        self.storageMap:save()
        self.needSave = false
    end

    return true
end


---Check if the storage map needs saving
---@return boolean
function StorageServer:backgroundSave()
    logger:info("Started background save process")
    while true do
        os.sleep(self.checkSaveRate)
        self:saveIfNeeded()
    end
end


---Handle an input/output chests request from a client
---@param clientId number
---@param data? table
---@return boolean, IoChestData?
function StorageServer:handleDataIoChests(clientId, data)
    local res = {
        inputChest = peripheral.getName(self.inputChest),
        outputChest = peripheral.getName(self.outputChest),
    }

    return true, res
end


---Handle an ping request from a client
---@param clientId number
---@param data? table
---@return boolean, PongData
function StorageServer:handlePing(clientId, data)
    return true, {pong = true}
end


---Handle a pull request from a client
---@param clientId number
---@param data? table
---@return boolean, PullData?
function StorageServer:handlePull(clientId, data)
    if not data then
        return false
    end

    if not data.invName or not data.item or not data.count then
        return false
    end

    local pullToChest = chestHelpers.wrapInventory(data.invName)

    if not pullToChest then
        return false
    end

    self:ensureUpToDate()

    local fuzzy = true
    if data.fuzzy ~= nil then
        fuzzy = data.fuzzy
    end

    local pulledCount = self.storageMap:pull(pullToChest, data.item, data.count, fuzzy, data.toSlot)

    if pulledCount > 0 then
        self.needSave = true
    end

    local res = {
        count = pulledCount,
    }

    return true, res
end


---Handle a push request from a client
---@param clientId number
---@param data? table
---@return boolean, PushData?
function StorageServer:handlePush(clientId, data)
    if not data then
        return false
    end

    if not data.invName then
        return false
    end

    local pushFromChest = chestHelpers.wrapInventory(data.invName)

    if not pushFromChest then
        return false
    end

    self:ensureUpToDate()

    local pushedCount = self.storageMap:push(pushFromChest, data.fromSlots)

    if pushedCount > 0 then
        self.needSave = true
    end

    local res = {
        count = pushedCount,
    }

    return true, res
end


---Handle a count request from a client
---@param clientId number
---@param data table
---@return boolean, ItemCountData?
function StorageServer:handleCount(clientId, data)
    if not data.item then
        return false
    end

    self:ensureUpToDate()

    local count = self.storageMap:getTotalItemCount(data.item, false)

    local res = {
        count = count,
    }

    return true, res
end