-- keymaps
local opts = { noremap = true, silent = true }
vim.keymap.set('n', '<leader>xx', '<Cmd>TroubleToggle<CR>', opts)
vim.keymap.set('n', '<leader>xw', '<Cmd>TroubleToggle workspace_diagnostics<CR>', opts)
vim.keymap.set('n', '<leader>xd', '<Cmd>TroubleToggle document_diagnostics<CR>', opts)
vim.keymap.set('n', '<leader>xf', '<Cmd>TroubleToggle quickfix<CR>', opts)
vim.keymap.set('n', '<leader>xl', '<Cmd>TroubleToggle loclist<CR>', opts)
