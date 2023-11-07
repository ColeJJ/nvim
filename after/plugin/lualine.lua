-- local auto_theme_custom = require('lualine.themes.auto')
-- auto_theme_custom.normal.c.bg = 'none'

require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'auto',
    -- theme = require('colejj.statusline_theme').theme(),
    component_separators = { left = '', right = ''},
    -- component_separators = { left = '│', right = '│'},
    -- section_separators = { left = '', right = ''},
    -- section_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = false,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
    }
  },

  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff'--[[ , 'diagnostics' ]]},
    lualine_c = {{'filename', file_status = true, path = 1}},
    lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},

    lualine_b = {},
    lualine_c = {'filename'},

    lualine_x = {'location'},
    lualine_y = {},

    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},

  extensions = {}
}

