vim.g.mapleader = " "

-- nerd tree
vim.keymap.set("n", "<leader>t", vim.cmd.Ex)

-- move lines above or down in v mode 
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- halfway jumping -> change keybindings
vim.keymap.set("n", "gj", "<C-d>zz")
vim.keymap.set("n", "gk", "<C-u>zz")

-- pasting without loosing the buffer
vim.keymap.set("x", "<leader>p", "\"_dP")
-- same with deleting
vim.keymap.set("n", "<leader>d", "\"_d")
vim.keymap.set("v", "<leader>d", "\"_d")

-- copy in vim and past in clipboard
vim.keymap.set("n", "<leader>y", "\"+y")
vim.keymap.set("v", "<leader>y", "\"+y")
vim.keymap.set("n", "<leader>Y", "\"+Y")

-- prevent from pressing capital Q
vim.keymap.set("n", "Q", "<nop>")

-- tmux project switching
vim.keymap.set('n', '<C-f>', '<cmd>silent !tmux neww ~/.config/tmux/tmux-sessionizer.sh<CR>')
vim.keymap.set('n', '<C-c>', '<cmd>silent !tmux neww ~/.config/tmux/tmux-cht.sh<CR>')

-- replacing the word you are currently on
vim.keymap.set("n", "<leader>r", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- WINDOWS
-- change windows 
vim.keymap.set('n', '<leader><Tab>', '<C-w>w')
-- nvim windwos resizing
vim.keymap.set('n', '<leader>h', '5<C-w><')
vim.keymap.set('n', '<leader>j', '5<C-w>-')
vim.keymap.set('n', '<leader>k', '5<C-w>+')
vim.keymap.set('n', '<leader>l', '5<C-w>>')

-- normal mode jumping of w and b for space and backspace
vim.keymap.set('n', '<BS>', 'b')

-- lazygit
vim.keymap.set('n', '<leader>gs', '<cmd>LazyGit<CR>')
