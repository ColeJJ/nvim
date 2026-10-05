return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
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
          "markdown",
          "markdown_inline",
          "bash",
          "python",
          "html",
          "css",
          "toml",
          "diff",
        },
        sync_install = false,
        auto_install = false,
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
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {
      -- Gerendert bleibt auch im Insert-Modus. Roh-Markdown nur auf der
      -- aktuellen Zeile, und nur solange man tippt.
      render_modes = { "n", "i", "c", "t", "v", "V", "\22" },
      anti_conceal = {
        enabled = true,
        disabled_modes = { "n", "v", "V", "\22" },
        above = 0,
        below = 0,
      },
      win_options = {
        concealcursor = {
          rendered = "nvc",
        },
      },
      completions = {
        lsp = { enabled = true },
      },
      code = {
        sign = false,
        width = "block",
        language_pad = 1,
      },
      checkbox = {
        unchecked = {
          icon = "[ ] ",
          highlight = "DiagnosticInfo",
        },
        checked = {
          icon = "[x] ",
          highlight = "DiagnosticOk",
        },
        custom = {
          blocked = {
            raw = "[B]",
            rendered = "[B] ",
            highlight = "DiagnosticWarn",
          },
          important = {
            raw = "[!]",
            rendered = "[!] ",
            highlight = "MarkdownCheckboxImportant",
          },
        },
      },
    },
    config = function(_, opts)
      local function plain_important()
        local hl = vim.api.nvim_get_hl(0, { name = "DiagnosticError", link = false })
        vim.api.nvim_set_hl(0, "MarkdownCheckboxImportant", {
          fg = hl.fg,
          nocombine = true,
        })
      end
      plain_important()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("colejj_markdown_checkbox", { clear = true }),
        callback = plain_important,
      })
      require("render-markdown").setup(opts)
    end,
  },
  {
    "theprimeagen/harpoon",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = (function()
      local keys = {
        {
          "<leader>ha",
          function()
            require("harpoon.mark").add_file()
          end,
          desc = "Harpoon: Datei merken",
        },
        {
          "<leader>he",
          function()
            require("harpoon.ui").toggle_quick_menu()
          end,
          desc = "Harpoon: Menü",
        },
      }
      for i = 1, 6 do
        local n = i
        keys[#keys + 1] = {
          "<leader>h" .. n,
          function()
            require("harpoon.ui").nav_file(n)
          end,
          desc = "Harpoon: Datei " .. n,
        }
      end
      return keys
    end)(),
    config = function()
      require("harpoon").setup({
        menu = {
          width = vim.api.nvim_win_get_width(0) - 4,
        },
        tabline = true,
        tabline_prefix = " ",
        tabline_suffix = " ",
      })
      require("colejj.harpoon_tabline").setup()
    end,
  },
  {
    "mbbill/undotree",
    keys = {
      { "<leader>u", "<cmd>UndotreeToggle<CR>", desc = "Undotree" },
    },
  },
  { "jiangmiao/auto-pairs", event = "InsertEnter" },
  { "alvan/vim-closetag", event = "InsertEnter", ft = { "html", "xml", "xhtml" } },
  {
    "numToStr/Comment.nvim",
    keys = {
      { "cc", mode = { "n", "v" } },
      { "cb", mode = { "n", "v" } },
    },
    opts = {
      padding = true,
      sticky = true,
      toggler = { line = "cc", block = "cb" },
      opleader = { line = "cc", block = "cb" },
    },
  },
  {
    "stevearc/conform.nvim",
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ lsp_fallback = true, async = false, timeout_ms = 5000 })
        end,
        mode = { "n", "v" },
        desc = "Format (IntelliJ-Profil)",
      },
      {
        "<leader>jf",
        function()
          require("conform").format({ lsp_fallback = true, async = false, timeout_ms = 5000 })
        end,
        desc = "Format (IntelliJ-Profil)",
      },
    },
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
    end,
  },
}
