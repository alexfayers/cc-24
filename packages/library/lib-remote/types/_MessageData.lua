---@alias MessageEndData table?

---@class MessageErrorData
---@field code MessageErrorCode
---@field message? string

---@class MessageCommandData
---@field type string
---@field data? table

---@alias MessageData MessageErrorData|MessageCommandData|MessageEndData
