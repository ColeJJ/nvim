local M = {}

local origin

function M.snapshot()
  return {
    file = vim.api.nvim_buf_get_name(0),
    pos = vim.api.nvim_win_get_cursor(0),
    view = vim.fn.winsaveview(),
  }
end

function M.set_origin(saved)
  origin = saved
end

function M.remember()
  origin = M.snapshot()
end

function M.restore()
  local saved = origin
  origin = nil
  if not saved then
    return
  end
  vim.schedule(function()
    if saved.file == "" or vim.fn.filereadable(saved.file) ~= 1 then
      return
    end
    pcall(function()
      require("colejj.git.blame").disable(0, { skip_restore = true })
    end)
    vim.cmd.edit(vim.fn.fnameescape(saved.file))
    pcall(vim.fn.winrestview, saved.view)
    pcall(vim.api.nvim_win_set_cursor, 0, saved.pos)
    vim.cmd.normal({ "zv", bang = true })
  end)
end

local function git_line(args)
  local root = require("colejj.project").git_root()
  if not root then
    return nil
  end
  local cmd = { "git", "-C", root }
  vim.list_extend(cmd, args)
  local out = vim.fn.systemlist(cmd)
  local line = out[1]
  if vim.v.shell_error ~= 0 or not line or line == "" or line:find("^fatal:") then
    return nil
  end
  return vim.trim(line)
end

--- Nächstliegender Abzweigpunkt wie Doom `+git/base-branch`:
--- Kandidaten develop/master/main (lokal, sonst origin/...), jüngster Merge-Base.
function M.base_rev()
  local current = git_line({ "rev-parse", "--abbrev-ref", "HEAD" })
  local refs = {}
  for _, name in ipairs({ "develop", "master", "main" }) do
    if name ~= current then
      if git_line({ "rev-parse", "--verify", "--quiet", "refs/heads/" .. name }) then
        refs[#refs + 1] = name
      elseif git_line({ "rev-parse", "--verify", "--quiet", "refs/remotes/origin/" .. name }) then
        refs[#refs + 1] = "origin/" .. name
      end
    end
  end
  local best_sha, best_ref, best_ts
  for _, ref in ipairs(refs) do
    local sha = git_line({ "merge-base", "HEAD", ref })
    if sha and sha:match("^%x+$") then
      local ts = tonumber(git_line({ "show", "-s", "--format=%ct", sha }) or "")
      if ts and (not best_ts or ts > best_ts) then
        best_sha, best_ref, best_ts = sha, ref, ts
      end
    end
  end
  return best_sha, best_ref
end

function M.open(cmd)
  M.remember()
  vim.cmd(cmd or "DiffviewOpen")
end

function M.open_against_base()
  local sha = M.base_rev()
  if not sha then
    vim.notify("Kein Basis-Branch gefunden (develop, master, main).", vim.log.levels.WARN, {
      title = "Git",
    })
    M.open("DiffviewOpen")
    return
  end
  M.open("DiffviewOpen " .. sha)
end

function M.opts()
  local close = { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Diffview schließen" } }
  return {
    hooks = {
      view_closed = M.restore,
    },
    keymaps = {
      view = { close },
      file_panel = { close },
      file_history_panel = { close },
    },
  }
end

return M
