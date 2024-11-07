---Message types

---@enum MessageType
MessageType = {  ---@class _MessageType
    ACK = "ACK",
    ERR_INVALID_DATA_TYPE = "ERR_INVALID_DATA_TYPE",
    ERR_UNKNOWN_COMMAND = "ERR_UNKNOWN_COMMAND",
    DONE = "DONE",
    ERR_UNKNOWN = "ERR_UNKNOWN",

    CMD_REFRESH = "CMD_REFRESH",
}


return {
    MessageType = MessageType,
}
