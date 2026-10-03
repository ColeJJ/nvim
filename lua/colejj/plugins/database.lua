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
          require("colejj.database.delete").confirm_or_edit()
        end,
      })
      table.insert(result_mappings, {
        key = "dd",
        mode = "n",
        action = function()
          require("colejj.database.delete").toggle_current()
        end,
      })
      table.insert(result_mappings, {
        key = "dd",
        mode = "v",
        action = function()
          require("colejj.database.delete").toggle_visual()
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
            ["Spalten & Typen"] = [[
SELECT ordinal_position, column_name, data_type, udt_name, is_nullable, column_default, character_maximum_length
FROM information_schema.columns
WHERE table_schema = '{{ .Schema }}' AND table_name = '{{ .Table }}'
ORDER BY ordinal_position;]],
            ["Constraints"] = [[
SELECT tc.constraint_name, tc.constraint_type, kcu.column_name,
       ccu.table_schema AS foreign_schema, ccu.table_name AS foreign_table, ccu.column_name AS foreign_column
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name AND tc.table_schema = ccu.table_schema
WHERE tc.table_schema = '{{ .Schema }}' AND tc.table_name = '{{ .Table }}'
ORDER BY tc.constraint_type, tc.constraint_name, kcu.ordinal_position;]],
            ["Tabellentyp"] = [[
SELECT n.nspname AS schema, c.relname AS name,
       CASE c.relkind
         WHEN 'r' THEN 'table'
         WHEN 'v' THEN 'view'
         WHEN 'm' THEN 'materialized view'
         WHEN 'p' THEN 'partitioned table'
         WHEN 'f' THEN 'foreign table'
         ELSE c.relkind::text
       END AS kind,
       pg_catalog.obj_description(c.oid, 'pg_class') AS comment
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = '{{ .Schema }}' AND c.relname = '{{ .Table }}';]],
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
