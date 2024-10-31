-- Example package that uses lexicon-lib
package.path = package.path .. ";/usr/lib/?.lua"

local terminal = require("lexicon-lib.lib-term.lib-term")

terminal.writeWrap("Hello from package-example!")
terminal.newline()
terminal.writeWrap("This package uses lexicon-lib.")
terminal.newline()
terminal.writeWrapColor("It can output in color too!", colors.lime)
terminal.newline()

local logging = require("lexicon-lib.lib-logging")
