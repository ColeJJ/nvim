require'nvim-treesitter.configs'.setup {
  ensure_installed = { "typescript", "lua", "php" },
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
        ['nf'] = '@function.outer',
        ['nc'] = '@class.outer',
      },
      goto_next_end = {
        ['nF'] = '@function.outer',
        ['nC'] = '@class.outer',
      },
      goto_previous_start = {
        ['bf'] = '@function.outer',
        ['bc'] = '@class.outer',
      },
      goto_previous_end = {
        ['bF'] = '@function.outer',
        ['bC'] = '@class.outer',
      },
    },
    swap = {
      enable = true,
      swap_next = {
        ['<leader>a'] = '@parameter.inner',
      },
      swap_previous = {
        ['<leader>A'] = '@parameter.inner',
      },
    },
  },
}
