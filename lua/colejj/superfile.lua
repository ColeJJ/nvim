-- Superfile im schwebenden Terminal, analog zu LazyGit.
-- `e` schreibt den Pfad nach `--chooser-file` und beendet superfile.
-- Danach öffnet Neovim die Datei im Fenster, das darunter lag.
local M = {}

local float_win, float_buf, prev_win

local function close_float()
  if float_win and vim.api.nvim_win_is_valid(float_win) then
    pcall(vim.api.nvim_win_close, float_win, true)
  end
  if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
    pcall(vim.api.nvim_buf_delete, float_buf, { force = true })
  end
  float_win, float_buf = nil, nil
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
  vim.bo[buf].filetype = "superfile"
  vim.wo[win].cursorcolumn = false
  vim.wo[win].signcolumn = "no"
  vim.api.nvim_set_hl(0, "LazyGitBorder", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "LazyGitFloat", { link = "Normal", default = true })
  vim.wo[win].winhl = "FloatBorder:LazyGitBorder,NormalFloat:LazyGitFloat"
  vim.wo[win].winblend = vim.g.lazygit_floating_window_winblend or 0
  return win, buf
end

local function start_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= "" and vim.bo.buftype == "" then
    local dir = vim.fn.fnamemodify(name, ":p:h")
    if vim.fn.isdirectory(dir) == 1 then
      return dir
    end
  end
  return vim.fn.getcwd()
end

local function open_picked(path, win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
  if path == "" then
    return
  end
  if vim.fn.isdirectory(path) == 1 then
    require("oil").open(path)
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
end

function M.open()
  if vim.fn.executable("spf") ~= 1 then
    vim.notify("superfile nicht gefunden. Homebrew: brew install superfile", vim.log.levels.ERROR, {
      title = "superfile",
    })
    return
  end

  close_float()
  prev_win = vim.api.nvim_get_current_win()
  local pick = vim.fn.tempname()
  local cwd = start_dir()
  float_win, float_buf = open_float()

  vim.api.nvim_create_autocmd("TermOpen", {
    buffer = float_buf,
    once = true,
    callback = function()
      if float_win and vim.api.nvim_win_is_valid(float_win) then
        vim.api.nvim_set_current_win(float_win)
      end
      vim.cmd("startinsert!")
    end,
  })
  vim.keymap.set("n", "i", "i", { buffer = float_buf, silent = true })
  vim.keymap.set("n", "<Esc>", "i", { buffer = float_buf, silent = true, desc = "Zurück zu Superfile" })

  vim.fn.jobstart({ "spf", "--chooser-file", pick, cwd }, {
    term = true,
    cwd = cwd,
    on_exit = function()
      vim.schedule(function()
        local target = prev_win
        prev_win = nil
        close_float()
        local lines = {}
        if vim.fn.filereadable(pick) == 1 then
          lines = vim.fn.readfile(pick)
          vim.fn.delete(pick)
        end
        open_picked(vim.trim(lines[1] or ""), target)
      end)
    end,
  })

  vim.schedule(function()
    if float_win and vim.api.nvim_win_is_valid(float_win) then
      vim.api.nvim_set_current_win(float_win)
      vim.cmd("startinsert!")
    end
  end)
end

return M
