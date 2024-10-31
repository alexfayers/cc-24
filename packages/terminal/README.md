# Logging

Simple terminal interaction library for CC:T.

## Usage

```lua
local terminal = require("lexicon.terminal")

terminal.writeWrap("Hello, ")
terminal.writeWrapColor("world!", colors.red)
terminal.newLine()
```