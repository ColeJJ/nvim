return {
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = { "lua_ls", "gopls" },
      automatic_enable = {
        exclude = { "jdtls" },
      },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "stylua",
        "prettier",
        "eslint_d",
        "ktlint",
      },
      run_on_start = false,
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
      if ok then
        capabilities = cmp_lsp.default_capabilities(capabilities)
      end

      if vim.lsp.config then
        pcall(vim.lsp.config, "*", { capabilities = capabilities })
      end

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = {
              checkThirdParty = false,
              library = vim.api.nvim_get_runtime_file("", true),
            },
            telemetry = { enable = false },
          },
        },
      })

      vim.lsp.config("gopls", {
        filetypes = { "go", "gomod", "gowork", "gotmpl" },
        settings = {
          gopls = {
            usePlaceholders = true,
            analyses = { unusedparams = true },
          },
        },
      })

      vim.lsp.enable({ "lua_ls", "gopls" })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("colejj-lsp", { clear = true }),
        callback = function(event)
          local bufnr = event.buf
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
          end

          map("n", "gd", function()
            require("colejj.java.lsp").jump("definition")
          end, "Definition / Referenzen")
          map("n", "gD", function()
            require("colejj.java.lsp").jump("implementation")
          end, "Zur Implementierung")
          map("n", "gy", function()
            require("colejj.java.lsp").jump("type_definition")
          end, "Zur Typ-Definition")
          map("n", "gh", function()
            vim.lsp.buf.hover({ border = "rounded", silent = true })
          end, "Hover / Docs")
          map("n", "gf", function()
            vim.lsp.buf.references({ includeDeclaration = true }, {
              on_list = function(options)
                require("colejj.java.lsp").pick_items(
                  require("colejj.java.lsp").source_items(options.items or {}),
                  "Referenzen"
                )
              end,
            })
          end, "Referenzen")
          map("n", "gn", vim.lsp.buf.rename, "Umbenennen")
          map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code Action")
          map("n", "<leader>cr", vim.lsp.buf.rename, "Rename")
          map("n", "<leader>cs", vim.lsp.buf.document_symbol, "Datei-Symbole")
        end,
      })
    end,
  },
}
