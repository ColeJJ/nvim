require('colorizer').setup()
local Color, c, Group, g, s= require("colorbuddy").setup()

-- colors
Color.new('white',     '#f2e5bc')
Color.new('superwhite', '#E0E0E0')
Color.new('red',       '#cc6666')
Color.new('pink',      '#fef601')
Color.new('green',     '#99cc99')
Color.new('yellow',    '#f8fe7a')
Color.new('blue',      '#81a2be')
Color.new('aqua',      '#8ec07c')
Color.new('cyan',      '#8abeb7')
Color.new('purple',    '#8e6fbd')
Color.new('violet',    '#b294bb')
Color.new('orange',    '#de935f')
Color.new('brown',     '#a3685a')
Color.new('seagreen',  '#698b69')
Color.new('turquoise', '#698b69')
Color.new("background", '#0F111A')
Color.new("superwhite", "#E0E0E0")
Color.new("softwhite", "#ebdbb2")
Color.new("teal", "#018080")

Group.new("WinSeparator", nil, nil)

-- Vim Editor
Group.new("Normal", c.superwhite, c.background)
Group.new("InvNormal", c.gray0, c.gray5)
Group.new("NormalFloat", g.normal.fg:light(), g.normal.bg:dark())
Group.new("FloatBorder", c.gray0:light(), g.NormalFloat)
Group.new("LineNr", c.gray3, c.background)
Group.new("EndOfBuffer", c.gray3)
Group.new("SignColumn", c.gray3, c.background)

-- Popup Menu
Group.new("PMenu", c.gray4, c.background)
Group.new("PMenuSel", c.gray0, c.yellow:light())
Group.new("PMenuSbar", c.none, c.gray0)
Group.new("PMenuThumb", c.none, c.gray4)

-- Tabline
Group.new("TabLineFill", c.softwhite, c.gray3, s.none)

-- Statusline Colors
Group.new("StatusLine", c.gray2, c.blue, nil)
Group.new("StatusLineNC", c.gray3, c.gray1:light())
Group.new("CommandMode", c.gray7, c.green, s.bold)
Group.new("NormalMode", c.gray7, c.red, s.bold)
Group.new("InsertMode", c.gray7, c.yellow, s.bold)
Group.new("ReplaceMode", c.gray7, c.yellow, s.bold + s.underline)
Group.new("TerminalMode", c.gray7, c.turquoise, s.bold)
Group.new("HelpDoc", c.gray7, c.turquoise, s.bold + s.italic)
Group.new("HelpIgnore", c.green, nil, s.bold + s.italic)
Group.new("Visual", nil, c.blue:dark(0.3))
Group.new("VisualMode", g.Visual, g.Visual)
Group.new("VisualLineMode", g.Visual, g.Visual)

-- Function
Group.new("functionCall", c.yellow, c.none, s.bold)
Group.new("Function", c.yellow, c.none, s.bold)

-- Special Characters
Group.new("Special", c.purple:light(), nil, s.bold)

-- Standard syntax
Group.new("Boolean", c.orange)
Group.new("Comment", c.gray3:light(), c.none, s.italic)
Group.new("Character", c.red)
Group.new("Conditional", c.red)
Group.new("Define", c.cyan)
Group.new("Error", c.red:light(), nil, s.bold)
Group.new("Number", c.red)
Group.new("Float", g.Number, g.Number, g.Number)
Group.new("Constant", c.orange, nil, s.bold)
Group.new("Identifier", c.red, nil, s.bold)
Group.new("Include", c.cyan)
Group.new("Keyword", c.violet)
Group.new("Operator", c.red:light():light())
Group.new("String", c.green)
Group.new("Structure", c.violet)
Group.new("Typedef", c.yellow)
Group.new("Type", c.violet, nil, s.italic)
Group.new("@variable", c.superwhite, nil)
Group.new("@variable.builtin", c.purple:light():light(), nil)

vim.cmd([[
    hi link @lsp.type.variable variable 
    hi link @function.call functionCall
    hi link @lsp.type.namespace @namespace
    hi link @punctuation.bracket.rapper @text.literal
    hi link @normal Normal
]])
