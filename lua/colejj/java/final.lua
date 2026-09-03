-- Fehlendes `final` als Diagnose, analog zu Dooms java-final-ts / IntelliJ
-- "Local variable or parameter can be final". Nur Java-Klassen, nur wenn die
-- Variable wirklich `final` sein könnte (kein Reassignment).

local M = {}

local ns = vim.api.nvim_create_namespace("colejj-java-final")

M.enabled = true

local TYPE_DECL = {
  class_declaration = true,
  enum_declaration = true,
  record_declaration = true,
}

local SKIP_TYPE = {
  interface_declaration = true,
  annotation_type_declaration = true,
}

local LOCAL_SCOPE = {
  method_declaration = true,
  constructor_declaration = true,
  compact_constructor_declaration = true,
  static_initializer = true,
  lambda_expression = true,
}

local INIT_SCOPE = {
  constructor_declaration = true,
  compact_constructor_declaration = true,
  static_initializer = true,
}

local KIND = {
  formal_parameter = "Parameter",
  spread_parameter = "Parameter",
  catch_formal_parameter = "catch-Parameter",
  local_variable_declaration = "Lokale Variable",
  enhanced_for_statement = "Lokale Variable",
  resource = "Lokale Variable",
  field_declaration = "Feld",
}

local decl_query
local assign_query

local function ensure_queries()
  if decl_query and assign_query then
    return true
  end
  local ok_decl, parsed_decl = pcall(
    vim.treesitter.query.parse,
    "java",
    [[
      (formal_parameter) @param
      (local_variable_declaration) @local
      (catch_formal_parameter) @catch
      (field_declaration) @field
      (enhanced_for_statement) @foreach
      (spread_parameter) @spread
      (resource) @resource
    ]]
  )
  local ok_assign, parsed_assign = pcall(
    vim.treesitter.query.parse,
    "java",
    [[
      (assignment_expression left: (identifier) @id)
      (update_expression (identifier) @id)
      (assignment_expression left: (field_access field: (identifier) @field))
      (update_expression (field_access field: (identifier) @field))
    ]]
  )
  if not ok_decl or not ok_assign then
    return false
  end
  decl_query = parsed_decl
  assign_query = parsed_assign
  return true
end

local function child_of_type(node, typ)
  for child in node:iter_children() do
    if child:type() == typ then
      return child
    end
  end
end

local function field1(node, name)
  local fields = node:field(name)
  return fields and fields[1]
end

local function text(node, bufnr)
  local ok, value = pcall(vim.treesitter.get_node_text, node, bufnr)
  if ok then
    return value
  end
  return ""
end

local function has_final(node, bufnr)
  local mods = child_of_type(node, "modifiers")
  return mods ~= nil and text(mods, bufnr):find("%f[%w_]final%f[^%w_]") ~= nil
end

-- Field-Injection: Spring setzt den Wert nach der Konstruktion, `final` geht nicht.
local INJECT_ANN = {
  SpringBean = true,
  Autowired = true,
  Inject = true,
  Resource = true,
}

local function is_injected_field(node, bufnr)
  if node:type() ~= "field_declaration" then
    return false
  end
  local mods = child_of_type(node, "modifiers")
  if not mods then
    return false
  end
  for name in text(mods, bufnr):gmatch("@([%w]+)") do
    if INJECT_ANN[name] then
      return true
    end
  end
  return false
end

local function find_parent(node, types)
  local parent = node:parent()
  while parent do
    if types[parent:type()] then
      return parent
    end
    parent = parent:parent()
  end
end

local function in_skipped_type(node)
  return find_parent(node, SKIP_TYPE) ~= nil
end

local function is_record_component(node)
  if node:type() ~= "formal_parameter" then
    return false
  end
  local params = node:parent()
  if not params or params:type() ~= "formal_parameters" then
    return false
  end
  local record = params:parent()
  return record ~= nil and record:type() == "record_declaration"
end

local function local_scope(node)
  return find_parent(node, LOCAL_SCOPE) or node:parent() or node
end

local METHOD_DECL = {
  method_declaration = true,
  constructor_declaration = true,
  compact_constructor_declaration = true,
}

local function is_method_identifier(name_node)
  local parent = name_node:parent()
  while parent do
    if METHOD_DECL[parent:type()] then
      local declared = field1(parent, "name")
      if declared and declared:equal(name_node) then
        return true
      end
    end
    parent = parent:parent()
  end
  return false
end

local function followed_by_paren(name_node, bufnr)
  local _, _, end_row, end_col = name_node:range()
  local line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1]
  if not line then
    return false
  end
  return line:sub(end_col + 1):match("^%s*%(") ~= nil
end

local function is_class_body_local(node)
  local parent = node:parent()
  local typ = parent and parent:type()
  return typ == "class_body" or typ == "enum_body" or typ == "record_body" or typ == "interface_body" or typ == "ERROR"
end

local function name_nodes(decl)
  local typ = decl:type()
  if typ == "formal_parameter" or typ == "catch_formal_parameter" or typ == "enhanced_for_statement" or typ == "resource" then
    local name = field1(decl, "name")
    if name and name:type() == "identifier" then
      return { name }
    end
    return {}
  end
  if typ == "spread_parameter" then
    local declarator = child_of_type(decl, "variable_declarator")
    local name = declarator and field1(declarator, "name")
    if name and name:type() == "identifier" then
      return { name }
    end
    return {}
  end
  local names = {}
  for _, declarator in ipairs(decl:field("declarator") or {}) do
    local name = field1(declarator, "name")
    if name and name:type() == "identifier" then
      names[#names + 1] = name
    end
  end
  return names
end

local function binding_scope(decl)
  local typ = decl:type()
  if typ == "formal_parameter" or typ == "spread_parameter" or typ == "catch_formal_parameter" then
    return local_scope(decl)
  end
  if typ == "enhanced_for_statement" then
    return decl
  end
  if typ == "resource" then
    return find_parent(decl, { try_statement = true, try_with_resources_statement = true }) or decl
  end
  return find_parent(decl, {
    block = true,
    for_statement = true,
    enhanced_for_statement = true,
    constructor_body = true,
  }) or local_scope(decl)
end

local function is_mutating_field_write(node)
  local parent = node:parent()
  while parent do
    local typ = parent:type()
    if typ == "method_declaration" or typ == "lambda_expression" then
      return true
    end
    if INIT_SCOPE[typ] then
      return false
    end
    if typ == "block" then
      local grand = parent:parent()
      local gtype = grand and grand:type()
      if gtype == "class_body" or gtype == "enum_body" or gtype == "record_body" then
        return false
      end
    end
    if TYPE_DECL[typ] or SKIP_TYPE[typ] then
      return false
    end
    parent = parent:parent()
  end
  return false
end

local function nearest_field_owner(node, name, fields_by_type)
  local parent = node:parent()
  while parent do
    if TYPE_DECL[parent:type()] then
      local declared = fields_by_type[parent:id()]
      if declared and declared[name] then
        return parent
      end
    end
    parent = parent:parent()
  end
end

local function local_at(bindings, name, byte)
  local best
  for _, bind in ipairs(bindings) do
    if bind.name == name and byte > bind.decl and byte >= bind.start and byte < bind.finish then
      if not best or (bind.finish - bind.start) < (best.finish - best.start) then
        best = bind
      end
    end
  end
  return best ~= nil
end

local function collect(bufnr)
  if not ensure_queries() then
    return {}
  end
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "java")
  if not ok or not parser then
    return {}
  end
  parser:parse()
  local tree = parser:trees()[1]
  if not tree then
    return {}
  end
  local root = tree:root()

  local candidates = {}
  local bindings = {}
  local fields_by_type = {}

  for _, node in decl_query:iter_captures(root, bufnr, 0, -1) do
    if
      not METHOD_DECL[node:type()]
      and not is_class_body_local(node)
      and not in_skipped_type(node)
      and not is_record_component(node)
    then
      local names = name_nodes(node)
      if node:type() == "field_declaration" then
        local owner = find_parent(node, TYPE_DECL)
        if owner then
          local declared = fields_by_type[owner:id()] or {}
          for _, name_node in ipairs(names) do
            declared[text(name_node, bufnr)] = true
          end
          fields_by_type[owner:id()] = declared
        end
      elseif node:type() ~= "field_declaration" then
        local scope = binding_scope(node)
        local _, _, start_byte = scope:start()
        local _, _, finish_byte = scope:end_()
        for _, name_node in ipairs(names) do
          local _, _, decl_byte = name_node:start()
          bindings[#bindings + 1] = {
            name = text(name_node, bufnr),
            decl = decl_byte,
            start = start_byte,
            finish = finish_byte,
          }
        end
      end
      if not has_final(node, bufnr) and not is_injected_field(node, bufnr) then
        candidates[#candidates + 1] = node
      end
    end
  end

  local reassigned = {}
  local field_mutated = {}

  local function mark_reassigned(scope, name)
    local key = select(3, scope:start())
    local set = reassigned[key]
    if not set then
      set = {}
      reassigned[key] = set
    end
    set[name] = true
  end

  for id, node in assign_query:iter_captures(root, bufnr, 0, -1) do
    local capture = assign_query.captures[id]
    local name = text(node, bufnr)
    if name ~= "" then
      local _, _, byte = node:start()
      if capture == "id" then
        if local_at(bindings, name, byte) then
          mark_reassigned(local_scope(node), name)
        elseif is_mutating_field_write(node) then
          local owner = nearest_field_owner(node, name, fields_by_type)
          if owner then
            local key = owner:id()
            field_mutated[key] = field_mutated[key] or {}
            field_mutated[key][name] = true
          end
        end
      elseif capture == "field" and is_mutating_field_write(node) then
        local owner = nearest_field_owner(node, name, fields_by_type)
        if owner then
          local key = owner:id()
          field_mutated[key] = field_mutated[key] or {}
          field_mutated[key][name] = true
        end
      end
    end
  end

  local diags = {}
  for _, node in ipairs(candidates) do
    local kind = KIND[node:type()] or "Variable"
    local is_field = node:type() == "field_declaration"
    local owner = is_field and find_parent(node, TYPE_DECL)
    local mutated = owner and field_mutated[owner:id()] or nil
    local scope = not is_field and local_scope(node) or nil
    local assigned = scope and reassigned[select(3, scope:start())] or nil

    for _, name_node in ipairs(name_nodes(node)) do
      local name = text(name_node, bufnr)
      local skip = is_method_identifier(name_node) or followed_by_paren(name_node, bufnr)
      if not skip then
        if is_field then
          skip = mutated and mutated[name]
        else
          skip = assigned and assigned[name]
        end
      end
      if not skip then
        local row, col = name_node:start()
        local end_row, end_col = name_node:end_()
        diags[#diags + 1] = {
          lnum = row,
          col = col,
          end_lnum = end_row,
          end_col = end_col,
          severity = vim.diagnostic.severity.WARN,
          source = "java-final",
          message = string.format("%s '%s' könnte 'final' sein", kind, name),
        }
      end
    end
  end
  return diags
end

local function java_source(bufnr)
  if vim.bo[bufnr].filetype ~= "java" or vim.bo[bufnr].buftype ~= "" then
    return false
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" or not name:match("%.java$") or name:match("^jdt://") then
    return false
  end
  if name:find("/target/", 1, true) or name:find("/generated%-sources/") then
    return false
  end
  return true
end

function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if not M.enabled or not java_source(bufnr) then
    vim.diagnostic.reset(ns, bufnr)
    return
  end
  local ok, diags = pcall(collect, bufnr)
  vim.diagnostic.set(ns, bufnr, ok and diags or {})
end

local pending = {}

local function schedule(bufnr)
  if pending[bufnr] then
    vim.fn.timer_stop(pending[bufnr])
  end
  pending[bufnr] = vim.fn.timer_start(200, function()
    pending[bufnr] = nil
    vim.schedule(function()
      M.refresh(bufnr)
    end)
  end)
end

function M.toggle()
  M.enabled = not M.enabled
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "java" then
      M.refresh(buf)
    end
  end
  vim.notify("final-Warnungen: " .. (M.enabled and "AN" or "AUS"), vim.log.levels.INFO, { title = "java-final" })
end

function M.setup()
  vim.api.nvim_create_user_command("JavaToggleFinalWarnings", M.toggle, {
    desc = "final-Warnungen an/aus",
  })

  local group = vim.api.nvim_create_augroup("colejj-java-final", { clear = true })
  vim.api.nvim_create_autocmd({ "FileType" }, {
    group = group,
    pattern = "java",
    callback = function(event)
      schedule(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave", "TextChanged" }, {
    group = group,
    pattern = "*.java",
    callback = function(event)
      schedule(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(event)
      if pending[event.buf] then
        vim.fn.timer_stop(pending[event.buf])
        pending[event.buf] = nil
      end
      vim.diagnostic.reset(ns, event.buf)
    end,
  })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "java" then
      schedule(buf)
    end
  end
end

return M
