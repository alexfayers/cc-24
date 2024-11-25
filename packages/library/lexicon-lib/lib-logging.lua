-- Logging for Lexicon
--
-- Usage:
-- local logging = require("lexicon-lib.lib-logging")
-- local logger = logging.getLogger("my-logger")
-- logger:info("Hello, world!")

local terminal = require("lexicon-lib.lib-term")

local newline = terminal.newline
local writeWrap = terminal.writeWrap
local writeWrapColor = terminal.writeWrapColor

-- Constants

local LEVELS = {
    DEBUG = 10,
    INFO = 20,
    WARN = 30,
    SUCCESS = 40,
    ERROR = 50,
    FATAL = 60
}

local LEVEL_NAMES = {
    [LEVELS.DEBUG] = "D",
    [LEVELS.INFO] = "I",
    [LEVELS.WARN] = "W",
    [LEVELS.SUCCESS] = "S",
    [LEVELS.ERROR] = "E",
    [LEVELS.FATAL] = "F"
}

local LEVEL_COLORS = {
    [LEVELS.DEBUG] = colors.lightBlue,
    [LEVELS.INFO] = colors.white,
    [LEVELS.WARN] = colors.yellow,
    [LEVELS.SUCCESS] = colors.lime,
    [LEVELS.ERROR] = colors.red,
    [LEVELS.FATAL] = colors.orange
}

local LOGGERS = {}

---@class Logger
local Logger = {
    _name = nil,
    _level = nil,
    _file = false,

    ---Create a new logger and register it with the logging system
    ---@param self any
    ---@param name string The name of the logger
    ---@return table
    new = function(self, name)
        settings.define("logger." .. name, {
            description = "The log level for the " .. name .. " logger",
            type = "number",
            default = LEVELS.INFO
        })

        settings.define("logger." .. name .. ".file", {
            description = "If the " .. name .. " logger should log to a file",
            type = "boolean",
            default = false
        })

        local level = settings.get("logger." .. name)
        local fileLog = settings.get("logger." .. name .. ".file")

        local logger = {
            _name = name,
            _level = level,
            _file = fileLog,
        }

        --ensure the log dir exists
        if fileLog and not fs.exists("/logs") then
            fs.makeDir("/logs")
        end

        setmetatable(logger, { __index = self })

        return logger
    end,

    ---Set the log level for the logger
    ---@param self any
    ---@param level integer The log level to set
    setLevel = function(self, level)
        if level < LEVELS.DEBUG or level > LEVELS.FATAL then
            error("Invalid log level")
        end

        self._level = level
    end,

    ---Log a line to the filesystem
    ---@param self any
    ---@param text string
    ---@return nil
    logToFile = function(self, text)
        if not self._file then
            return
        end
        local file = fs.open("/logs/" .. self._name .. ".log", "a")
        if not file then
            error("Failed to open log file (" .. self._name .. ")")
        end
        file.writeLine(text)
        file.close()
    end,

    ---Log a message
    ---@param self any
    ---@param level integer The log level
    ---@param message string The message to log
    ---@param ... any Additional arguments to log (used to format the message)
    ---@return nil
    log = function(self, level, message, ...)
        if level < self._level then
            return
        end

        local level_color = LEVEL_COLORS[level]
        local level_name = LEVEL_NAMES[level]

        local formatted = string.format(message, ...)
        writeWrap(string.format("[%s] ", os.date("%H:%M:%S")))
        writeWrapColor(level_name, level_color)
        writeWrap(": ")
        writeWrapColor(formatted, level_color)

        self:logToFile(string.format("[%s] %s: %s", os.date("%H:%M:%S"), level_name, formatted))

        newline()
    end,

    ---Log a debug message
    ---@param self any
    ---@param message string The message to log
    ---@param ... any Additional arguments to log (used to format the message)
    ---@return nil
    debug = function(self, message, ...)
        self:log(LEVELS.DEBUG, message, ...)
    end,

    ---Log an info message
    ---@param self any
    ---@param message string The message to log
    ---@param ... any Additional arguments to log (used to format the message)
    ---@return nil
    info = function(self, message, ...)
        self:log(LEVELS.INFO, message, ...)
    end,

    ---Log a warning message
    ---@param self any
    ---@param message string The message to log
    ---@param ... any Additional arguments to log (used to format the message)
    ---@return nil
    warn = function(self, message, ...)
        self:log(LEVELS.WARN, message, ...)
    end,

    ---Log a success message
    ---@param self any
    ---@param message string The message to log
    ---@param ... any Additional arguments to log (used to format the message)
    ---@return nil
    success = function(self, message, ...)
        self:log(LEVELS.SUCCESS, message, ...)
    end,

    ---Log an error message
    ---@param self any
    ---@param message string The message to log
    ---@param ... any Additional arguments to log (used to format the message)
    ---@return nil
    error = function(self, message, ...)
        self:log(LEVELS.ERROR, message, ...)
    end,

    ---Log a fatal message
    ---@param self any
    ---@param message string The message to log
    ---@param ... any Additional arguments to log (used to format the message)
    ---@return nil
    fatal = function(self, message, ...)
        self:log(LEVELS.FATAL, message, ...)
    end
}

---Get a logger by name
---@param name string The name of the logger
---@return Logger
local function getLogger(name)
    if LOGGERS[name] then
        return LOGGERS[name]
    end

    local logger = Logger:new(name)
    LOGGERS[name] = logger

    return logger
end

return {
    getLogger = getLogger,
    LEVELS = LEVELS
}
