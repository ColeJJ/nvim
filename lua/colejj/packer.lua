-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'

    -- FINDER
    use { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
    use {
        'junegunn/fzf.vim',
        requires = { { 'junegunn/fzf' } }
    }
    use {
        'imNel/monorepo.nvim',
        -- or                            , branch = '0.1.x',
        requires = { { 'nvim-lua/plenary.nvim' }, { 'nvim-telescope/telescope.nvim' } }
    }
    use { "nvim-telescope/telescope.nvim" }

    -- TMUX
    use { 'christoomey/vim-tmux-navigator' }
    use { 'camgraff/telescope-tmux.nvim' }

    -- THEMES & APPEARANCE
    use({
        'tjdevries/colorbuddy.vim',
        after = "nvim-treesitter",
        requires = "nvim-treesitter/nvim-treesitter",
    })
    use({
        'tjdevries/gruvbuddy.nvim',
        after = "nvim-treesitter",
        requires = "nvim-treesitter/nvim-treesitter",
    })
    use({
        'norcalli/nvim-colorizer.lua',
        after = "nvim-treesitter",
        requires = "nvim-treesitter/nvim-treesitter",
    })
    -- putting nvim cmd into central ui
    use { 'stevearc/dressing.nvim' }
    -- using web devicons
    use { 'nvim-tree/nvim-web-devicons' }

    -- EDITOR
    use {
        'nvim-treesitter/nvim-treesitter',
        run = ':TSUpdate'
    }
    use({
        "nvim-treesitter/nvim-treesitter-textobjects",
        after = "nvim-treesitter",
        requires = "nvim-treesitter/nvim-treesitter",
    })
    -- local windows switching
    use('theprimeagen/harpoon')
    -- local branches and changes
    use('mbbill/undotree')
    -- git
    use('tpope/vim-fugitive')
    use { 'ThePrimeagen/git-worktree.nvim' }
    use { 'kdheepak/lazygit.nvim' }
    -- autopairs
    use('jiangmiao/auto-pairs')
    -- prettier / formatting
    use { "stevearc/conform.nvim" }
    -- autopairs for html
    use('alvan/vim-closetag')
    -- commenting -> comment shortcuts
    use('numToStr/Comment.nvim')
    -- lualine for statusline style
    use { 'nvim-lualine/lualine.nvim' }
    -- merge conflicts
    use { 'akinsho/git-conflict.nvim', tag = "*" }
    -- tree
    use { 'nvim-tree/nvim-tree.lua' }

    -- LANGUAGES
    -- linting
    use { 'mfussenegger/nvim-lint' }
    -- lsp
    use {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v1.x',
        requires = {
            -- LSP Support
            { 'neovim/nvim-lspconfig' }, -- Required
            {                            -- Optional
                'williamboman/mason.nvim',
                run = function()
                    pcall(vim.cmd, 'MasonUpdate')
                end,
            },
            { 'williamboman/mason-lspconfig.nvim' }, -- Optional

            -- Autocompletion
            { 'hrsh7th/nvim-cmp' },         -- Required
            { 'hrsh7th/cmp-nvim-lsp' },     -- Required
            { 'hrsh7th/cmp-buffer' },       -- source for text in buffer
            { 'hrsh7th/cmp-path' },         -- source for file system paths
            { 'saadparwaiz1/cmp_luasnip' }, -- completion for snippets
            { 'hrsh7th/cmp-nvim-lua' },     -- Optional
            { 'hrsh7th/cmp-emoji' },        -- Emojis

            -- Icons for CMP
            { 'onsails/lspkind-nvim' }, -- Optional

            -- Snippets
            { 'L3MON4D3/LuaSnip',                 requires = { 'rafamadriz/friendly-snippets' } }, -- snippet engine
            { 'rafamadriz/friendly-snippets' },                                                    -- useful snippets
        },

        -- Debugger
        use "mfussenegger/nvim-dap",
        use 'rcarriga/cmp-dap',
        use "rcarriga/nvim-dap-ui",
        use "theHamsta/nvim-dap-virtual-text",
        use "nvim-telescope/telescope-dap.nvim",
        use {
            "mxsdev/nvim-dap-vscode-js",
            requires = { "mfussenegger/nvim-dap" }
        },

        -- vim be good
        use 'ThePrimeagen/vim-be-good',

        -- leetcode nvim
        use { 'mbledkowski/neuleetcode.vim' }
    }
end)
