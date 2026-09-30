-- TJ DeVries startet mit `colorscheme gruvbuddy`.
-- config.nvim lädt colorbuddy.nvim und setzt nur dieses Scheme:
-- https://github.com/tjdevries/config.nvim/blob/37c9356fd40a8d3589638c8d16a6a6b1274c40ca/lua/custom/plugins/colorschemes.lua
-- Die Farben stehen in colorbuddy.nvim/colors/gruvbuddy.lua, die übrigen
-- Gruppen in colorbuddy/plugins/init.lua. gruvbuddy.nvim ist dieselbe Datei.

local M = {}

local function ensure_colorbuddy()
  pcall(function()
    require("lazy").load({ plugins = { "colorbuddy.nvim" } })
  end)
end

local function hex(n)
  if n == nil then
    return nil
  end
  return string.format("#%06x", n)
end

local function hl_part(name)
  local h = vim.api.nvim_get_hl(0, { name = name, link = false })
  local part = {}
  if h.fg then
    part.fg = hex(h.fg)
  end
  if h.bg then
    part.bg = hex(h.bg)
  end
  local gui = {}
  if h.bold then
    table.insert(gui, "bold")
  end
  if h.underline then
    table.insert(gui, "underline")
  end
  if h.italic then
    table.insert(gui, "italic")
  end
  if #gui > 0 then
    part.gui = table.concat(gui, ",")
  end
  return part
end

-- express_line färbt den Modus über NormalMode/InsertMode/... und den Rest
-- über StatusLine. Lualine bekommt dieselben Gruppen.
local function lualine_from_groups()
  local status = hl_part("StatusLine")
  local status_nc = hl_part("StatusLineNC")
  local visual = hl_part("VisualMode")
  if not visual.fg then
    visual.fg = hex(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg)
  end
  return {
    normal = {
      a = hl_part("NormalMode"),
      b = status,
      c = status,
    },
    insert = { a = hl_part("InsertMode") },
    visual = { a = visual },
    replace = { a = hl_part("ReplaceMode") },
    command = { a = hl_part("CommandMode") },
    inactive = {
      a = status_nc,
      b = status_nc,
      c = status_nc,
    },
  }
end

function M.apply()
  ensure_colorbuddy()

  local files = vim.api.nvim_get_runtime_file("colors/gruvbuddy.lua", false)
  if #files == 0 then
    vim.notify("gruvbuddy.lua nicht gefunden (colorbuddy.nvim)", vim.log.levels.ERROR)
    return
  end

  dofile(files[1])
  vim.g.colors_name = "tj"
  vim.g.tj_lualine = lualine_from_groups()
end

return M
