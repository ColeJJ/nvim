-- TJ Devries: `colorscheme gruvbuddy`
-- https://github.com/tjdevries/config.nvim → colorbuddy.nvim colors/gruvbuddy.lua
-- plus die Default-Gruppen aus colorbuddy/plugins/init.lua

local M = {}

local function ensure_colorbuddy()
  pcall(function()
    require("lazy").load({ plugins = { "colorbuddy.nvim" } })
  end)
end

function M.apply()
  ensure_colorbuddy()

  vim.cmd("hi clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end

  local colorbuddy = require("colorbuddy")
  -- Defaults zuerst; 'background' nur hier setzen, nicht danach
  -- (sonst setzt Neovim NonText/EndOfBuffer wieder auf Standard-Blau).
  colorbuddy.colorscheme("tj")

  local Color = colorbuddy.Color
  local Group = colorbuddy.Group
  local c = colorbuddy.colors
  local g = colorbuddy.groups
  local s = colorbuddy.styles

  Color.new("white", "#f2e5bc")
  Color.new("red", "#cc6666")
  Color.new("pink", "#fef601")
  Color.new("green", "#99cc99")
  Color.new("yellow", "#f8fe7a")
  Color.new("blue", "#81a2be")
  Color.new("aqua", "#8ec07c")
  Color.new("cyan", "#8abeb7")
  Color.new("purple", "#8e6fbd")
  Color.new("violet", "#b294bb")
  Color.new("orange", "#de935f")
  Color.new("brown", "#a3685a")
  Color.new("seagreen", "#698b69")
  Color.new("turquoise", "#698b69")

  local background_string = "#111111"
  Color.new("background", background_string)
  Color.new("gray0", background_string)

  Group.new("Normal", c.superwhite, c.gray0)
  Group.new("NormalNC", c.superwhite, c.gray0)
  Group.new("EndOfBuffer", c.gray0, c.gray0)
  Group.new("NonText", c.gray3, c.gray0)
  Group.new("MsgArea", c.superwhite, c.gray0)
  Group.new("WinBar", c.superwhite, c.gray0)
  Group.new("WinBarNC", c.gray3, c.gray0)
  Group.new("SignColumn", g.LineNr.fg, c.gray0)
  Group.new("LineNr", c.gray1, c.gray0)

  Group.new("@constant", c.orange, nil, s.none)
  Group.new("@function", c.yellow, nil, s.none)
  Group.new("@function.bracket", g.Normal, g.Normal)
  Group.new("@keyword", c.violet, nil, s.none)
  Group.new("@keyword.faded", g.nontext.fg:light(), nil, s.none)
  Group.new("@property", c.blue)
  Group.new("@variable", c.superwhite, nil)
  Group.new("@variable.builtin", c.purple:light():light(), g.Normal)
  Group.new("@function.call.lua", c.blue:dark(), nil, nil)

  vim.cmd([[
    hi link @function.call @function
    hi link @function.method @function
    hi link @function.method.call @function
    hi link @lsp.type.variable @variable
    hi link @lsp.type.property @property
    hi link @lsp.type.function @function
    hi link @lsp.type.method @function
    hi link @lsp.type.keyword @keyword
    hi link @lsp.type.namespace @module
  ]])

  vim.o.termguicolors = true
  vim.g.colors_name = "tj"

  local bg = background_string
  local fg = "#E0E0E0"
  vim.api.nvim_set_hl(0, "Normal", { fg = fg, bg = bg })
  vim.api.nvim_set_hl(0, "NormalNC", { fg = fg, bg = bg })
  vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = bg, bg = bg })
  vim.api.nvim_set_hl(0, "NonText", { fg = "#333333", bg = bg })
  vim.api.nvim_set_hl(0, "MsgArea", { fg = fg, bg = bg })
  vim.api.nvim_set_hl(0, "WinBar", { fg = fg, bg = bg })
  vim.api.nvim_set_hl(0, "WinBarNC", { fg = "#555555", bg = bg })
  vim.api.nvim_set_hl(0, "SignColumn", { fg = "#555555", bg = bg })
  vim.api.nvim_set_hl(0, "TabLine", { fg = "#5c5c5c", bg = bg })
  vim.api.nvim_set_hl(0, "TabLineSel", { fg = "#c8c8c8", bg = "#1c1c1c" })
  vim.api.nvim_set_hl(0, "TabLineFill", { fg = "#5c5c5c", bg = bg })

  vim.g.tj_lualine = {
    normal = {
      a = { fg = bg, bg = "#81a2be", gui = "bold" },
      b = { fg = fg, bg = "#2a2a2a" },
      c = { fg = "#888888", bg = bg },
    },
    insert = { a = { fg = bg, bg = "#f8fe7a", gui = "bold" } },
    visual = { a = { fg = bg, bg = "#8e6fbd", gui = "bold" } },
    replace = { a = { fg = bg, bg = "#cc6666", gui = "bold" } },
    command = { a = { fg = bg, bg = "#99cc99", gui = "bold" } },
    inactive = {
      a = { fg = "#555555", bg = "#1a1a1a" },
      b = { fg = "#555555", bg = "#1a1a1a" },
      c = { fg = "#555555", bg = bg },
    },
  }
end

return M
