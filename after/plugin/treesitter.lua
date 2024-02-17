require'nvim-treesitter.configs'.setup {
  ensure_installed = { "typescript", "lua", "php"},
  sync_install = false,
  auto_install = true,
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },

  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = '<Space-TAB>',
      scope_incremental = '<CR-S>',
      node_incremental = '<TAB>',
      node_decremental = '<S-TAB>',
    },
  },

  textobjects = {
    select = {
      enable = true,
      lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
      keymaps = {
        -- You can use the capture groups defined in textobjects.scm
        ['aa'] = '@parameter.outer',
        ['ia'] = '@parameter.inner',
        ['af'] = '@function.outer',
        ['if'] = '@function.inner',
        ['ac'] = '@class.outer',
        ['ic'] = '@class.inner',
      },
    },
    move = {
      enable = true,
      set_jumps = true, -- whether to set jumps in the jumplist
      goto_next_start = {
        ['mf'] = '@function.outer',
        ['mc'] = '@class.outer',
      },
      goto_next_end = {
        ['mF'] = '@function.outer',
        ['mC'] = '@class.outer',
      },
      goto_previous_start = {
        ['Mf'] = '@function.outer',
        ['Mc'] = '@class.outer',
      },
      goto_previous_end = {
        ['MF'] = '@function.outer',
        ['MC'] = '@class.outer',
      },
    },
    swap = {
      enable = true,
      swap_next = {
        ['<leader>s'] = '@parameter.inner',
      },
      swap_previous = {
        ['<leader>S'] = '@parameter.inner',
      },
    },
  },
}
