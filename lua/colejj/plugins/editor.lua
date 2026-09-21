return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter-textobjects", branch = "master" },
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "typescript",
          "javascript",
          "lua",
          "php",
          "java",
          "kotlin",
          "yaml",
          "xml",
          "properties",
          "json",
          "sql",
        },
        sync_install = false,
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<Space-TAB>",
            scope_incremental = "<CR-S>",
            node_incremental = "<TAB>",
            node_decremental = "<S-TAB>",
          },
        },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["aa"] = "@parameter.outer",
              ["ia"] = "@parameter.inner",
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = {
              ["mf"] = "@function.outer",
              ["mc"] = "@class.outer",
            },
            goto_next_end = {
              ["mF"] = "@function.outer",
              ["mC"] = "@class.outer",
            },
            goto_previous_start = {
              ["Mf"] = "@function.outer",
              ["Mc"] = "@class.outer",
            },
            goto_previous_end = {
              ["MF"] = "@function.outer",
              ["MC"] = "@class.outer",
            },
          },
          swap = {
            enable = true,
            swap_next = {
              ["<leader>c>"] = "@parameter.inner",
            },
            swap_previous = {
              ["<leader>c<"] = "@parameter.inner",
            },
          },
        },
      })
      require("colejj.treesitter_compat").setup()
    end,
  },
  {
    "theprimeagen/harpoon",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local mark = require("harpoon.mark")
      local ui = require("harpoon.ui")
      require("harpoon").setup({
        menu = {
          width = vim.api.nvim_win_get_width(0) - 4,
        },
        tabline = true,
        tabline_prefix = " ",
        tabline_suffix = " ",
      })
      require("colejj.harpoon_tabline").setup()
      vim.keymap.set("n", "<leader>ha", mark.add_file, { desc = "Harpoon: Datei merken" })
      vim.keymap.set("n", "<leader>he", ui.toggle_quick_menu, { desc = "Harpoon: Menü" })
      for i = 1, 6 do
        vim.keymap.set("n", "<leader>h" .. i, function()
          ui.nav_file(i)
        end, { desc = "Harpoon: Datei " .. i })
      end
    end,
  },
  {
    "mbbill/undotree",
    keys = {
      { "<leader>u", "<cmd>UndotreeToggle<CR>", desc = "Undotree" },
    },
  },
  { "jiangmiao/auto-pairs" },
  { "alvan/vim-closetag" },
  {
    "numToStr/Comment.nvim",
    opts = {
      padding = true,
      sticky = true,
      toggler = { line = "cc", block = "cb" },
      opleader = { line = "cc", block = "cb" },
    },
  },
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local conform = require("conform")
      conform.setup({
        formatters_by_ft = {
          lua = { "stylua" },
          javascript = { "prettier" },
          typescript = { "prettier" },
          html = { "prettier" },
          css = { "prettier" },
          xml = { lsp_format = "prefer" },
          markdown = { "prettier" },
          java = { lsp_format = "prefer" },
          kotlin = { "ktlint", lsp_format = "fallback" },
        },
        formatters = {
          prettier = {
            prepend_args = function(_, ctx)
              local width = (ctx.filename or ""):match("%.md$") and "120" or "100"
              return { "--tab-width", "2", "--print-width", width }
            end,
          },
        },
      })
      vim.keymap.set({ "n", "v" }, "<leader>cf", function()
        conform.format({
          lsp_fallback = true,
          async = false,
          timeout_ms = 5000,
        })
      end, { desc = "Format (IntelliJ-Profil)" })
    end,
  },
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("lint").linters_by_ft = {
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
      }
    end,
  },
  { "ThePrimeagen/vim-be-good", cmd = "VimBeGood" },
}
