local M = {}

local buf
local win
local job

local function valid_buf()
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function valid_win()
  return win and vim.api.nvim_win_is_valid(win)
end

function M.ensure(title)
  title = title or "Java Run"
  if valid_buf() then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    buf = nil
  end
  buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].buflisted = true
  pcall(vim.api.nvim_buf_set_name, buf, title)

  if not valid_win() then
    vim.cmd("botright 15split")
    win = vim.api.nvim_get_current_win()
  else
    vim.api.nvim_set_current_win(win)
  end
  vim.api.nvim_win_set_buf(win, buf)
  vim.wo[win].winfixheight = true
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

function M.stop()
  if job and vim.fn.jobwait({ job }, 0)[1] == -1 then
    pcall(vim.fn.jobstop, job)
  end
  job = nil
end

function M.run(opts)
  opts = opts or {}
  local cmd = opts.cmd
  if type(cmd) == "table" then
    cmd = table.concat(vim.tbl_map(vim.fn.shellescape, cmd), " ")
  end
  if not cmd or cmd == "" then
    return
  end

  M.stop()
  M.ensure(opts.title or "Java Run")
  vim.bo[buf].modifiable = true

  job = vim.fn.termopen(cmd, {
    cwd = opts.cwd,
    env = opts.env,
    on_exit = function(_, code)
      vim.schedule(function()
        if opts.on_exit then
          opts.on_exit(code)
        end
      end)
    end,
  })

  if valid_win() then
    vim.cmd("normal! G")
  end
  return job
end

function M.job()
  return job
end

function M.buf()
  return buf
end

return M
