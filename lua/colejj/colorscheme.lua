require("colorizer").setup()
require('colorbuddy').setup()
require('colejj.colors')

local c = require('colorbuddy.init').colors
local Group = require('colorbuddy.init').Group
local g = require('colorbuddy.init').groups
local s = require('colorbuddy.init').styles

Group.new("StatuslineError1", c.red:light():light(), g.Statusline)
Group.new("StatuslineError2", c.red:light(), g.Statusline)
Group.new("StatuslineError3", c.red, g.Statusline)
Group.new("StatuslineError3", c.red:dark(), g.Statusline)
Group.new("StatuslineError3", c.red:dark():dark(), g.Statusline)

Group.new("pythonTSType", c.superwhite)
Group.new("goTSType", g.Type.fg:dark(), nil, g.Type)
Group.new("typescriptTSConstructor", g.pythonTSType)
Group.new("typescriptTSProperty", c.blue)
Group.new("TSTitle", c.blue)

Group.new("WinSeparator", nil, nil)

Group.new("LspParameter", nil, nil, s.italic)
Group.new("LspDeprecated", nil, nil, s.strikethrough)
Group.new("@function.bracket", g.Normal, g.Normal)
Group.new("@variable", c.superwhite, g.Normal)
Group.new("@variable.builtin", c.purple:light():light(), g.Normal)

Group.new("VirtNonText", c.gray3:dark(), nil, s.italic)

Group.new("TreesitterContext", nil, g.Normal.bg:light())
Group.new("TreesitterContextLineNumber", c.blue)

Group.new("@property", c.blue)
Group.new("@punctuation.bracket.rapper", c.gray3, nil, s.none)
Group.new("@rapper_argument", c.superwhite, nil, s.italic)
Group.new("@rapper_return", c.orange:light(), nil, s.italic)
Group.new("@constructor.ocaml", c.orange:light(), nil, s.none)
Group.new("constant", c.orange, nil, s.none)

Group.new("@keyword", c.violet, nil, s.none)
Group.new("@keyword.faded", g.nontext.fg:light(), nil, s.none)

Group.new("Function", c.yellow, nil, s.none)

vim.cmd [[
  hi link @lsp.type.variable variable
]]

Group.new("Normal", nil, c.background2)
