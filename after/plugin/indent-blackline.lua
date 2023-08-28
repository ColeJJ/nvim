vim.opt.list = true

require("indent_blankline").setup {
    char = '┊',
    show_trailing_blankline_indent = false,
    show_current_context = true,
    show_current_context_start = true,
}

vim.keymap.set("n", "gs", function()
    local ok, start = require("indent_blankline.utils").get_current_context(
        vim.g.indent_blankline_context_patterns,
        vim.g.indent_blankline_use_treesitter_scope
    )
    if not ok then
        return
    end
    vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { start, 0 })
    vim.cmd [[normal! _]]
end)
