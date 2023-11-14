local cmp = require('cmp')

-- load snippets
require("luasnip.loaders.from_vscode").lazy_load()
require('luasnip').filetype_extend("html", {"angular"})
require('luasnip').filetype_extend("ts", {"angular"})
local lspkind = require('lspkind')

cmp.setup({
    -- enabled = function()
    --     return vim.api.nvim_buf_get_option(0, "buftype") ~= "prompt"
    --     or require("cmp_dap").is_dap_buffer()
    -- end,
    completion = {
        completeopt = "menu,menuone,preview,noselect,noinsert",
    },
    snippet = {
        expand = function(args)
            require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
        end,
    },
    window = {
        completion = {
            border = "rounded",
        },
        documentation = {
            border = "rounded",
        }
    },
    sources = cmp.config.sources({
        { name = 'nvim_lsp' },
        { name = 'luasnip' }, -- For luasnip users.
        { name = 'buffer' },
        { name = 'path' },
        { name = 'emoji' },
    }),
    formatting = {
        format = lspkind.cmp_format({
            mode = "symbol_text",
            menu = ({
                buffer = "[Buffer]",
                nvim_lsp = "[LSP]",
                luasnip = "[LuaSnip]",
                nvim_lua = "[Lua]",
                latex_symbols = "[Latex]",
            })
        })
    }
})
