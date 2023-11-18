vim.opt.guicursor = ""

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
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

vim.opt.colorcolumn = "80"

-- sets <space> as leader 
vim.g.mapleader = " "
-- sets <space> as localleader 
vim.g.maplocalleader = " "

vim.opt.colorcolumn = ""

vim.g.fillchars='eob: '

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

-- Automatically format the current line after leaving Insert mode
-- vim.cmd([[
-- augroup FormatOnLeave
--     autocmd!
--     autocmd InsertLeave * normal ==O
-- augroup END
-- ]])
