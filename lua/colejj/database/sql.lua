-- SQL am Cursor: visuelle Auswahl oder Semikolon-Statement, analog zu Doom.

local M = {}

local function statement_from_text(lines, row, col)
  local text = table.concat(lines, "\n")
  if text == "" then
    return nil
  end
  local offset = 0
  for i = 1, row - 1 do
    offset = offset + #lines[i] + 1
  end
  offset = offset + math.max(col, 1)
  offset = math.min(offset, #text + 1)
  while offset > 1 and text:sub(offset - 1, offset - 1):match("%s") do
    offset = offset - 1
  end
  local at_semi = offset > 1 and text:sub(offset - 1, offset - 1) == ";"
  local finish = at_semi and (offset - 1) or (text:find(";", offset, true) or #text)
  local start = 1
  local search_from = at_semi and (offset - 2) or (offset - 1)
  if search_from > 0 then
    local prefix = text:sub(1, search_from)
    local last_semi = prefix:match(".*();")
    if type(last_semi) == "number" then
      start = last_semi + 1
    end
  end
  local snippet = vim.trim(text:sub(start, finish))
  if snippet == "" then
    return nil
  end
  local before = text:sub(1, start)
  local lnum = select(2, before:gsub("\n", "\n")) + 1
  local after = text:sub(1, finish)
  local end_lnum = select(2, after:gsub("\n", "\n")) + 1
  return snippet, lnum, end_lnum
end

local function statement_from_treesitter(bufnr, row, col)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row - 1, col } })
  if not ok or not node then
    return nil
  end
  local current = node
  while current do
    if current:type():find("statement", 1, true) then
      local sr, _, er = current:range()
      local text_ok, text = pcall(vim.treesitter.get_node_text, current, bufnr)
      if text_ok and text and vim.trim(text) ~= "" then
        return vim.trim(text), sr + 1, er + 1
      end
    end
    current = current:parent()
  end
end

function M.at_point()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]
  local ts_text, ts_s, ts_e = statement_from_treesitter(bufnr, row, col)
  if ts_text and ts_text ~= "" then
    return ts_text, ts_s, ts_e
  end
  return statement_from_text(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), row, col)
end

function M.selection_or_statement()
  local mode = vim.fn.mode()
  if mode:find("[vV\22]") then
    local pos1 = vim.fn.getpos("v")
    local pos2 = vim.fn.getpos(".")
    local srow, erow = pos1[2], pos2[2]
    if srow > erow then
      srow, erow = erow, srow
    end
    local lines = vim.api.nvim_buf_get_lines(0, srow - 1, erow, false)
    return vim.trim(table.concat(lines, "\n")), srow, erow
  end
  return M.at_point()
end

return M
