-- Rose Pine main wie ThePrimeagen:
-- https://github.com/ThePrimeagen/init.lua/blob/249f3b14cc517202c80c6babd0f9ec548351ec71/after/plugin/colors.lua

local M = {}

local function is_main(name)
  name = name or vim.g.colors_name
  return name == "rose-pine" or name == "rose-pine-main"
end

function M.transparent()
  if not is_main() then
    return
  end
  vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
  vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
end

function M.setup()
  require("rose-pine").setup({
    variant = "main",
    dark_variant = "main",
    disable_background = true,
    dim_inactive_windows = false,
    styles = {
      bold = true,
      italic = true,
      transparency = true,
    },
  })
end

function M.apply(color)
  M.setup()
  color = color or "rose-pine"
  vim.cmd.colorscheme(color)
  M.transparent()
end

function M.setup_autocmd()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("colejj-rosepine-primeagen", { clear = true }),
    pattern = { "rose-pine", "rose-pine-main" },
    callback = function()
      vim.schedule(M.transparent)
    end,
  })
end

return M
