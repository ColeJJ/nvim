-- disable nerdtree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.scrolloff = 8

-- sets <space> as leader 
vim.g.mapleader = " "
-- sets <space> as localleader 
vim.g.maplocalleader = " "

vim.opt.colorcolumn = ""

-- need this column left to prevent window resizing all the time
vim.opt.signcolumn = "yes"

-- highlights
vim.opt.termguicolors = true
vim.opt.cursorline = true

-- FORMATTING
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.smartindent = true

-- Format: HTML
vim.g.html_indent_style1 = "auto"
vim.g.html_indent_script1 = "auto"
