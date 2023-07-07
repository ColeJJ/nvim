local status, bufferline = pcall(require, "bufferline")
if (not status) then return end

bufferline.setup({
  options = {
    mode = "tabs",
    separator_style = 'slant',
    numbers = 'ordinal',
    diagnostics = "nvim_lsp",
    always_show_bufferline = false,
    show_buffer_close_icons = false,
    show_close_icon = false,
    color_icons = true
  },
  highlights = {
    separator = {
      fg = '#073642',
      bg = '#002b36',
    },
    separator_selected = {
      fg = '#073642',
    },
    background = {
      fg = '#657b83',
      bg = '#002b36'
    },
    buffer_selected = {
      fg = '#fdf6e3',
      bold = true,
    },
    fill = {
      bg = '#073642'
    }
  },
})

local opts = { noremap = true, silent = true }
vim.keymap.set('n', '<Tab>', '<Cmd>BufferLineCycleNext<CR>', opts)
vim.keymap.set('n', '<S-Tab>', '<Cmd>BufferLineCyclePrev<CR>', opts)
vim.keymap.set('n', '<space>1', '<Cmd>BufferLineGoToBuffer 1<CR>', opts)
vim.keymap.set('n', '<space>2', '<Cmd>BufferLineGoToBuffer 2<CR>', opts)
vim.keymap.set('n', '<space>3', '<Cmd>BufferLineGoToBuffer 3<CR>', opts)
vim.keymap.set('n', '<space>4', '<Cmd>BufferLineGoToBuffer 4<CR>', opts)
vim.keymap.set('n', '<space>5', '<Cmd>BufferLineGoToBuffer 5<CR>', opts)
vim.keymap.set('n', '<space>r', '<Cmd>tabmove +1<CR>', opts)
vim.keymap.set('n', '<space>l', '<Cmd>tabmove -1<CR>', opts)
vim.keymap.set('n', '<space>n', '<Cmd>tabnew<CR>', opts)
vim.keymap.set('n', '<space>x', '<Cmd>bdelete<CR>', opts)
vim.keymap.set('n', '<space>be', '<Cmd>BufferLineSortByExtension<CR>', opts)
vim.keymap.set('n', '<space>bd', '<Cmd>BufferLineSortByDirectory<CR>', opts)
vim.keymap.set('n', '<space>bt', '<Cmd>BufferLineSortByTabs<CR>', opts)
