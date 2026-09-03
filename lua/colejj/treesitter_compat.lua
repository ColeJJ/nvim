-- Neovim 0.12 übergibt bei Query-Directives `TSNode[]` pro Capture.
-- nvim-treesitter master erwartet noch einen einzelnen Node → Hover-Markdown
-- (fenced code) crasht in get_node_text / node:range.

local M = {}

local function first_node(match, id)
  local node = match[id]
  if type(node) == "table" and type(node.range) ~= "function" then
    node = node[1]
  end
  if node and type(node.range) == "function" then
    return node
  end
end

function M.setup()
  local query = vim.treesitter.query
  local opts = { force = true, all = false }

  local aliases = {
    ex = "elixir",
    pl = "perl",
    sh = "bash",
    ts = "typescript",
  }

  query.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
    local node = first_node(match, pred[2])
    if not node then
      return
    end
    local alias = vim.treesitter.get_node_text(node, bufnr):lower()
    metadata["injection.language"] = vim.filetype.match({ filename = "a." .. alias }) or aliases[alias] or alias
  end, opts)

  query.add_directive("set-lang-from-mimetype!", function(match, _, bufnr, pred, metadata)
    local node = first_node(match, pred[2])
    if not node then
      return
    end
    local value = vim.treesitter.get_node_text(node, bufnr)
    metadata["injection.language"] = value:match("/(.+)$") or value
  end, opts)

  query.add_directive("downcase!", function(match, _, bufnr, pred, metadata)
    local id = pred[2]
    local node = first_node(match, id)
    if not node then
      return
    end
    local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[id] }) or ""
    metadata[id] = metadata[id] or {}
    metadata[id].text = string.lower(text)
  end, opts)

  query.add_predicate("nth?", function(match, _, _, pred)
    local node = first_node(match, pred[2])
    local n = tonumber(pred[3])
    if node and node:parent() and n and node:parent():named_child_count() > n then
      return node:parent():named_child(n) == node
    end
    return false
  end, opts)

  query.add_predicate("kind-eq?", function(match, _, _, pred)
    local node = first_node(match, pred[2])
    if not node then
      return true
    end
    return vim.list_contains({ unpack(pred, 3) }, node:type())
  end, opts)
end

return M
