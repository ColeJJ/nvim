require('neorg').setup {
    load = {
        ["core.defaults"] = {}, -- load default behaviour
        ["core.integrations.telescope"] = {}, -- fuzzy find headers, links etc.
        ["core.highlights"] = {},
        ["core.mode"] = {}, -- indent lines with << or >> 
        ["core.integrations.treesitter"] = {},
        ["core.dirman"] = { -- sets workspaces
            config = {
                workspaces = {
                    codebase = "~/ghq/github.com/ColeJJ/codebase",
                },
                default_workspace = "codebase"
            }
        },
        ["core.concealer"] = {
            config = {
                icon_preset = "diamond",
                markup_preset = "dimmed",
                dim_code_blocks = {
                    enabled = true,
                },
                code_block = {
                    conceal = true
                }
            },
        }, -- loads nice icons and visuals
        ["core.syntax"] = {}, -- fallback if treesitter is not working
        ["core.completion"] = { -- autocompletion for neorg
            config = {
                engine = "nvim-cmp"
            }
        },
        ["core.promo"] = {}, -- indent lines with << or >> 
    }
}

-- keybindings
vim.keymap.set('n', '<leader>nw', ":Neorg index <CR>", { desc = 'Go to default [W]orkspace index.norg' })
vim.keymap.set('n', '<leader>nr', ":Neorg return <CR>", { desc = '[R]eturns to code' })
