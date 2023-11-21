vim.g.neoformat_try_node_exe = 1
vim.g.neoformat_run_all_formatters = 1
vim.g.neoformat_try_formatprg = 1
-- vim.g.neoformat_verbose = 1 --for config purposes

-- enable for languages
vim.g.neoformat_enabled_javascript = {'prettier'}
vim.g.neoformat_enabled_php = {'prettier'}

-- autoformating when saving
vim.api.nvim_exec([[
  augroup fmt
    autocmd!
    autocmd BufWritePre * undojoin | Neoformat
  augroup END
]], false)
