local M = {}

local buf
local win
local job
local run_id = 0

local function valid_buf()
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function valid_win()
  return win and vim.api.nvim_win_is_valid(win)
end

-- Fester Name ohne /bin/ und target/, sonst verschwindet der Buffer aus <leader>bl.
local function publish(term_buf, title)
  if not vim.api.nvim_buf_is_valid(term_buf) then
    return
  end
  local name = (title or "Java Run"):gsub("[\\/%z]", " ")
  local path = "/colejj/" .. name
  if not pcall(vim.api.nvim_buf_set_name, term_buf, path) then
    pcall(vim.api.nvim_buf_set_name, term_buf, path .. " " .. term_buf)
  end
  vim.bo[term_buf].buflisted = true
  vim.bo[term_buf].bufhidden = "hide"
end

local function string_env(env)
  if type(env) ~= "table" then
    return nil
  end
  local out = {}
  for key, value in pairs(env) do
    if type(key) == "string" and value ~= nil then
      out[key] = tostring(value)
    end
  end
  if next(out) then
    return out
  end
end

function M.stop()
  run_id = run_id + 1
  if job and vim.fn.jobwait({ job }, 0)[1] == -1 then
    pcall(vim.fn.jobstop, job)
  end
  job = nil
end

local function prepare_window(title)
  local old_buf = valid_buf() and buf or nil
  local old_win = valid_win() and win or nil

  buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].buflisted = true
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false

  if old_win then
    pcall(vim.api.nvim_win_set_buf, old_win, buf)
    pcall(vim.api.nvim_set_current_win, old_win)
    win = old_win
  else
    vim.cmd("botright vsplit")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
  end
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_current_buf(buf)
  vim.cmd("wincmd L")
  win = vim.api.nvim_get_current_win()

  if old_buf and old_buf ~= buf and vim.api.nvim_buf_is_valid(old_buf) then
    pcall(vim.api.nvim_buf_delete, old_buf, { force = true })
  end

  -- jobstart überschreibt den Namen mit term://…/bin/java …/target/….
  -- Telescope filtert genau /bin/ und target/ aus der Buffer-Liste.
  publish(buf, title)
  vim.wo[win].winfixwidth = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"

  vim.keymap.set("n", "q", function()
    if valid_win() then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, silent = true, desc = "Run-Fenster schließen" })

  return buf, win
end

local function start_job(opts, id)
  local cmd = opts.cmd
  if type(cmd) ~= "table" or not cmd[1] then
    vim.notify("Kein Start-Kommando", vim.log.levels.ERROR, { title = "colejj.java" })
    return
  end

  prepare_window(opts.title or "Java Run")
  local term_buf = buf
  local finished = false

  local function finish(code)
    if finished or id ~= run_id then
      return
    end
    finished = true
    if opts.on_exit then
      opts.on_exit(tonumber(code) or code or 0)
    end
  end

  -- jobstart({term=true}) ruft on_exit unter 0.12 oft nicht auf.
  -- TermClose ist für Terminal-Jobs der verlässliche Hook.
  vim.api.nvim_create_autocmd("TermOpen", {
    buffer = term_buf,
    once = true,
    callback = function()
      publish(term_buf, opts.title)
    end,
  })

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = term_buf,
    once = true,
    callback = function()
      local code = vim.v.event and vim.v.event.status or 0
      vim.schedule(function()
        finish(code)
      end)
    end,
  })

  local job_opts = {
    cwd = opts.cwd,
    term = true,
    on_exit = function(_, code)
      vim.schedule(function()
        finish(code)
      end)
    end,
  }
  if opts.on_output then
    job_opts.on_stdout = function(_, data)
      if id == run_id and data then
        opts.on_output(data)
      end
    end
  end
  local env = string_env(opts.env)
  if env then
    job_opts.env = env
  end

  job = vim.fn.jobstart(cmd, job_opts)
  if type(job) ~= "number" or job <= 0 then
    vim.notify(
      "Start fehlgeschlagen (jobstart=" .. tostring(job) .. ")",
      vim.log.levels.ERROR,
      { title = "colejj.java" }
    )
    job = nil
    finish(1)
    return
  end
end

function M.ensure(title)
  return prepare_window(title)
end

function M.run(opts)
  opts = opts or {}
  M.stop()
  local id = run_id
  vim.defer_fn(function()
    if id ~= run_id then
      return
    end
    start_job(opts, id)
  end, 40)
end

function M.job()
  return job
end

function M.buf()
  return buf
end

function M.win()
  return win
end

return M
