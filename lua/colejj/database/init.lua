local profiles = require("colejj.database.profiles")
local psql = require("colejj.database.psql")
local sql = require("colejj.database.sql")

local M = {}

local last_profile
local current_view
local prepared = false
local setup_done = false
local COL_NS = vim.api.nvim_create_namespace("colejj-db-column")

function M.last_profile_name()
  return last_profile and last_profile.name or nil
end

local function apply_globals()
  vim.g.dbs = profiles.dadbod_list()
end

function M.prepare()
  if prepared then
    return
  end
  prepared = true
  apply_globals()
  psql.ensure_path()
end

local function pick_profile(cb)
  local list = profiles.sorted()
  if #list == 0 then
    vim.notify("Keine DB-Profile", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end
  local default = last_profile and last_profile.name or nil
  vim.ui.select(list, {
    prompt = "DB-Profil",
    format_item = function(item)
      local mark = (default and item.name == default) and "  (zuletzt)" or ""
      return item.name .. mark
    end,
  }, function(choice)
    if choice then
      last_profile = choice
      vim.g.db = choice.url
      cb(choice)
    end
  end)
end

local function with_profile(cb)
  pick_profile(function(profile)
    psql.check(profile, function(ok)
      if ok then
        cb(profile)
      end
    end)
  end)
end

function M.open_browser()
  M.open_viewer()
end

function M.open_table()
  M.open_viewer()
end

function M.open_viewer()
  M.prepare()
  psql.ensure_pgpass()
  local ok, dbee = pcall(require, "dbee")
  if not ok then
    vim.notify("DBee ist noch nicht geladen", vim.log.levels.ERROR, { title = "Datenbank" })
    return
  end
  dbee.toggle()
end

function M.run_dbee_statement()
  local text = sql.at_point()
  if not text or text == "" then
    vim.notify("Kein SQL-Statement am Cursor", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end
  require("dbee").execute(text)
end

local DB_OBJECT_TYPES = {
  table = true,
  view = true,
  materialized_view = true,
  streaming_table = true,
}

local function quote_ident(name)
  return '"' .. (name or ""):gsub('"', '""') .. '"'
end

local function collect_db_objects(nodes, result, seen)
  for _, node in ipairs(nodes or {}) do
    if DB_OBJECT_TYPES[node.type] and node.name and node.name ~= "" then
      local schema = node.schema or ""
      local key = schema .. "\0" .. node.name .. "\0" .. node.type
      if not seen[key] then
        seen[key] = true
        result[#result + 1] = {
          schema = schema,
          name = node.name,
          type = node.type,
          label = (schema ~= "" and (schema .. ".") or "") .. node.name,
        }
      end
    end
    collect_db_objects(node.children, result, seen)
  end
end

local function qualified_table(item)
  local table_name = quote_ident(item.name)
  if item.schema and item.schema ~= "" then
    return quote_ident(item.schema) .. "." .. table_name
  end
  return table_name
end

local function normalize_where(text)
  text = vim.trim(text or "")
  text = text:gsub("^[Ww][Hh][Ee][Rr][Ee]%s+", "")
  text = text:gsub("%s*[Ll][Ii][Mm][Ii][Tt]%s+%d+%s*;?%s*$", "")
  return vim.trim(text)
end

local function table_query(item, where)
  local sql_text = "SELECT * FROM " .. qualified_table(item)
  if where and where ~= "" then
    sql_text = sql_text .. " WHERE " .. where
  end
  return sql_text .. " LIMIT 200;"
end

local function remember_view(connection, item, where)
  current_view = {
    connection_id = connection.id,
    connection_name = connection.name,
    schema = item.schema or "",
    name = item.name,
    type = item.type or "table",
    label = item.label or ((item.schema and item.schema ~= "" and (item.schema .. ".") or "") .. item.name),
    where = where or "",
  }
end

local function parse_table_query(query)
  if not query or query == "" then
    return nil
  end
  local compact = query:gsub("%s+", " "):gsub(";%s*$", "")
  if compact:upper():find("%sJOIN%s") then
    return nil
  end
  local schema, name = compact:match('[Ff][Rr][Oo][Mm]%s+"([^"]+)"%s*%.%s*"([^"]+)"')
  if not name then
    schema, name = compact:match("[Ff][Rr][Oo][Mm]%s+([%w_]+)%s*%.%s*([%w_]+)")
  end
  if not name then
    name = compact:match('[Ff][Rr][Oo][Mm]%s+"([^"]+)"')
    schema = ""
  end
  if not name then
    name = compact:match("[Ff][Rr][Oo][Mm]%s+([%w_]+)")
    schema = ""
  end
  if not name then
    return nil
  end
  local where = compact:match("[Ww][Hh][Ee][Rr][Ee]%s+(.+)%s+[Ll][Ii][Mm][Ii][Tt]%s+%d+")
    or compact:match("[Ww][Hh][Ee][Rr][Ee]%s+(.+)$")
  return {
    schema = schema or "",
    name = name,
    type = "table",
    label = ((schema and schema ~= "") and (schema .. ".") or "") .. name,
    where = normalize_where(where or ""),
  }
end

local function active_connection()
  local ok, dbee = pcall(require, "dbee")
  if not ok then
    return nil
  end
  return dbee.api.core.get_current_connection()
end

local function current_table_view()
  if current_view then
    return current_view
  end
  local dbee = require("dbee")
  local connection = dbee.api.core.get_current_connection()
  if not connection then
    return nil
  end
  local call = dbee.api.ui.result_get_call()
  local parsed = call and parse_table_query(call.query)
  if not parsed then
    return nil
  end
  remember_view(connection, parsed, parsed.where)
  return current_view
end

local function show_table(connection, item, where)
  remember_view(connection, item, where or "")
  require("dbee").api.core.set_current_connection(connection.id)
  require("dbee").execute(table_query(item, current_view.where))
end

local function find_result_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf):find("dbee%-result", 1, false) then
      return win, buf
    end
  end
end

local function wait_result(timeout_ms)
  vim.wait(timeout_ms or 5000, function()
    local ok, call = pcall(require("dbee").api.ui.result_get_call)
    if not ok or not call then
      return false
    end
    return call.state ~= "executing" and call.state ~= "retrieving"
  end, 40)
end

local function parse_result_columns(buf)
  local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  if not line or not line:find("│", 1, true) then
    return {}
  end
  local columns = {}
  local pos = 1
  while true do
    local _, fence = line:find("│", pos, true)
    if not fence then
      break
    end
    local next_start = line:find("│", fence + 1, true)
    local finish = next_start and (next_start - 1) or #line
    local name = vim.trim(line:sub(fence + 1, finish))
    if name ~= "" then
      columns[#columns + 1] = {
        name = name,
        cursor_col = fence,
        hl_end = finish,
      }
    end
    if not next_start then
      break
    end
    pos = next_start
  end
  return columns
end

local function column_types(view)
  local types = {}
  if not view then
    return types
  end
  local ok, cols = pcall(require("dbee").api.core.connection_get_columns, view.connection_id, {
    table = view.name,
    schema = view.schema,
    materialization = (view.type == "view" or view.type == "materialized_view") and "view" or "table",
  })
  if not ok then
    return types
  end
  for _, col in ipairs(cols or {}) do
    types[col.name] = col.type
  end
  return types
end

local function highlight_column(win, buf, column)
  vim.api.nvim_buf_clear_namespace(buf, COL_NS, 0, -1)
  local row = vim.api.nvim_win_get_cursor(win)[1] - 1
  vim.api.nvim_buf_add_highlight(buf, COL_NS, "IncSearch", 0, column.cursor_col, column.hl_end)
  if row > 0 then
    vim.api.nvim_buf_add_highlight(buf, COL_NS, "Visual", row, column.cursor_col, column.hl_end)
  end
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, COL_NS, 0, -1)
    end
  end, 1400)
end

local function jump_to_column(column)
  local win, buf = find_result_win()
  if not win then
    vim.notify("Kein DBee-Resultat offen", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end
  vim.api.nvim_set_current_win(win)
  local row = vim.api.nvim_win_get_cursor(win)[1]
  if row < 3 and vim.api.nvim_buf_line_count(buf) >= 3 then
    row = 3
  end
  vim.api.nvim_win_set_cursor(win, { row, column.cursor_col })
  vim.api.nvim_win_call(win, function()
    vim.cmd("normal! zs")
  end)
  highlight_column(win, buf, column)
end

local function pick_items(opts)
  local ok_telescope, pickers = pcall(require, "telescope.pickers")
  if not ok_telescope then
    vim.ui.select(opts.items, {
      prompt = opts.prompt,
      format_item = opts.format_item,
    }, function(item)
      if item then
        opts.on_select(item)
      end
    end)
    return
  end

  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values
  local entry_display = require("telescope.pickers.entry_display")
  local displayer = entry_display.create({
    separator = " ",
    items = opts.display_items or {
      { remaining = true },
    },
  })

  local picker_opts = {}
  if opts.dropdown then
    picker_opts = require("telescope.themes").get_dropdown({
      previewer = false,
    })
  end
  pickers
    .new(picker_opts, {
      prompt_title = opts.prompt,
      previewer = false,
      finder = require("telescope.finders").new_table({
        results = opts.items,
        entry_maker = function(item)
          return {
            value = item,
            display = function()
              return displayer(opts.display(item))
            end,
            ordinal = opts.ordinal(item),
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry and entry.value then
            opts.on_select(entry.value)
          end
        end)
        return true
      end,
    })
    :find()
end

function M.find_dbee_table()
  local dbee = require("dbee")
  local connection = dbee.api.core.get_current_connection()
  if not connection then
    vim.notify("Keine aktive DBee-Verbindung. In SPC o d eine Verbindung mit Enter wählen.", vim.log.levels.WARN, {
      title = "Datenbank",
    })
    return
  end

  vim.notify("Lade Tabellen aus " .. connection.name .. " …", vim.log.levels.INFO, { title = "Datenbank" })
  local ok, structure = pcall(dbee.api.core.connection_get_structure, connection.id)
  if not ok then
    vim.notify("Tabellen konnten nicht geladen werden:\n" .. tostring(structure), vim.log.levels.ERROR, {
      title = "Datenbank",
    })
    return
  end

  local items = {}
  collect_db_objects(structure, items, {})
  table.sort(items, function(a, b)
    return a.label < b.label
  end)
  if #items == 0 then
    vim.notify("Keine Tabellen oder Views gefunden", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end

  pick_items({
    prompt = "Tabellen · " .. connection.name,
    items = items,
    format_item = function(item)
      return item.label
    end,
    display_items = {
      { width = 3 },
      { remaining = true },
    },
    display = function(item)
      local icon = item.type == "table" and "" or "󰈈"
      return {
        { icon, item.type == "table" and "Type" or "Function" },
        item.label,
      }
    end,
    ordinal = function(item)
      return item.label .. " " .. item.type
    end,
    on_select = function(item)
      show_table(connection, item)
    end,
  })
end

function M.find_dbee_column()
  local connection = active_connection()
  if not connection then
    vim.notify("Keine aktive DBee-Verbindung. In SPC o d eine Verbindung mit Enter wählen.", vim.log.levels.WARN, {
      title = "Datenbank",
    })
    return
  end

  local win, buf = find_result_win()
  if not win then
    local view = current_table_view()
    if not view then
      vim.notify("Zuerst eine Tabelle öffnen (SPC f t)", vim.log.levels.WARN, { title = "Datenbank" })
      return
    end
    show_table({ id = view.connection_id, name = view.connection_name }, view, view.where)
    wait_result()
    win, buf = find_result_win()
  end
  if not buf then
    vim.notify("Kein DBee-Resultat offen", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end

  local columns = parse_result_columns(buf)
  if #columns == 0 then
    vim.notify("Keine Spalten im aktuellen Resultat", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end

  local types = column_types(current_table_view())
  for _, column in ipairs(columns) do
    column.type = types[column.name] or ""
  end

  pick_items({
    dropdown = true,
    prompt = "Spalten" .. (current_view and (" · " .. current_view.label) or ""),
    items = columns,
    format_item = function(item)
      return item.type ~= "" and (item.name .. "  " .. item.type) or item.name
    end,
    display_items = {
      { width = 3 },
      { width = 32 },
      { remaining = true },
    },
    display = function(item)
      return {
        { "󰓹", "Type" },
        { item.name, "Identifier" },
        item.type,
      }
    end,
    ordinal = function(item)
      return item.name .. " " .. item.type
    end,
    on_select = function(item)
      M.goto_dbee_column(item.name)
    end,
  })
end

function M.yank_dbee_cell()
  local line = vim.api.nvim_get_current_line()
  if not line or not line:find("│", 1, true) then
    vim.notify("Kein Tabellenzelle unter dem Cursor", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local left = 0
  local pos = 1
  while true do
    local start, finish = line:find("│", pos, true)
    if not start or start >= col then
      break
    end
    left = finish
    pos = finish + 1
  end
  if left == 0 then
    vim.notify("Cursor steht nicht in einer Datenzelle", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end
  local right = line:find("│", math.max(col, left + 1), true)
  local text = vim.trim(line:sub(left + 1, right and (right - 1) or #line))
  if text == "<nil>" then
    text = ""
  end
  vim.fn.setreg('"', text)
  pcall(vim.fn.setreg, "+", text)
  if text == "" then
    vim.notify("NULL kopiert (leer)", vim.log.levels.INFO, { title = "Datenbank" })
  else
    vim.notify("Kopiert: " .. text, vim.log.levels.INFO, { title = "Datenbank" })
  end
end

function M.goto_dbee_column(name)
  local win, buf = find_result_win()
  if not buf then
    vim.notify("Kein DBee-Resultat offen", vim.log.levels.WARN, { title = "Datenbank" })
    return false
  end
  for _, column in ipairs(parse_result_columns(buf)) do
    if column.name == name then
      jump_to_column(column)
      return true
    end
  end
  vim.notify("Spalte nicht gefunden: " .. name, vim.log.levels.WARN, { title = "Datenbank" })
  return false
end

function M.table_view()
  return current_table_view()
end

function M.refresh_current_table()
  local view = current_table_view()
  if not view then
    return
  end
  show_table({ id = view.connection_id, name = view.connection_name }, view, view.where)
end

function M.edit_dbee_cell()
  require("colejj.database.edit").edit_cell()
end

function M.filter_dbee_table()
  local connection = active_connection()
  if not connection then
    vim.notify("Keine aktive DBee-Verbindung. In SPC o d eine Verbindung mit Enter wählen.", vim.log.levels.WARN, {
      title = "Datenbank",
    })
    return
  end

  local view = current_table_view()
  if not view then
    vim.notify("Zuerst eine Tabelle öffnen (SPC f t)", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end

  local prompt = "WHERE  (" .. view.label .. ")"
  if view.where ~= "" then
    prompt = prompt .. "  · leer = Filter löschen"
  end
  vim.ui.input({
    prompt = prompt .. ": ",
    default = view.where,
  }, function(value)
    if value == nil then
      return
    end
    local where = normalize_where(value)
    show_table({ id = view.connection_id, name = view.connection_name }, view, where)
    if where == "" then
      vim.notify("Filter entfernt · " .. view.label, vim.log.levels.INFO, { title = "Datenbank" })
    else
      vim.notify("WHERE " .. where, vim.log.levels.INFO, { title = "Datenbank" })
    end
  end)
end

function M.run_sql()
  M.prepare()
  local buf = vim.api.nvim_get_current_buf()
  local text, srow, erow = sql.selection_or_statement()
  if not text or text == "" then
    vim.notify("Kein SQL ausgewählt — Region markieren oder Cursor ins Statement setzen", vim.log.levels.WARN, {
      title = "Datenbank",
    })
    return
  end
  with_profile(function(profile)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    vim.b[buf].db = profile.url
    local started = vim.uv.hrtime()
    vim.api.nvim_buf_call(buf, function()
      if srow and erow then
        vim.cmd(string.format("%d,%dDB", srow, erow))
      else
        vim.cmd("%DB")
      end
    end)
    local ms = math.floor((vim.uv.hrtime() - started) / 1e6)
    vim.notify(string.format("%s  |  %d ms", profile.name, ms), vim.log.levels.INFO, { title = "Datenbank" })
  end)
end

local function map_sql_buffer(bufnr)
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set({ "n", "v" }, "<leader>ms", M.run_sql, vim.tbl_extend("force", opts, { desc = "SQL ausführen" }))
  vim.keymap.set({ "n", "v" }, "<C-c><C-c>", M.run_sql, vim.tbl_extend("force", opts, { desc = "SQL ausführen" }))
end

function M.setup()
  M.prepare()
  if setup_done then
    return
  end
  setup_done = true
  psql.warn_prerequisites()

  vim.api.nvim_create_user_command("DBCheck", function(opts)
    local name = opts.args
    local profile
    for _, item in ipairs(profiles.all()) do
      if item.name == name or (name == "" and last_profile and item.name == last_profile.name) then
        profile = item
        break
      end
    end
    if not profile then
      vim.notify("Unbekanntes DB-Profil", vim.log.levels.ERROR, { title = "Datenbank" })
      return
    end
    psql.check(profile, function(ok)
      if ok then
        vim.notify(profile.name .. ": Verbindung erfolgreich", vim.log.levels.INFO, { title = "Datenbank" })
      end
    end)
  end, {
    nargs = "?",
    complete = function()
      local names = {}
      for _, item in ipairs(profiles.all()) do
        names[#names + 1] = item.name
      end
      return names
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("colejj-database", { clear = true }),
    pattern = { "sql", "mysql", "plsql" },
    callback = function(event)
      map_sql_buffer(event.buf)
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("colejj-database-ui", { clear = true }),
    pattern = { "dbout" },
    callback = function(event)
      vim.keymap.set("n", "q", function()
        pcall(vim.cmd.normal, { "gq", bang = true })
        if vim.api.nvim_buf_is_valid(event.buf) then
          pcall(vim.api.nvim_win_close, 0, true)
        end
      end, { buffer = event.buf, silent = true, desc = "DB-Fenster schließen" })
      if last_profile then
        pcall(vim.api.nvim_set_option_value, "winbar", "DB: " .. last_profile.name, { scope = "local" })
      end
    end,
  })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local ft = vim.bo[buf].filetype
      if ft == "sql" or ft == "mysql" or ft == "plsql" then
        map_sql_buffer(buf)
      end
    end
  end
end

return M
