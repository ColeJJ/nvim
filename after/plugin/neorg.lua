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
        ["core.autocommands"] = {},
        ["core.concealer"] = {
            config = {
                icon_preset = "diamond",
            }
        }, -- loads nice icons and visuals
        ["core.completion"] = { -- autocompletion for neorg
            config = {
                engine = "nvim-cmp"
            }
        },
        ["core.summary"] = {}
    }
}

-- keybindings
vim.keymap.set('n', '<leader>nw', ":Neorg index <CR>", { desc = 'Go to default [W]orkspace index.norg' })
vim.keymap.set('n', '<leader>nr', ":Neorg return <CR>", { desc = '[R]eturns to code' })
