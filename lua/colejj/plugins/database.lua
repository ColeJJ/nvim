return {
  {
    "kndndrj/nvim-dbee",
    dependencies = { "MunifTanjim/nui.nvim" },
    build = function()
      require("dbee").install()
    end,
    keys = {
      {
        "<leader>od",
        function()
          require("colejj.database").open_viewer()
        end,
        desc = "Datenbank-Viewer",
      },
      {
        "<leader>ft",
        function()
          require("colejj.database").find_dbee_table()
        end,
        desc = "DB-Tabelle finden",
      },
      {
        "<leader>tc",
        function()
          require("colejj.database").find_dbee_column()
        end,
        desc = "DB-Spalte finden",
      },
      {
        "<leader>tw",
        function()
          require("colejj.database").filter_dbee_table()
        end,
        desc = "DB-WHERE-Filter",
      },
    },
    config = function()
      local profiles = require("colejj.database.profiles")
      local sources = require("dbee.sources")
      local defaults = require("dbee.config").default
      local connections = profiles.dbee_list()
      local drawer_mappings = vim.deepcopy(defaults.drawer.mappings)
      local editor_mappings = vim.deepcopy(defaults.editor.mappings)
      local result_mappings = vim.deepcopy(defaults.result.mappings)
      table.insert(drawer_mappings, {
        key = "q",
        mode = "n",
        action = function()
          require("dbee").close()
        end,
      })
      table.insert(result_mappings, {
        key = "q",
        mode = "n",
        action = function()
          require("dbee").close()
        end,
      })
      table.insert(result_mappings, {
        key = "yc",
        mode = "n",
        action = function()
          require("colejj.database").yank_dbee_cell()
        end,
      })
      table.insert(result_mappings, {
        key = "yy",
        mode = "n",
        action = function()
          require("colejj.database").yank_dbee_cell()
        end,
      })
      table.insert(result_mappings, {
        key = "<CR>",
        mode = "n",
        action = function()
          require("colejj.database").edit_dbee_cell()
        end,
      })
      table.insert(editor_mappings, {
        key = "<leader>ms",
        mode = "n",
        action = function()
          require("colejj.database").run_dbee_statement()
        end,
      })
      table.insert(editor_mappings, {
        key = "<leader>ms",
        mode = "v",
        action = "run_selection",
      })
      require("dbee").setup({
        sources = {
          sources.MemorySource:new(connections),
        },
        default_connection = connections[1] and connections[1].id or nil,
        extra_helpers = {
          postgres = {
            ["Daten anzeigen (max. 200)"] = 'SELECT * FROM "{{ .Schema }}"."{{ .Table }}" LIMIT 200;',
            ["Zeilen zählen"] = 'SELECT count(*) AS rows FROM "{{ .Schema }}"."{{ .Table }}";',
          },
        },
        drawer = {
          mappings = drawer_mappings,
        },
        editor = {
          mappings = editor_mappings,
        },
        result = {
          page_size = 200,
          focus_result = true,
          mappings = result_mappings,
        },
        window_layout = require("colejj.database.layout").new({
          drawer_width = 40,
          call_log_height = 8,
        }),
      })
      require("colejj.database").setup()
    end,
  },
  {
    "tpope/vim-dadbod",
    cmd = { "DB" },
    ft = { "sql", "mysql", "plsql" },
    dependencies = {
      {
        "kristijanhusak/vim-dadbod-completion",
        ft = { "sql", "mysql", "plsql" },
        lazy = true,
      },
    },
    init = function()
      require("colejj.database").prepare()
    end,
    config = function()
      require("colejj.database").setup()
    end,
  },
}
