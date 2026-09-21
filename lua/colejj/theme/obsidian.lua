local M = {}

function M.apply()
  vim.cmd.colorscheme("custom-obsidian")
end

-- Treesitter/LSP setzen nach ColorScheme Default-Gruppen; ohne hi clear nachziehen.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("colejj-obsidian-reinforce", { clear = true }),
  pattern = "custom-obsidian",
  callback = function()
    vim.schedule(function()
      if vim.g.colors_name == "custom-obsidian" then
        vim.g.custom_obsidian_skip_clear = true
        vim.cmd.runtime("colors/custom-obsidian.lua")
        vim.g.custom_obsidian_skip_clear = nil
      end
    end)
  end,
})

return M

