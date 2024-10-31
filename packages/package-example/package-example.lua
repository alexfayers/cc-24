-- Example package that uses lexicon-lib

local terminal = require("lexicon.terminal")

terminal.writeWrap("Hello from package-example!")
terminal.newline()
terminal.writeWrap("This package uses lexicon-lib.")
terminal.newline()
terminal.writeWrapColor("It can output in color too!", colors.lime)
terminal.newline()
