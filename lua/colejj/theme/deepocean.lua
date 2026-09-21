local M = {}

function M.apply()
  vim.cmd.colorscheme("material-deep-ocean")
end

-- Treesitter/LSP setzen nach ColorScheme Default-Gruppen; ohne hi clear nachziehen.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("colejj-deepocean-reinforce", { clear = true }),
  pattern = "material-deep-ocean",
  callback = function()
    vim.schedule(function()
      if vim.g.colors_name == "material-deep-ocean" then
        vim.g.material_deep_ocean_skip_clear = true
        vim.cmd.runtime("colors/material-deep-ocean.lua")
        vim.g.material_deep_ocean_skip_clear = nil
      end
    end)
  end,
})

return M
