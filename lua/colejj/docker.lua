local M = {}

local prev_win
local float_win
local float_buf

local function config_file()
  return vim.fn.stdpath("config") .. "/lazydocker.yml"
end

--- LazyDocker hat kein `-ucf`; es liest `config.yml` aus `CONFIG_DIR`.
local function config_dir()
  local src = config_file()
  if vim.uv.fs_stat(src) == nil then
    vim.notify("lazydocker.yml fehlt unter " .. src, vim.log.levels.WARN, { title = "Docker" })
  end
  local dir = vim.fn.stdpath("cache") .. "/colejj-lazydocker"
  vim.fn.mkdir(dir, "p")
  local link = dir .. "/config.yml"
  local target = vim.uv.fs_readlink(link)
  if target ~= src then
    if target or vim.uv.fs_stat(link) then
      vim.uv.fs_unlink(link)
    end
    vim.uv.fs_symlink(src, link)
  end
  return dir
end

local function open_float()
  local scale = vim.g.lazygit_floating_window_scaling_factor or 0.9
  if type(scale) == "table" then
    scale = scale[false] or 0.9
  end
  local height = math.ceil(vim.o.lines * scale) - 1
  local width = math.ceil(vim.o.columns * scale)
  local row = math.ceil((vim.o.lines - height) / 2)
  local col = math.ceil((vim.o.columns - width) / 2)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    style = "minimal",
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = vim.g.lazygit_floating_window_border_chars or "rounded",
  })
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "lazydocker"
  vim.wo[win].cursorcolumn = false
  vim.wo[win].signcolumn = "no"
  vim.api.nvim_set_hl(0, "LazyGitBorder", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "LazyGitFloat", { link = "Normal", default = true })
  vim.wo[win].winhl = "FloatBorder:LazyGitBorder,NormalFloat:LazyGitFloat"
  vim.wo[win].winblend = vim.g.lazygit_floating_window_winblend or 0
  return win, buf
end

function M.open()
  if float_win and vim.api.nvim_win_is_valid(float_win) then
    vim.api.nvim_set_current_win(float_win)
    vim.cmd("startinsert")
    return
  end

  if vim.fn.executable("lazydocker") ~= 1 then
    vim.notify("lazydocker nicht gefunden. Homebrew: brew install lazydocker", vim.log.levels.ERROR, {
      title = "Docker",
    })
    return
  end

  prev_win = vim.api.nvim_get_current_win()
  float_win, float_buf = open_float()
  local cwd = require("colejj.project").project_root()
  vim.fn.jobstart({ "lazydocker" }, {
    term = true,
    cwd = cwd,
    env = { CONFIG_DIR = config_dir() },
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 and code ~= 130 then
          vim.notify("lazydocker beendet mit Code " .. tostring(code), vim.log.levels.WARN, { title = "Docker" })
        end
        if float_win and vim.api.nvim_win_is_valid(float_win) then
          vim.api.nvim_win_close(float_win, true)
        end
        if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
          pcall(vim.api.nvim_buf_delete, float_buf, { force = true })
        end
        if prev_win and vim.api.nvim_win_is_valid(prev_win) then
          vim.api.nvim_set_current_win(prev_win)
        end
        float_win, float_buf, prev_win = nil, nil, nil
      end)
    end,
  })
  vim.cmd("startinsert")
end

return M
