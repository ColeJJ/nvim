-- Record-Komponenten: JDT.LS-Rename ändert oft nur den Header oder knallt mit -32603.
-- Wir sammeln alle Stellen selbst (Datei + Referenzen + Workspace-Symbole) und ersetzen.

local M = {}

local function ts_root(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "java")
  if not ok or not parser then
    return nil
  end
  local tree = parser:parse()[1]
  return tree and tree:root() or nil
end

local function parent_of_type(node, typ)
  while node do
    if node:type() == typ then
      return node
    end
    node = node:parent()
  end
end

local function identifier_at_cursor(bufnr)
  local node = vim.treesitter.get_node({ bufnr = bufnr })
  if not node then
    return nil
  end
  if node:type() == "identifier" then
    return node
  end
  local named = node:field("name")[1]
  if named and named:type() == "identifier" then
    return named
  end
  for child in node:iter_children() do
    if child:type() == "identifier" then
      return child
    end
  end
  return node
end

--- Record-Header ist bei tree-sitter-java ein formal_parameter, nicht record_component.
local function in_record_header(node)
  if parent_of_type(node, "record_component") then
    return true
  end
  local param = parent_of_type(node, "formal_parameter")
  if not param then
    return false
  end
  if parent_of_type(param, "class_body") or parent_of_type(param, "method_declaration") then
    return false
  end
  return parent_of_type(param, "record_declaration") ~= nil
end

local function is_record_component(node)
  return in_record_header(node)
end

local function each_identifier(bufnr, name, cb)
  local root = ts_root(bufnr)
  if not root then
    return
  end
  local ok, query = pcall(vim.treesitter.query.parse, "java", "(identifier) @id")
  if not ok then
    return
  end
  for _, node in query:iter_captures(root, bufnr) do
    if vim.treesitter.get_node_text(node, bufnr) == name then
      cb(node)
    end
  end
end

local function record_type_name(bufnr, node)
  local rec = parent_of_type(node, "record_declaration")
  if not rec then
    return nil
  end
  for child in rec:iter_children() do
    if child:type() == "identifier" then
      return vim.treesitter.get_node_text(child, bufnr)
    end
  end
end

local function same_record_symbol(node)
  if is_record_component(node) then
    return true
  end
  if parent_of_type(node, "compact_constructor_declaration") then
    return true
  end
  local parent = node:parent()
  if parent and (parent:type() == "method_invocation" or parent:type() == "field_access") then
    return true
  end
  return false
end

local function has_header_component(bufnr, name)
  local found = false
  each_identifier(bufnr, name, function(other)
    if in_record_header(other) then
      found = true
    end
  end)
  return found
end

local function is_record_symbol(bufnr, node, name)
  if not node or node:type() ~= "identifier" then
    return false
  end
  if in_record_header(node) then
    return true
  end
  if parent_of_type(node, "compact_constructor_declaration") and has_header_component(bufnr, name) then
    return true
  end
  return parent_of_type(node, "record_declaration") ~= nil and has_header_component(bufnr, name)
end

local function node_range(client, bufnr, node)
  local sr, sc, er, ec = node:range()
  local encoding = client.offset_encoding or "utf-16"
  return {
    start = {
      line = sr,
      character = vim.lsp.util.character_offset(bufnr, sr, sc, encoding),
    },
    ["end"] = {
      line = er,
      character = vim.lsp.util.character_offset(bufnr, er, ec, encoding),
    },
  }
end

local function loc_parts(loc)
  local uri = loc.uri or loc.targetUri
  local range = loc.range or loc.targetSelectionRange or loc.targetRange
  if not uri or not range or not range.start then
    return nil
  end
  return uri, range
end

local function loc_key(uri, range)
  return string.format(
    "%s:%d:%d:%d:%d",
    uri,
    range.start.line,
    range.start.character,
    range["end"].line,
    range["end"].character
  )
end

local function add_edit(edits, uri, range)
  local key = loc_key(uri, range)
  if edits[key] then
    return
  end
  edits[key] = { uri = uri, range = range }
end

local function request_sync(client, bufnr, method, params, timeout)
  -- client:request_sync, nicht buf_request_sync: sonst zeigt Neovim -32603 an.
  local ok, resp = pcall(function()
    return client:request_sync(method, params, timeout or 8000, bufnr)
  end)
  if not ok or not resp or resp.err or not resp.result then
    return {}
  end
  if vim.islist(resp.result) then
    return resp.result
  end
  return { resp.result }
end

local function position_params(client, bufnr, row, col)
  return {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = {
      line = row,
      character = vim.lsp.util.character_offset(bufnr, row, col, client.offset_encoding or "utf-16"),
    },
  }
end

local function collect_symbol_positions(symbols, name, out)
  for _, sym in ipairs(symbols or {}) do
    if sym.name == name and (sym.selectionRange or sym.range) then
      out[#out + 1] = sym.selectionRange or sym.range
    end
    if sym.children then
      collect_symbol_positions(sym.children, name, out)
    end
  end
end

local function add_references_from(client, bufnr, params, edits)
  params.context = { includeDeclaration = true }
  for _, loc in ipairs(request_sync(client, bufnr, "textDocument/references", params)) do
    local uri, range = loc_parts(loc)
    if uri then
      add_edit(edits, uri, range)
    end
  end
end

local function add_workspace_symbols(client, bufnr, name, record_name, edits)
  if not record_name then
    return
  end
  for _, item in ipairs(request_sync(client, bufnr, "workspace/symbol", { query = name })) do
    if item.name == name then
      local container = item.containerName or ""
      if container == record_name or container:find(record_name, 1, true) then
        local uri, range = loc_parts(item.location or item)
        if uri then
          add_edit(edits, uri, range)
        end
      end
    end
  end
end

local function apply_edits(client, edits, new_name)
  local changes = {}
  local files, count = {}, 0
  for _, item in pairs(edits) do
    local uri = item.uri
    changes[uri] = changes[uri] or {}
    changes[uri][#changes[uri] + 1] = { range = item.range, newText = new_name }
    files[uri] = true
    count = count + 1
  end
  if count == 0 then
    return 0, 0
  end
  vim.lsp.util.apply_workspace_edit({ changes = changes }, client.offset_encoding or "utf-16")
  return count, vim.tbl_count(files)
end

local function rename_record_component(client, bufnr, node, old_name, new_name)
  local edits = {}
  local uri = vim.uri_from_bufnr(bufnr)
  local record_name = record_type_name(bufnr, node)

  each_identifier(bufnr, old_name, function(id)
    if same_record_symbol(id) or in_record_header(id) then
      add_edit(edits, uri, node_range(client, bufnr, id))
      -- Referenzen nicht vom Header: JDT.LS antwortet dort mit -32603.
      if not in_record_header(id) then
        local row, col = id:start()
        add_references_from(client, bufnr, position_params(client, bufnr, row, col), edits)
      end
    end
  end)

  local symbols = request_sync(client, bufnr, "textDocument/documentSymbol", {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
  })
  local ranges = {}
  collect_symbol_positions(symbols, old_name, ranges)
  for _, range in ipairs(ranges) do
    add_edit(edits, uri, range)
  end

  add_workspace_symbols(client, bufnr, old_name, record_name, edits)

  local count, file_count = apply_edits(client, edits, new_name)
  if count == 0 then
    vim.notify("Keine Stellen zum Umbenennen gefunden", vim.log.levels.WARN, { title = "Rename" })
    return
  end
  vim.notify(
    string.format("%d Stelle(n) in %d Datei(en) umbenannt", count, file_count),
    vim.log.levels.INFO,
    { title = "Rename" }
  )
end

function M.rename()
  local client = require("colejj.java.lsp").client()
  if not client then
    vim.lsp.buf.rename()
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local word = vim.fn.expand("<cword>")
  if word == "" then
    vim.notify("Kein Symbol unter dem Cursor", vim.log.levels.WARN, { title = "Rename" })
    return
  end

  local node = identifier_at_cursor(bufnr)
  local record = node and is_record_symbol(bufnr, node, word)

  vim.ui.input({ prompt = "Neuer Name: ", default = word }, function(new_name)
    if not new_name or new_name == "" or new_name == word then
      return
    end
    if not new_name:match("^[%a_][%w_]*$") then
      vim.notify("Ungültiger Java-Bezeichner", vim.log.levels.ERROR, { title = "Rename" })
      return
    end
    if record then
      rename_record_component(client, bufnr, node, word, new_name)
      return
    end
    vim.lsp.buf.rename(new_name)
  end)
end

return M
