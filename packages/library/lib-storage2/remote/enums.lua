---Message types

---@enum MessageType
MessageType = {  ---@class _MessageType
    ACKNOWLEDGE = "ACK",
    BUSY = "BUSY",
    INVALID_DATA_TYPE = "INVALID_DATA_TYPE",
    UNKNOWN_COMMAND = "UNKNOWN_COMMAND",
    DONE = "DONE",

    UNKNOWN_ERROR = "UNKNOWN_ERROR",

    COMMAND_REFRESH = "COMMAND_REFRESH",
}
