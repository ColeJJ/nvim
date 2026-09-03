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

function M.open(cmd)
  M.remember()
  vim.cmd(cmd or "DiffviewOpen")
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
