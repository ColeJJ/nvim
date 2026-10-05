local M = {}

local favorites = {
  "tj",
  "custom-obsidian",
  "material-deep-ocean",
  "rose-pine",
  "rose-pine-moon",
  "rose-pine-dawn",
}

local function refresh_lualine()
  local lazy_ok, cfg = pcall(require, "lazy.core.config")
  local plugin = lazy_ok and cfg.plugins["lualine.nvim"]
  if not (plugin and plugin._ and plugin._.loaded) then
    return
  end
  local lualine = require("lualine")
  local cfg = lualine.get_config()
  if vim.g.colors_name == "custom-obsidian" then
    cfg.options.theme = vim.g.custom_obsidian_lualine or "auto"
  elseif vim.g.colors_name == "material-deep-ocean" then
    cfg.options.theme = vim.g.material_deep_ocean_lualine or "auto"
  elseif vim.g.colors_name == "tj" then
    cfg.options.theme = vim.g.tj_lualine or "auto"
  else
    cfg.options.theme = "auto"
  end
  lualine.setup(cfg)
end

local function refresh_harpoon_tabline()
  pcall(function()
    require("colejj.harpoon_tabline").apply_highlights()
  end)
end

local function refresh_chrome()
  refresh_lualine()
  refresh_harpoon_tabline()
end

local function ensure_rose_pine()
  pcall(function()
    require("lazy").load({ plugins = { "rose-pine" } })
  end)
end

function M.apply(name)
  if name == "rose-pine" or name == "rose-pine-main" then
    ensure_rose_pine()
    require("colejj.theme.rosepine").apply(name)
    refresh_chrome()
    return
  end
  if name == "tj" then
    require("colejj.theme.tj").apply()
    refresh_chrome()
    return
  end
  if name:find("^rose%-pine") then
    ensure_rose_pine()
  end
  local ok, err = pcall(vim.cmd.colorscheme, name)
  if not ok then
    vim.notify("Theme nicht geladen: " .. name .. "\n" .. tostring(err), vim.log.levels.ERROR)
    return
  end
  refresh_chrome()
end

function M.pick()
  ensure_rose_pine()

  local ok, builtin = pcall(require, "telescope.builtin")
  if ok then
    builtin.colorscheme({
      enable_preview = true,
    })
    return
  end

  local seen = {}
  local items = {}
  for _, name in ipairs(favorites) do
    if not seen[name] then
      seen[name] = true
      table.insert(items, name)
    end
  end
  for _, name in ipairs(vim.fn.getcompletion("", "color")) do
    if not seen[name] then
      seen[name] = true
      table.insert(items, name)
    end
  end

  vim.ui.select(items, {
    prompt = "Theme",
    format_item = function(item)
      if item == vim.g.colors_name then
        return item .. "  (aktuell)"
      end
      return item
    end,
  }, function(choice)
    if choice then
      M.apply(choice)
    end
  end)
end

local function apply_cursors()
  if vim.g.colors_name == "material-deep-ocean" or vim.g.colors_name == "tj" then
    return
  end
  -- Blockcursor: Normal grau, Insert/Visual weiß.
  vim.api.nvim_set_hl(0, "Cursor", { fg = "#010611", bg = "#A0A0A0" })
  vim.api.nvim_set_hl(0, "iCursor", { fg = "#010611", bg = "#FFFFFF" })
  vim.api.nvim_set_hl(0, "vCursor", { fg = "#010611", bg = "#FFFFFF" })
  vim.api.nvim_set_hl(0, "lCursor", { fg = "#010611", bg = "#FFFFFF" })
  vim.api.nvim_set_hl(0, "TermCursor", { fg = "#010611", bg = "#A0A0A0" })
end

function M.setup()
  require("colejj.theme.obsidian")
  require("colejj.theme.deepocean")
  require("colejj.theme.rosepine").setup_autocmd()
  vim.keymap.set("n", "<leader>T", M.pick, { desc = "Theme wählen" })
  apply_cursors()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("colejj-theme-lualine", { clear = true }),
    callback = function()
      vim.schedule(function()
        apply_cursors()
        refresh_chrome()
      end)
    end,
  })
end

return M
