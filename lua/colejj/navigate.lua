-- Methode/Klasse springen wie IntelliJ, mit Repeat über `n`.
-- Eigenes Treesitter-Walking: nvim-treesitter-textobjects ist unter 0.12 unzuverlässig.

local M = {}

local ns = vim.api.nvim_create_augroup("colejj-navigate", { clear = true })
local repeating = false
local forward = true

local NODE_TYPES = {
  java = {
    method_declaration = true,
    constructor_declaration = true,
    class_declaration = true,
    interface_declaration = true,
    enum_declaration = true,
    record_declaration = true,
    annotation_type_declaration = true,
  },
  kotlin = {
    function_declaration = true,
    class_declaration = true,
    object_declaration = true,
    companion_object = true,
  },
  lua = {
    function_declaration = true,
    function_definition = true,
  },
  javascript = {
    function_declaration = true,
    function_expression = true,
    method_definition = true,
    class_declaration = true,
  },
  typescript = {
    function_declaration = true,
    function_expression = true,
    method_definition = true,
    class_declaration = true,
  },
  xml = {
    element = true,
  },
  html = {
    element = true,
  },
}

NODE_TYPES.tsx = NODE_TYPES.typescript
NODE_TYPES.jsx = NODE_TYPES.javascript

local NAME_TYPES = {
  identifier = true,
  simple_identifier = true,
  type_identifier = true,
}

local function target_pos(node)
  for child, _ in node:iter_children() do
    if NAME_TYPES[child:type()] then
      local row, col = child:start()
      return row, col
    end
  end
  local row, col = node:start()
  return row, col
end

local function collect(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return {}
  end
  parser:parse()
  local lang = parser:lang()
  local types = NODE_TYPES[lang]
  if not types then
    return {}
  end

  local items = {}
  local function walk(node)
    if types[node:type()] then
      local row, col = target_pos(node)
      items[#items + 1] = { row = row, col = col }
    end
    for child in node:iter_children() do
      walk(child)
    end
  end

  for _, tree in ipairs(parser:trees()) do
    walk(tree:root())
  end

  table.sort(items, function(a, b)
    if a.row == b.row then
      return a.col < b.col
    end
    return a.row < b.row
  end)
  return items
end

local function jump(dir)
  local bufnr = vim.api.nvim_get_current_buf()
  local items = collect(bufnr)
  if #items == 0 then
    vim.notify("Keine Methode/Klasse zum Springen gefunden", vim.log.levels.INFO)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  local dest

  if dir then
    for _, item in ipairs(items) do
      if item.row > row or (item.row == row and item.col > col) then
        dest = item
        break
      end
    end
    dest = dest or items[1]
  else
    for i = #items, 1, -1 do
      local item = items[i]
      if item.row < row or (item.row == row and item.col < col) then
        dest = item
        break
      end
    end
    dest = dest or items[#items]
  end

  if dest then
    vim.api.nvim_win_set_cursor(0, { dest.row + 1, dest.col })
  end
end

local function stop()
  if not repeating then
    return
  end
  repeating = false
  pcall(vim.keymap.del, "n", "n", { buffer = 0 })
  pcall(vim.keymap.del, "n", "N", { buffer = 0 })
  pcall(vim.keymap.del, "n", "<Esc>", { buffer = 0 })
end

local function start(dir)
  forward = dir
  jump(dir)
  if repeating then
    return
  end
  repeating = true

  vim.keymap.set("n", "n", function()
    jump(forward)
  end, { buffer = true, nowait = true, silent = true, desc = "Nächste Methode/Klasse" })
  vim.keymap.set("n", "N", function()
    jump(not forward)
  end, { buffer = true, nowait = true, silent = true, desc = "Methode/Klasse Gegenrichtung" })
  vim.keymap.set("n", "<Esc>", function()
    stop()
  end, { buffer = true, nowait = true, silent = true, desc = "Navigation beenden" })

  vim.api.nvim_create_autocmd({ "InsertEnter", "BufLeave" }, {
    group = ns,
    buffer = 0,
    once = true,
    callback = stop,
  })
end

function M.next()
  start(true)
end

function M.prev()
  start(false)
end

function M.setup()
  vim.keymap.set("n", "<leader>cn", M.next, { desc = "Nächste Methode/Klasse" })
  vim.keymap.set("n", "<leader>cN", M.prev, { desc = "Vorherige Methode/Klasse" })
end

return M
