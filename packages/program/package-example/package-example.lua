-- Example package that uses lexicon-lib
package.path = package.path .. ";/usr/lib/?.lua"

-- Terminal example
local terminal = require("lexicon-lib.lib-term")

terminal.writeWrap("Hello from package-example!")
terminal.newline()
terminal.writeWrap("This package uses lexicon-lib.")
terminal.newline()
terminal.writeWrapColor("It can output in color too!", colors.lime)
terminal.newline()

-- Logging example
local logging = require("lexicon-lib.lib-logging")
local logger = logging.getLogger("package-example")
logger:setLevel(logging.LEVELS.DEBUG)

logger:info("This is an info message")
logger:warn("This is a warning message")
logger:error("This is an error message")