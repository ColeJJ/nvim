local profiles = require("colejj.database.profiles")
local psql = require("colejj.database.psql")

local M = {}

local pk_cache = {}

local function quote_ident(name)
  return '"' .. (name or ""):gsub('"', '""') .. '"'
end

local function qualified_table(view)
  if view.schema and view.schema ~= "" then
    return quote_ident(view.schema) .. "." .. quote_ident(view.name)
  end
  return quote_ident(view.name)
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
      value = (raw == "<nil>" or raw == "") and nil or raw,
      cursor_col = fence,
      hl_end = finish,
    }
    if not next_start then
      break
    end
    pos = next_start
  end
  return cells
end

local function cell_index_at(cells, col)
  for i, cell in ipairs(cells) do
    if col >= cell.cursor_col and col <= cell.hl_end then
      return i
    end
  end
  for i, cell in ipairs(cells) do
    if col < cell.cursor_col then
      return i
    end
  end
  return #cells > 0 and #cells or nil
end

local function base_type(col_type)
  return vim.trim((col_type or ""):lower():gsub("%(.*%)", ""))
end

local function is_numeric(col_type)
  local t = base_type(col_type)
  return t:find("int", 1, true)
    or t == "numeric"
    or t == "decimal"
    or t == "real"
    or t:find("float", 1, true)
    or t:find("double", 1, true)
    or t == "serial"
    or t == "bigserial"
    or t == "money"
end

local function is_bool(col_type)
  local t = base_type(col_type)
  return t == "boolean" or t == "bool"
end

local function sql_literal(value, col_type)
  if value == nil then
    return "NULL"
  end
  value = vim.trim(value)
  if value == "" or value:upper() == "NULL" then
    return "NULL"
  end
  if (value == "''" or value == '""') and not is_numeric(col_type) and not is_bool(col_type) then
    return "''"
  end
  if is_numeric(col_type) then
    if value:match("^%-?%d+%.?%d*$") then
      return value
    end
  end
  if is_bool(col_type) then
    local low = value:lower()
    if low == "true" or low == "t" or low == "1" then
      return "TRUE"
    end
    if low == "false" or low == "f" or low == "0" then
      return "FALSE"
    end
  end
  return "'" .. value:gsub("'", "''") .. "'"
end

local function column_types(view)
  local types = {}
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
    sql_literal(view.schema ~= "" and view.schema or "public"),
    sql_literal(view.name)
  )
end

local function load_pks(view, profile, cb)
  local key = (view.schema or "") .. "." .. view.name
  if pk_cache[key] ~= nil then
    cb(pk_cache[key])
    return
  end
  psql.query(profile, pk_sql(view), function(out, err)
    if err then
      cb(nil, err)
      return
    end
    local pks = {}
    for line in vim.gsplit(out or "", "\n", { trimempty = true }) do
      local name = vim.trim(line)
      if name ~= "" then
        pks[#pks + 1] = name
      end
    end
    pk_cache[key] = pks
    cb(pks)
  end)
end

local function by_name(columns, values)
  local map = {}
  for i, col in ipairs(columns) do
    map[col.name] = values[i]
  end
  return map
end

local function build_update(view, column, new_value, pks, row, types)
  local clauses = {}
  for _, pk in ipairs(pks) do
    local cell = row[pk]
    if not cell or cell.value == nil then
      return nil, "Primärschlüssel " .. pk .. " fehlt in der Zeile"
    end
    clauses[#clauses + 1] = quote_ident(pk) .. " = " .. sql_literal(cell.value, types[pk])
  end
  return string.format(
    "UPDATE %s SET %s = %s WHERE %s;",
    qualified_table(view),
    quote_ident(column),
    sql_literal(new_value, types[column]),
    table.concat(clauses, " AND ")
  )
end

function M.edit_cell()
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

  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  if row < 3 then
    vim.notify("Zelle in einer Datenzeile wählen", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end

  local header = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  local line = vim.api.nvim_get_current_line()
  if not header or not line:find("│", 1, true) or line:find("─", 1, true) then
    vim.notify("Keine Tabellenzelle unter dem Cursor", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end

  local columns = parse_cells(header)
  local values = parse_cells(line)
  if #columns == 0 or #columns ~= #values then
    vim.notify("Zeile passt nicht zum Tabellenkopf", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end
  for i, column in ipairs(columns) do
    column.name = column.raw
    values[i].name = column.raw
  end

  local index = cell_index_at(values, col)
  if not index or columns[index].name == "" then
    vim.notify("Cursor steht nicht in einer Datenzelle", vim.log.levels.WARN, { title = "Datenbank" })
    return
  end

  local column = columns[index].name
  local current = values[index].value or ""
  local profile = profile_for(view)
  if not profile then
    vim.notify("Kein Profil für " .. (view.connection_name or "?"), vim.log.levels.ERROR, { title = "Datenbank" })
    return
  end

  load_pks(view, profile, function(pks, err)
    if err then
      vim.notify("Primärschlüssel nicht lesbar:\n" .. err, vim.log.levels.ERROR, { title = "Datenbank" })
      return
    end
    if not pks or #pks == 0 then
      vim.notify("Tabelle hat keinen Primary Key — Update nicht möglich", vim.log.levels.WARN, { title = "Datenbank" })
      return
    end
    local row_map = by_name(columns, values)
    for _, pk in ipairs(pks) do
      if not row_map[pk] then
        vim.notify("Primary Key " .. pk .. " ist nicht im Resultat", vim.log.levels.WARN, { title = "Datenbank" })
        return
      end
    end

    vim.ui.input({
      prompt = string.format("SET %s.%s =  (Enter speichert, Esc bricht ab): ", view.label, column),
      default = current,
    }, function(value)
      if value == nil then
        return
      end
      local new_value = vim.trim(value)
      local old_value = current
      if new_value == old_value then
        vim.notify("Unverändert", vim.log.levels.INFO, { title = "Datenbank" })
        return
      end
      if new_value:upper() == "NULL" then
        new_value = nil
      elseif new_value == "" then
        new_value = nil
      end
      local types = column_types(view)
      local update, build_err = build_update(view, column, new_value, pks, row_map, types)
      if not update then
        vim.notify(build_err, vim.log.levels.ERROR, { title = "Datenbank" })
        return
      end
      psql.exec(profile, update, function(tag, exec_err)
        if exec_err then
          vim.notify("Update fehlgeschlagen:\n" .. exec_err, vim.log.levels.ERROR, { title = "Datenbank" })
          return
        end
        if tag and tag:find("UPDATE 0") then
          vim.notify("Keine Zeile geändert — Primary Key nicht gefunden?", vim.log.levels.WARN, {
            title = "Datenbank",
          })
          return
        end
        vim.notify(tag ~= "" and tag or ("Gespeichert · " .. column), vim.log.levels.INFO, { title = "Datenbank" })
        db.refresh_current_table()
      end)
    end)
  end)
end

return M
