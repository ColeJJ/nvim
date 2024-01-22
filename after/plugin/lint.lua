-- install the linter via mason
require('lint').linters_by_ft = {
    javascript = { 'eslint_d' },
    typescript = { 'eslint_d' },
}

-- autorun linters
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
    callback = function()
        require("lint").try_lint()
    end,
})
