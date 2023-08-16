vim.keymap.set("n", "<leader>gs", vim.cmd.Git);
vim.keymap.set("n", "<leader>gv", vim.cmd.Gvsplit);
vim.keymap.set("n", "<leader>gd", vim.cmd.Gdiffsplit);
vim.keymap.set("n", "<leader>gl", ":Git log <CR>");
vim.keymap.set("n", "<leader>gb", ":Git blame <CR>");


-- add diff highlighting colors
vim.cmd([[hi DiffAdd guifg=NONE guibg=#0f7d2d]])
vim.cmd([[hi DiffDelete guifg=NONE guibg=#7d160f]])
