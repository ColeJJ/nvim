return {
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",
    build = "make install_jsregexp",
    event = "InsertEnter",
    dependencies = { "rafamadriz/friendly-snippets" },
    config = function()
      local luasnip = require("luasnip")
      luasnip.setup({
        update_events = { "TextChangedI" },
      })
      require("luasnip.loaders.from_vscode").lazy_load()
      luasnip.filetype_extend("html", { "angular" })
      luasnip.filetype_extend("typescript", { "angular" })
      require("colejj.snippets").setup()
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-emoji",
      "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind-nvim",
      "L3MON4D3/LuaSnip",
      "kristijanhusak/vim-dadbod-completion",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      local lspkind = require("lspkind")

      -- Quellen, deren after/plugin den Load-Zyklus verpasst hat, nachziehen.
      local function source_registered(name)
        for _, src in pairs(cmp.core.sources) do
          if src.name == name then
            return true
          end
        end
        return false
      end

      local function ensure_source(name, create)
        if source_registered(name) then
          return
        end
        local ok, src = pcall(create)
        if ok and src then
          cmp.register_source(name, src)
        end
      end

      local function ensure_sources()
        pcall(function()
          require("cmp_nvim_lsp").setup()
        end)
        ensure_source("luasnip", function()
          return require("cmp_luasnip").new()
        end)
        ensure_source("buffer", function()
          return require("cmp_buffer")
        end)
        ensure_source("path", function()
          return require("cmp_path").new()
        end)
        ensure_source("emoji", function()
          return require("cmp_emoji").new()
        end)
        ensure_source("vim-dadbod-completion", function()
          return require("vim_dadbod_completion").nvim_cmp_source
        end)
        pcall(function()
          require("cmp_luasnip").clear_cache()
        end)
      end

      vim.opt.completeopt = { "menu", "menuone", "noselect", "noinsert" }

      cmp.setup({
        completion = {
          completeopt = "menu,menuone,preview,noselect,noinsert",
          keyword_length = 1,
        },
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          completion = { border = "rounded" },
          documentation = { border = "rounded" },
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
          ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
          ["<C-y>"] = cmp.mapping.confirm({ select = true }),
          ["<CR>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.confirm({ select = true })
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if luasnip.expandable() then
              luasnip.expand()
            elseif cmp.visible() then
              cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer", keyword_length = 2 },
          { name = "path" },
        }),
        formatting = {
          format = lspkind.cmp_format({
            mode = "symbol_text",
            before = function(entry, vim_item)
              if entry.source.name == "luasnip" then
                local data = entry.completion_item.data
                local snip = data and data.snip_id and require("luasnip").get_id_snippet(data.snip_id)
                if snip and snip.name and snip.name ~= "" and snip.name ~= vim_item.abbr then
                  vim_item.abbr = (snip.trigger or vim_item.abbr) .. "  " .. snip.name
                end
              end
              return vim_item
            end,
            menu = {
              buffer = "[Buffer]",
              nvim_lsp = "[LSP]",
              luasnip = "[Snippet]",
              ["vim-dadbod-completion"] = "[DB]",
            },
          }),
        },
      })

      local snippet_first = {
        { name = "luasnip", keyword_length = 1 },
        { name = "nvim_lsp" },
        { name = "buffer", keyword_length = 2 },
        { name = "path" },
      }
      cmp.setup.filetype({ "xml", "java", "kotlin" }, {
        sources = cmp.config.sources(snippet_first),
      })

      cmp.setup.filetype("markdown", {
        sources = cmp.config.sources({
          { name = "luasnip", keyword_length = 1 },
          { name = "nvim_lsp" },
          { name = "path" },
          { name = "emoji" },
          { name = "buffer", keyword_length = 2 },
        }),
      })

      cmp.setup.filetype({ "sql", "mysql", "plsql" }, {
        sources = cmp.config.sources({
          { name = "vim-dadbod-completion" },
          { name = "luasnip" },
          { name = "buffer", keyword_length = 2 },
          { name = "path" },
        }),
      })

      vim.schedule(ensure_sources)
    end,
  },
}
