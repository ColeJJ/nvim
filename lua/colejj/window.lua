-- <leader>wz blendet die anderen Splits aus. Das aktuelle Fenster nimmt die
-- ganze Fläche ein. Ein zweites Mal holt das vorherige Layout zurück.
local M = {}

local zoomed = {}

local function normal_windows()
  local wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      wins[#wins + 1] = win
    end
  end
  return wins
end

local function capture_layout(node, current)
  if node[1] == "leaf" then
    local win = node[2]
    return {
      kind = "leaf",
      buf = vim.api.nvim_win_get_buf(win),
      view = vim.api.nvim_win_call(win, vim.fn.winsaveview),
      width = vim.api.nvim_win_get_width(win),
      height = vim.api.nvim_win_get_height(win),
      fixwidth = vim.wo[win].winfixwidth,
      fixheight = vim.wo[win].winfixheight,
      enter = win == current,
    }
  end
  local children = {}
  for _, child in ipairs(node[2]) do
    children[#children + 1] = capture_layout(child, current)
  end
  return { kind = node[1], children = children }
end

local function patch_zoomed_leaf(node)
  if node.kind == "leaf" then
    if node.enter then
      node.buf = vim.api.nvim_get_current_buf()
      node.view = vim.fn.winsaveview()
    end
    return
  end
  for _, child in ipairs(node.children) do
    patch_zoomed_leaf(child)
  end
end

local function prepare_layout(node)
  if node.kind == "leaf" then
    node.win = vim.api.nvim_get_current_win()
    return
  end
  local slots = { vim.api.nvim_get_current_win() }
  for i = 2, #node.children do
    vim.api.nvim_set_current_win(slots[#slots])
    if node.kind == "row" then
      vim.cmd("rightbelow vsplit")
    else
      vim.cmd("rightbelow split")
    end
    slots[i] = vim.api.nvim_get_current_win()
  end
  for i, child in ipairs(node.children) do
    vim.api.nvim_set_current_win(slots[i])
    prepare_layout(child)
  end
end

local function fill_layout(node)
  if node.kind == "leaf" then
    local win = node.win
    if vim.api.nvim_buf_is_valid(node.buf) then
      vim.api.nvim_win_set_buf(win, node.buf)
    end
    vim.api.nvim_win_call(win, function()
      pcall(vim.fn.winrestview, node.view)
    end)
    return
  end
  for _, child in ipairs(node.children) do
    fill_layout(child)
  end
end

local function each_leaf(node, fn)
  if node.kind == "leaf" then
    fn(node)
    return
  end
  for _, child in ipairs(node.children) do
    each_leaf(child, fn)
  end
end

local function apply_sizes(node)
  each_leaf(node, function(leaf)
    if leaf.win and vim.api.nvim_win_is_valid(leaf.win) then
      vim.api.nvim_win_set_width(leaf.win, leaf.width)
      vim.api.nvim_win_set_height(leaf.win, leaf.height)
    end
  end)
end

local function apply_fixes(node)
  each_leaf(node, function(leaf)
    if leaf.win and vim.api.nvim_win_is_valid(leaf.win) then
      vim.wo[leaf.win].winfixwidth = leaf.fixwidth
      vim.wo[leaf.win].winfixheight = leaf.fixheight
    end
  end)
end

local function focus_entered(node)
  each_leaf(node, function(leaf)
    if leaf.enter and leaf.win and vim.api.nvim_win_is_valid(leaf.win) then
      vim.api.nvim_set_current_win(leaf.win)
    end
  end)
end

local function hide_other_windows(current)
  for _, win in ipairs(normal_windows()) do
    if win ~= current and vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_hide, win)
    end
  end
end

local function restore_zoom(snapshot)
  patch_zoomed_leaf(snapshot)
  local current = vim.api.nvim_get_current_win()
  hide_other_windows(current)
  if #normal_windows() ~= 1 then
    return false
  end
  local equalalways = vim.o.equalalways
  vim.o.equalalways = false
  prepare_layout(snapshot)
  fill_layout(snapshot)
  vim.o.equalalways = equalalways
  apply_sizes(snapshot)
  apply_fixes(snapshot)
  focus_entered(snapshot)
  return true
end

function M.zoom()
  local tab = vim.api.nvim_get_current_tabpage()
  if zoomed[tab] then
    if restore_zoom(zoomed[tab]) then
      zoomed[tab] = nil
    end
    return
  end
  local current = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(current).relative ~= "" then
    return
  end
  if #normal_windows() < 2 then
    return
  end
  local snapshot = capture_layout(vim.fn.winlayout(), current)
  hide_other_windows(current)
  if #normal_windows() == 1 then
    zoomed[tab] = snapshot
  end
end

vim.api.nvim_create_autocmd("TabClosed", {
  group = vim.api.nvim_create_augroup("colejj-win-zoom", { clear = true }),
  callback = function()
    for tab in pairs(zoomed) do
      if not vim.api.nvim_tabpage_is_valid(tab) then
        zoomed[tab] = nil
      end
    end
  end,
})

return M
