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

local highlights_ready = false

local function define_highlights()
  if highlights_ready then
    return
  end
  highlights_ready = true
  local link = function(name, target)
    vim.api.nvim_set_hl(0, name, { link = target, default = true })
  end
  link("JavaRunError", "DiagnosticError")
  link("JavaRunWarn", "DiagnosticWarn")
  link("JavaRunInfo", "DiagnosticInfo")
  link("JavaRunDebug", "Comment")
  link("JavaRunStack", "DiagnosticError")
end

local function apply_syntax(target)
  define_highlights()
  vim.bo[target].filetype = "java-run"
  vim.api.nvim_buf_call(target, function()
    vim.cmd([[
      syntax enable
      syntax clear
      syntax case match
      syntax match JavaRunDebug /\<\%(DEBUG\|TRACE\)\>/
      syntax match JavaRunInfo /\<INFO\>/
      syntax match JavaRunWarn /\<WARN\%(ING\)\?\>/
      syntax match JavaRunError /\<\%(ERROR\|FATAL\)\>/
      syntax match JavaRunStack /^\s\+at\s.*/
      syntax match JavaRunStack /^\s\+\.\.\. \d\+ more\>/
      syntax match JavaRunError /^\%(Caused by:\|Suppressed:\).*/
      syntax match JavaRunError /^[A-Za-z0-9_$.][A-Za-z0-9_$.]*\%(Exception\|Error\|Throwable\)\>.*/
    ]])
  end)
end

local function strip_ansi(line)
  line = line:gsub("\27%][^\7]*\7", "")
  line = line:gsub("\27%[[%d:;?]*[A-Za-z]", "")
  line = line:gsub("\r", "")
  return line
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
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

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
  local out_buf = buf
  local finished = false
  local pending = ""
  vim.bo[out_buf].buftype = "nofile"
  vim.bo[out_buf].modifiable = false
  vim.bo[out_buf].undolevels = -1
  apply_syntax(out_buf)

  local function append(lines)
    if id ~= run_id or #lines == 0 or not vim.api.nvim_buf_is_valid(out_buf) then
      return
    end
    local count = vim.api.nvim_buf_line_count(out_buf)
    local stick = true
    if valid_win() and vim.api.nvim_win_get_buf(win) == out_buf then
      stick = vim.api.nvim_win_get_cursor(win)[1] >= count - 1
    end
    local replace_blank = count == 1 and vim.api.nvim_buf_get_lines(out_buf, 0, 1, false)[1] == ""
    vim.bo[out_buf].modifiable = true
    vim.api.nvim_buf_set_lines(out_buf, replace_blank and 0 or -1, -1, false, lines)
    vim.bo[out_buf].modifiable = false
    if stick and valid_win() and vim.api.nvim_win_get_buf(win) == out_buf then
      pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(out_buf), 0 })
    end
  end

  local function consume(data, flush)
    if id ~= run_id or type(data) ~= "table" then
      return {}
    end
    if #data == 0 then
      return {}
    end
    data[1] = pending .. data[1]
    if flush then
      pending = ""
    else
      pending = data[#data]
      data[#data] = nil
    end
    local lines = {}
    for _, line in ipairs(data) do
      lines[#lines + 1] = strip_ansi(line)
    end
    return lines
  end

  local function finish(code)
    if finished or id ~= run_id then
      return
    end
    finished = true
    if pending ~= "" then
      local rest = pending
      pending = ""
      append({ strip_ansi(rest) })
    end
    if opts.on_exit then
      opts.on_exit(tonumber(code) or code or 0)
    end
  end

  local job_opts = {
    cwd = opts.cwd,
    pty = true,
    width = valid_win() and math.max(vim.api.nvim_win_get_width(win), 80) or 120,
    height = valid_win() and math.max(vim.api.nvim_win_get_height(win), 20) or 40,
    on_stdout = function(_, data)
      if id ~= run_id then
        return
      end
      local lines = consume(data, false)
      append(lines)
      if opts.on_output and #lines > 0 then
        opts.on_output(lines)
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        finish(code)
      end)
    end,
  }
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
