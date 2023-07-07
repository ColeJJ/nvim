-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'

  -- file and folder finder
  use {
	  'nvim-telescope/telescope.nvim', tag = '0.1.1',
	  -- or                            , branch = '0.1.x',
	  requires = { {'nvim-lua/plenary.nvim'} }
  }
  use { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
  use {
      'junegunn/fzf.vim',
      requires = { {'junegunn/fzf'} }
  }
  use 'nvim-telescope/telescope-file-browser.nvim'
  use {
	  'imNel/monorepo.nvim',
	  -- or                            , branch = '0.1.x',
	  requires = { {'nvim-lua/plenary.nvim'}, {'nvim-telescope/telescope.nvim'}}
  }


  -- THEMES & EDITOR 
  -- Themes
  use { "catppuccin/nvim", name = "catppuccin" }
  use { "neanias/everforest-nvim" }
  use { 'shaunsingh/nord.nvim' }
  use { 'rose-pine/neovim', as = 'rose-pine' }
  -- File Icons 
  use { "nvim-tree/nvim-web-devicons" }
  -- Nvimtree (File Explorer)
  use { 'nvim-tree/nvim-tree.lua' }
  -- Which-key -> window with possible key bindings 
  use { 'folke/which-key.nvim' }
  use ('nvim-treesitter/nvim-treesitter', {run = ':TSUpdate'})
  -- local windows switching
  use ('theprimeagen/harpoon')
  -- local branches and changes
  use ('mbbill/undotree')
  -- git 
  use ('tpope/vim-fugitive')
  -- autopairs
  use ('jiangmiao/auto-pairs')
  -- autopairs for html
  use ('alvan/vim-closetag')
  -- commenting -> comment shortcuts
  use ('numToStr/Comment.nvim')
  -- prettier and null ls
  use('jose-elias-alvarez/null-ls.nvim')
  -- TODO: Remove?
  use('MunifTanjim/prettier.nvim')
  -- Trouble -> area showing all the errors and warnings in the file
  use { "folke/trouble.nvim" }
  -- lualine for statusline style
  use { 'nvim-lualine/lualine.nvim' }
  -- merge conflicts
  use { 'akinsho/git-conflict.nvim', tag = "*" }

  -- LANGUAGES
  -- lsp
  use {
    'VonHeikemen/lsp-zero.nvim',
    branch = 'v1.x',
    requires = {
      -- LSP Support
      {'neovim/nvim-lspconfig'},             -- Required
      {                                      -- Optional
        'williamboman/mason.nvim',
        run = function()
          pcall(vim.cmd, 'MasonUpdate')
        end,
      },
      {'williamboman/mason-lspconfig.nvim'}, -- Optional

      -- Autocompletion
      {'hrsh7th/nvim-cmp'},         -- Required
      {'hrsh7th/cmp-nvim-lsp'},     -- Required
      {'hrsh7th/cmp-buffer'},       -- Optional
      {'hrsh7th/cmp-path'},         -- Optional
      {'saadparwaiz1/cmp_luasnip'}, -- Optional
      {'hrsh7th/cmp-nvim-lua'},     -- Optional

      -- Snippets
      {'L3MON4D3/LuaSnip'},             -- Required
      {'rafamadriz/friendly-snippets'}, -- Optional
    }
  }

  -- go lang 
  use ('fatih/vim-go',{ run = ':GoUpdateBinaries' })

  -- java 
  use 'mfussenegger/nvim-jdtls'

  -- Debugger
  use "mfussenegger/nvim-dap"
  use 'rcarriga/cmp-dap'
  use "rcarriga/nvim-dap-ui"
  use "theHamsta/nvim-dap-virtual-text"
  use "nvim-telescope/telescope-dap.nvim"
  use {
    "leoluz/nvim-dap-go",
    requires = {{"mfussenegger/nvim-dap"}}
  }
  -- vim be good
  use 'ThePrimeagen/vim-be-good'
end)
