local profiles = require("colejj.database.profiles")
local psql = require("colejj.database.psql")

local M = {}

local NS = vim.api.nvim_create_namespace("colejj-dbee-delete")
local states = {}
local pk_cache = {}

local function quote_ident(name)
  return '"' .. (name or ""):gsub('"', '""') .. '"'
end

local function quote_string(value)
  return "'" .. tostring(value):gsub("'", "''") .. "'"
end

local function qualified_table(view)
  if view.schema and view.schema ~= "" then
    return quote_ident(view.schema) .. "." .. quote_ident(view.name)
  end
  return quote_ident(view.name)
end

local function view_id(view)
  return table.concat({ view.connection_id or "", view.schema or "", view.name or "" }, "\0")
end

local function profile_for(view)
  for _, profile in ipairs(profiles.all()) do
    if profile.name == view.connection_name then
      return profile
    end
  end
end

local function parse_cells(line)
  local cells = {}
  local pos = 1
  while true do
    local _, fence = line:find("│", pos, true)
    if not fence then
      break
    end
    local next_start = line:find("│", fence + 1, true)
    local finish = next_start and (next_start - 1) or #line
    local raw = vim.trim(line:sub(fence + 1, finish))
    cells[#cells + 1] = {
      raw = raw,
      value = raw == "<nil>" and nil or raw,
    }
    if not next_start then
      break
    end
    pos = next_start
  end
  return cells
end

local function result_columns(buf)
  local header = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  if not header then
    return {}
  end
  local columns = parse_cells(header)
  for _, column in ipairs(columns) do
    column.name = column.raw
  end
  return columns
end

local function result_row(buf, lnum, columns)
  if lnum < 3 or lnum > vim.api.nvim_buf_line_count(buf) then
    return nil
  end
  local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
  if not line or not line:find("│", 1, true) or line:find("─", 1, true) then
    return nil
  end
  local cells = parse_cells(line)
  if #cells ~= #columns then
    return nil
  end
  local row = {}
  for i, column in ipairs(columns) do
    row[column.name] = cells[i].value
  end
  return row
end

local function base_type(col_type)
  return vim.trim((col_type or ""):lower():gsub("%(.*%)", ""))
end

local function sql_literal(value, col_type)
  if value == nil then
    return "NULL"
  end
  local text = tostring(value)
  local typ = base_type(col_type)
  if typ:find("int", 1, true)
    or typ == "numeric"
    or typ == "decimal"
    or typ == "real"
    or typ:find("float", 1, true)
    or typ:find("double", 1, true)
    or typ == "serial"
    or typ == "bigserial"
  then
    if text:match("^%-?%d+%.?%d*$") then
      return text
    end
  elseif typ == "boolean" or typ == "bool" then
    local low = text:lower()
    if low == "true" or low == "t" or low == "1" then
      return "TRUE"
    end
    if low == "false" or low == "f" or low == "0" then
      return "FALSE"
    end
  end
  return quote_string(text)
end

local function column_types(view)
  local types = {}
  local ok, columns = pcall(require("dbee").api.core.connection_get_columns, view.connection_id, {
    table = view.name,
    schema = view.schema,
    materialization = "table",
  })
  if not ok then
    return types
  end
  for _, column in ipairs(columns or {}) do
    types[column.name] = column.type
  end
  return types
end

local function pk_sql(view)
  return string.format(
    [[
SELECT kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
 AND tc.table_name = kcu.table_name
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_schema = %s
  AND tc.table_name = %s
ORDER BY kcu.ordinal_position;
]],
    quote_string(view.schema ~= "" and view.schema or "public"),
    quote_string(view.name)
  )
end

local function load_pks(view, profile, callback)
  local key = view_id(view)
  if pk_cache[key] then
    callback(pk_cache[key])
    return
  end
  psql.query(profile, pk_sql(view), function(output, err)
    if err then
      callback(nil, err)
      return
    end
    local pks = {}
    for line in vim.gsplit(output or "", "\n", { trimempty = true }) do
      local name = vim.trim(line)
      if name ~= "" then
        pks[#pks + 1] = name
      end
    end
    pk_cache[key] = pks
    callback(pks)
  end)
end

local function state_for(buf, view)
  local id = view_id(view)
  local state = states[buf]
  if state and state.view_id ~= id then
    vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
    states[buf] = nil
    state = nil
  end
  if not state then
    state = {
      view_id = id,
      rows = {},
      loading = false,
      executing = false,
    }
    states[buf] = state
  end
  return state
end

local function clear(buf)
  states[buf] = nil
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  end
end

local function row_count(state)
  local count = 0
  for _ in pairs(state.rows) do
    count = count + 1
  end
  return count
end

local function row_key(row, pks)
  local values = {}
  for _, pk in ipairs(pks) do
    if row[pk] == nil then
      return nil, "Primary Key " .. pk .. " fehlt oder ist NULL"
    end
    values[#values + 1] = row[pk]
  end
  return vim.json.encode(values)
end

local function predicate(row, pks, types)
  local parts = {}
  for _, pk in ipairs(pks) do
    parts[#parts + 1] = quote_ident(pk) .. " = " .. sql_literal(row[pk], types[pk])
  end
  return table.concat(parts, " AND ")
end

local function mark_row(buf, state, candidate)
  local extmark = vim.api.nvim_buf_set_extmark(buf, NS, candidate.lnum - 1, 0, {
    line_hl_group = "ColejjDbeeDeletePending",
    sign_text = "×",
    sign_hl_group = "DiagnosticError",
    priority = 200,
  })
  candidate.extmark = extmark
  state.rows[candidate.key] = candidate
end

local function unmark_row(buf, state, key)
  local candidate = state.rows[key]
  if not candidate then
    return
  end
  pcall(vim.api.nvim_buf_del_extmark, buf, NS, candidate.extmark)
  state.rows[key] = nil
end

local function notify_marked(state)
  local count = row_count(state)
  if count == 0 then
    vim.notify("Keine Zeilen zum Löschen markiert", vim.log.levels.INFO, { title = "Datenbank" })
    return
  end
  vim.notify(
    string.format("%d Zeile(n) zum Löschen markiert · Enter bestätigt · dd hebt auf", count),
    vim.log.levels.WARN,
    { title = "Datenbank" }
  )
end

function M.toggle_range(first, last)
  local db = require("colejj.database")
  local view = db.table_view()
  if not view then
    vim.notify("Zuerst eine Tabelle öffnen (SPC f t)", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end
  if view.type == "view" or view.type == "materialized_view" then
    vim.notify("Views lassen sich nicht direkt ändern", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local columns = result_columns(buf)
  if #columns == 0 then
    vim.notify("Kein Tabellenresultat unter dem Cursor", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end
  local profile = profile_for(view)
  if not profile then
    vim.notify("Kein Profil für " .. (view.connection_name or "?"), vim.log.levels.ERROR, { title = "Datenbank" })
    return
  end

  local state = state_for(buf, view)
  if state.loading or state.executing then
    return
  end
  state.loading = true
  first, last = math.min(first, last), math.max(first, last)

  load_pks(view, profile, function(pks, err)
    if states[buf] ~= state or not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    state.loading = false
    if err then
      vim.notify("Primärschlüssel nicht lesbar:\n" .. err, vim.log.levels.ERROR, { title = "Datenbank" })
      return
    end
    if not pks or #pks == 0 then
      vim.notify("Tabelle hat keinen Primary Key — Löschen nicht möglich", vim.log.levels.WARN, {
        title = "Datenbank",
      })
      return
    end

    local types = column_types(view)
    local candidates = {}
    for lnum = first, last do
      local row = result_row(buf, lnum, columns)
      if row then
        local key, key_err = row_key(row, pks)
        if not key then
          vim.notify(key_err, vim.log.levels.WARN, { title = "Datenbank" })
          return
        end
        candidates[#candidates + 1] = {
          key = key,
          lnum = lnum,
          predicate = predicate(row, pks, types),
        }
      end
    end
    if #candidates == 0 then
      vim.notify("Keine Datenzeile ausgewählt", vim.log.levels.WARN, { title = "Datenbank" })
      return
    end

    local all_marked = true
    for _, candidate in ipairs(candidates) do
      if not state.rows[candidate.key] then
        all_marked = false
        break
      end
    end
    for _, candidate in ipairs(candidates) do
      if all_marked then
        unmark_row(buf, state, candidate.key)
      elseif not state.rows[candidate.key] then
        mark_row(buf, state, candidate)
      end
    end
    notify_marked(state)
  end)
end

function M.toggle_current()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  M.toggle_range(line, line)
end

function M.toggle_visual()
  local first = vim.fn.line("v")
  local last = vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  M.toggle_range(first, last)
end

local function confirm_delete(buf, state, view)
  if state.executing then
    return
  end
  if state.view_id ~= view_id(view) then
    clear(buf)
    vim.notify("Tabelle hat gewechselt; Löschmarkierungen wurden verworfen", vim.log.levels.WARN, {
      title = "Datenbank",
    })
    return
  end

  local rows = {}
  for _, row in pairs(state.rows) do
    rows[#rows + 1] = row
  end
  table.sort(rows, function(a, b)
    return a.lnum < b.lnum
  end)
  if #rows == 0 then
    return
  end

  local profile = profile_for(view)
  if not profile then
    vim.notify("Kein Profil für " .. (view.connection_name or "?"), vim.log.levels.ERROR, { title = "Datenbank" })
    return
  end
  local predicates = {}
  for _, row in ipairs(rows) do
    predicates[#predicates + 1] = "(" .. row.predicate .. ")"
  end
  local sql = string.format("DELETE FROM %s WHERE %s;", qualified_table(view), table.concat(predicates, " OR "))

  state.executing = true
  vim.notify(string.format("Lösche %d markierte Zeile(n) …", #rows), vim.log.levels.WARN, { title = "Datenbank" })
  psql.exec(profile, sql, function(tag, err)
    if states[buf] ~= state then
      return
    end
    state.executing = false
    if err then
      vim.notify("Löschen fehlgeschlagen:\n" .. err, vim.log.levels.ERROR, { title = "Datenbank" })
      return
    end
    local deleted = tonumber((tag or ""):match("DELETE%s+(%d+)"))
    clear(buf)
    if deleted and deleted ~= #rows then
      vim.notify(
        string.format("%d von %d markierten Zeilen gelöscht", deleted, #rows),
        vim.log.levels.WARN,
        { title = "Datenbank" }
      )
    else
      vim.notify(string.format("%d Zeile(n) gelöscht", deleted or #rows), vim.log.levels.INFO, { title = "Datenbank" })
    end
    require("colejj.database").refresh_current_table()
  end)
end

function M.confirm_or_edit()
  local buf = vim.api.nvim_get_current_buf()
  local state = states[buf]
  if state and state.loading then
    vim.notify("Löschmarkierung wird noch vorbereitet …", vim.log.levels.INFO, { title = "Datenbank" })
    return
  end
  if not state or row_count(state) == 0 then
    require("colejj.database.edit").edit_cell()
    return
  end
  local view = require("colejj.database").table_view()
  if not view then
    clear(buf)
    return
  end
  confirm_delete(buf, state, view)
end

vim.api.nvim_set_hl(0, "ColejjDbeeDeletePending", { link = "DiffDelete", default = true })

local group = vim.api.nvim_create_augroup("colejj-dbee-delete", { clear = true })
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = group,
  callback = function(args)
    if states[args.buf] then
      clear(args.buf)
    end
  end,
})
vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(args)
    states[args.buf] = nil
  end,
})

return M
