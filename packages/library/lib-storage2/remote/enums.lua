---Message types

---@enum MessageType
MessageType = {  ---@class _MessageType
    ACK = "ACK",
    ERR_INVALID_DATA_TYPE = "ERR_INVALID_DATA_TYPE",
    ERR_UNKNOWN_COMMAND = "ERR_UNKNOWN_COMMAND",
    DONE = "DONE",
    ERR_UNKNOWN = "ERR_UNKNOWN",

    CMD_REFRESH = "CMD_REFRESH",
    CMD_DATA_IO_CHESTS = "CMD_DATA_IO_CHESTS",
    CMD_PING = "CMD_PING",
}


---Same as MessageType, but the values are the keys of MessageType and the keys are the values of MessageType
---@type table<string, MessageType>
MessageTypeInverted = {}
for k, v in pairs(MessageType) do
    MessageTypeInverted[v] = k
end


return {
    MessageType = MessageType,
    MessageTypeInverted = MessageTypeInverted,
}
