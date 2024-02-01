-- add diff highlighting colors
vim.cmd([[hi DiffAdd guifg=NONE guibg=#0f7d2d]])
vim.cmd([[hi DiffDelete guifg=NONE guibg=#7d160f]])

-- conflict
require'git-conflict'.setup({})

-- keybindings
vim.keymap.set('n', '<leader>gc', '<cmd>GitConflictListQf<CR>')
