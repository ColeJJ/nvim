--[[
Implements helpers for the current Java type under the cursor.
--]]

local M = {}

local function ts_utils()
  local ok, mod = pcall(require, "nvim-treesitter.ts_utils")
  if ok then
    return mod
  end
end

local function find_node_by_type(expr, type_name)
  while expr do
    if expr:type() == type_name then
      break
    end
    expr = expr:parent()
  end
  return expr
end

local function find_child_by_type(expr, type_name)
  local id = 0
  local expr_child = expr:child(id)
  while expr_child do
    if expr_child:type() == type_name then
      break
    end
    id = id + 1
    expr_child = expr:child(id)
  end
  return expr_child
end

local function node_text(node)
  return vim.treesitter.get_node_text(node, 0)
end

function M.get_current_method_name()
  local ts = ts_utils()
  if not ts then
    return nil
  end
  local current_node = ts.get_node_at_cursor()
  if not current_node then
    return nil
  end
  local expr = find_node_by_type(current_node, "method_declaration")
  if not expr then
    return nil
  end
  local child = find_child_by_type(expr, "identifier")
  if not child then
    return nil
  end
  return node_text(child)
end

function M.get_current_class_name()
  local ts = ts_utils()
  if not ts then
    return nil
  end
  local current_node = ts.get_node_at_cursor()
  if not current_node then
    return nil
  end
  local class_declaration = find_node_by_type(current_node, "class_declaration")
  if not class_declaration then
    return nil
  end
  local child = find_child_by_type(class_declaration, "identifier")
  if not child then
    return nil
  end
  return node_text(child)
end

function M.get_current_package_name()
  local ts = ts_utils()
  if not ts then
    return nil
  end
  local current_node = ts.get_node_at_cursor()
  if not current_node then
    return nil
  end
  local program_expr = find_node_by_type(current_node, "program")
  if not program_expr then
    return nil
  end
  local package_expr = find_child_by_type(program_expr, "package_declaration")
  if not package_expr then
    return nil
  end
  local child = find_child_by_type(package_expr, "scoped_identifier")
  if not child then
    return nil
  end
  return node_text(child)
end

function M.get_current_full_class_name()
  local package = M.get_current_package_name()
  local class = M.get_current_class_name()
  if not class then
    return nil
  end
  if not package then
    return class
  end
  return package .. "." .. class
end

function M.visual_selection()
  local mode = vim.fn.mode()
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")
  if not mode:find("[vV\22]") then
    start_pos = vim.fn.getpos("'<")
    end_pos = vim.fn.getpos("'>")
    mode = vim.fn.visualmode() or "v"
  end
  local start_row, start_col = start_pos[2], start_pos[3]
  local end_row, end_col = end_pos[2], end_pos[3]
  if start_row == 0 or end_row == 0 then
    return ""
  end
  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end
  if mode == "V" then
    return table.concat(vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false), "\n")
  end
  if mode == "\22" then
    local left, right = math.min(start_col, end_col), math.max(start_col, end_col)
    local chunks = {}
    for row = start_row, end_row do
      local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
      chunks[#chunks + 1] = line:sub(left, right)
    end
    return table.concat(chunks, "\n")
  end
  return table.concat(vim.api.nvim_buf_get_text(0, start_row - 1, start_col - 1, end_row - 1, end_col, {}), "\n")
end

function M.visual_search_text()
  if not vim.fn.mode():find("[vV\22]") then
    return nil
  end
  local text = vim.trim(M.visual_selection():gsub("[\n\r]+", " "))
  if text == "" then
    return nil
  end
  return text
end

function M.search_text()
  return M.visual_search_text() or vim.fn.expand("<cword>")
end

function M.get_current_full_method_name(delimiter)
  delimiter = delimiter or "."
  local full_class_name = M.get_current_full_class_name()
  local method_name = M.get_current_method_name()
  if not full_class_name or not method_name then
    return nil
  end
  return full_class_name .. delimiter .. method_name
end

return M
