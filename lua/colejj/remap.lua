vim.g.mapleader = " "

-- move lines above or down in v mode 
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '>-2<CR>gv=gv")

-- halfway jumping -> change keybindings
vim.keymap.set("n", "gj", "<C-d>zz")
vim.keymap.set("n", "gk", "<C-u>zz")

-- pasting without loosing the buffer
vim.keymap.set("x", "<leader>p", "\"_dP")

-- prevent from pressing capital Q
vim.keymap.set("n", "Q", "<nop>")

-- change windows 
vim.keymap.set('n', '<leader><Tab>', '<C-w>w')
