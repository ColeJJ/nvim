local tools = require("dbee.layouts.tools")
local api_ui = require("dbee.api.ui")
local utils = require("dbee.utils")

local M = {}

local Layout = {}

function Layout:new(opts)
  opts = opts or {}
  local o = {
    egg = nil,
    windows = {},
    on_switch = opts.on_switch or "immutable",
    is_opened = false,
    drawer_width = opts.drawer_width or 40,
    call_log_height = opts.call_log_height or 8,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Layout:configure_window_on_switch(winid, open_fn)
  utils.create_singleton_autocmd({ "BufWinEnter", "BufReadPost", "BufNewFile" }, {
    window = winid,
    callback = function()
      if self.on_switch == "close" then
        self:close()
      else
        open_fn(winid)
      end
    end,
  })
end

function Layout:configure_window_on_quit(winid)
  utils.create_singleton_autocmd({ "QuitPre" }, {
    window = winid,
    callback = function()
      self:close()
    end,
  })
end

function Layout:is_open()
  return self.is_opened
end

function Layout:open()
  self.egg = tools.save()
  self.windows = {}

  tools.make_only(0)
  local result_win = vim.api.nvim_get_current_win()
  self.windows.result = result_win
  api_ui.result_show(result_win)
  self:configure_window_on_switch(result_win, api_ui.result_show)
  self:configure_window_on_quit(result_win)

  vim.cmd("topleft " .. self.drawer_width .. "vsplit")
  local drawer_win = vim.api.nvim_get_current_win()
  self.windows.drawer = drawer_win
  api_ui.drawer_show(drawer_win)
  self:configure_window_on_switch(drawer_win, api_ui.drawer_show)
  self:configure_window_on_quit(drawer_win)

  vim.cmd("belowright " .. self.call_log_height .. "split")
  local log_win = vim.api.nvim_get_current_win()
  self.windows.call_log = log_win
  api_ui.call_log_show(log_win)
  self:configure_window_on_switch(log_win, api_ui.call_log_show)
  self:configure_window_on_quit(log_win)

  vim.api.nvim_set_current_win(result_win)
  self.is_opened = true
end

function Layout:reset()
  if self.windows.drawer and vim.api.nvim_win_is_valid(self.windows.drawer) then
    vim.api.nvim_win_set_width(self.windows.drawer, self.drawer_width)
  end
  if self.windows.call_log and vim.api.nvim_win_is_valid(self.windows.call_log) then
    vim.api.nvim_win_set_height(self.windows.call_log, self.call_log_height)
  end
end

function Layout:close()
  for _, win in pairs(self.windows) do
    pcall(vim.api.nvim_win_close, win, false)
  end
  tools.restore(self.egg)
  self.egg = nil
  self.is_opened = false
end

function M.new(opts)
  return Layout:new(opts)
end

return M
