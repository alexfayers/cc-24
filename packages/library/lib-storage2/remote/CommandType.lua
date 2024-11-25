---@enum CommandType
CommandType = {  ---@class _CommandTypes
    REFRESH = "REFRESH",
    DATA_IO_CHESTS = "DATA_IO_CHESTS",
    PING = "PING",
    PULL = "PULL",
    PUSH = "PUSH",
    ITEM_COUNT = "ITEM_COUNT",
}


---@alias RefreshData nil
---@alias IoChestData { inputChest: string, outputChest: string }
---@alias PongData { pong: true }
---@alias PullData { count: number }
---@alias PushData { count: number }
---@alias ItemCountData { count: number }
