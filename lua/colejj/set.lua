vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Neovim 0.12: Plugins (nvim-dap, nvim-jdtls, colorizer, …) rufen noch
-- vim.tbl_flatten auf. Ohne Shim erscheint die Deprecation-Warnung beim Start.
if vim.fn.has("nvim-0.12") == 1 then
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.tbl_flatten = function(t)
    return vim.iter(t):flatten(math.huge):totable()
  end
end

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
vim.opt.colorcolumn = ""
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.updatetime = 250
vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.smartindent = true

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "java", "kotlin" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.shiftwidth = 2
  end,
})

vim.g.html_indent_style1 = "auto"
vim.g.html_indent_script1 = "auto"

vim.g.leetcode_browser = "chrome"
vim.g.leetcode_solution_filetype = "typescript"

local version = vim.version()
if version.major == 0 and version.minor == 11 and version.patch < 5 then
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      vim.notify(
        ("nvim-java braucht Neovim 0.11.5+, gefunden %s. Bitte aktualisieren."):format(tostring(vim.version())),
        vim.log.levels.WARN,
        { title = "colejj" }
      )
    end,
  })
end
