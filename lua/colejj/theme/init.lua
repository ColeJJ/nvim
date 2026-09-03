local M = {}

local favorites = {
  "custom-obsidian",
  "rose-pine",
  "rose-pine-moon",
  "rose-pine-dawn",
}

local function refresh_lualine()
  local ok, lualine = pcall(require, "lualine")
  if not ok then
    return
  end
  local cfg = lualine.get_config()
  if vim.g.colors_name == "custom-obsidian" then
    cfg.options.theme = vim.g.custom_obsidian_lualine or "auto"
  else
    cfg.options.theme = "auto"
  end
  lualine.setup(cfg)
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
    refresh_lualine()
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
  refresh_lualine()
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

function M.setup()
  require("colejj.theme.rosepine").setup_autocmd()
  vim.keymap.set("n", "<leader>T", M.pick, { desc = "Theme wählen" })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("colejj-theme-lualine", { clear = true }),
    callback = function()
      vim.schedule(refresh_lualine)
    end,
  })
end

return M
