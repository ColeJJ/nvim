vim.keymap.set("n", "<leader>gd", vim.cmd.Gdiffsplit);

-- add diff highlighting colors
vim.cmd([[hi DiffAdd guifg=NONE guibg=#0f7d2d]])
-- test
vim.cmd([[hi DiffDelete guifg=NONE guibg=#7d160f]])

-- conflict
require'git-conflict'.setup({})
