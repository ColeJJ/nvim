-- Harpoon-Tabline: dunkle, wenig ablenkende Leiste statt greller TabLineFill-Fläche.
local M = {}

local palettes = {
  tj = {
    bar = "#111111",
    active_bg = "#1c1c1c",
    active_fg = "#c8c8c8",
    inactive_fg = "#5c5c5c",
    number_active = "#81a2be",
    number_inactive = "#4a5f70",
    sep = "#2e2e2e",
  },
  ["custom-obsidian"] = {
    bar = "#010611",
    active_bg = "#05111D",
    active_fg = "#c9cccd",
    inactive_fg = "#3d4e56",
    number_active = "#8e97a4",
    number_inactive = "#3d4e56",
    sep = "#08212F",
  },
  ["material-deep-ocean"] = {
    bar = "#0F111A",
    active_bg = "#1A1C25",
    active_fg = "#c5c8d0",
    inactive_fg = "#4B526D",
    number_active = "#82AAFF",
    number_inactive = "#4B526D",
    sep = "#1F2233",
  },
  ["rose-pine"] = {
    bar = "#191724",
    active_bg = "#1f1d2e",
    active_fg = "#e6e4ef",
    inactive_fg = "#6e6a86",
    number_active = "#9dccb0",
    number_inactive = "#6e6a86",
    sep = "#26233a",
  },
}

palettes["rose-pine-main"] = palettes["rose-pine"]

local function hex(n)
  if n == nil then
    return nil
  end
  if type(n) == "string" then
    return n
  end
  return string.format("#%06x", n)
end

local function hl_col(group, key)
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
  if not ok or not h then
    return nil
  end
  return hex(h[key])
end

local function luminance(color)
  local r, g, b = color:match("#(%x%x)(%x%x)(%x%x)")
  if not r then
    return 0
  end
  local function lin(c)
    c = tonumber(c, 16) / 255
    if c <= 0.03928 then
      return c / 12.92
    end
    return ((c + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

local function palette()
  local named = palettes[vim.g.colors_name or ""]
  if named then
    return named
  end

  local bar = hl_col("Normal", "bg") or "#111111"
  local active_bg = hl_col("CursorLine", "bg") or bar
  local active_fg = hl_col("Normal", "fg") or "#c8c8c8"
  local inactive_fg = hl_col("Comment", "fg") or hl_col("LineNr", "fg") or "#5c5c5c"
  local number = hl_col("Identifier", "fg") or hl_col("DiagnosticInfo", "fg") or active_fg
  if luminance(number) > 0.55 then
    number = hl_col("Directory", "fg") or inactive_fg
  end
  if luminance(number) > 0.55 then
    number = inactive_fg
  end

  return {
    bar = bar,
    active_bg = active_bg,
    active_fg = active_fg,
    inactive_fg = inactive_fg,
    number_active = number,
    number_inactive = inactive_fg,
    sep = inactive_fg,
  }
end

function M.apply_highlights()
  local p = palette()
  local function hi(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  hi("TabLine", { fg = p.inactive_fg, bg = p.bar })
  hi("TabLineSel", { fg = p.active_fg, bg = p.active_bg })
  hi("TabLineFill", { fg = p.inactive_fg, bg = p.bar })
  hi("HarpoonInactive", { fg = p.inactive_fg, bg = p.bar })
  hi("HarpoonActive", { fg = p.active_fg, bg = p.active_bg })
  hi("HarpoonNumberInactive", { fg = p.number_inactive, bg = p.bar })
  hi("HarpoonNumberActive", { fg = p.number_active, bg = p.active_bg, bold = true })
  hi("HarpoonSep", { fg = p.sep, bg = p.bar })
end

local function shorten_filenames(marks)
  local counts = {}
  for _, mark in ipairs(marks) do
    local name = vim.fn.fnamemodify(mark.filename or "", ":t")
    counts[name] = (counts[name] or 0) + 1
  end

  local shortened = {}
  for _, mark in ipairs(marks) do
    local full = mark.filename or ""
    local name = vim.fn.fnamemodify(full, ":t")
    if counts[name] > 1 then
      table.insert(shortened, full)
    else
      table.insert(shortened, name)
    end
  end
  return shortened
end

local function truncate(name, max)
  if vim.fn.strdisplaywidth(name) <= max then
    return name
  end
  return vim.fn.strcharpart(name, 0, max - 1) .. "…"
end

local function escape(label)
  return (label:gsub("%%", "%%%%"))
end

function M.render()
  local ok, harpoon = pcall(require, "harpoon")
  if not ok then
    return ""
  end

  local marks = harpoon.get_mark_config().marks
  local labels = shorten_filenames(marks)
  local current = require("harpoon.mark").get_index_of(vim.fn.bufname())
  local parts = { "%#TabLineFill#" }

  local shown = 0
  for i, label in ipairs(labels) do
    if label ~= "" and label ~= "(empty)" then
      shown = shown + 1
      if shown > 1 then
        table.insert(parts, "%#HarpoonSep# │")
      end

      local active = i == current
      local num_hl = active and "HarpoonNumberActive" or "HarpoonNumberInactive"
      local name_hl = active and "HarpoonActive" or "HarpoonInactive"
      table.insert(parts, string.format("%%#%s# %d %%#%s#%s ", num_hl, i, name_hl, escape(truncate(label, 28))))
    end
  end

  table.insert(parts, "%#TabLineFill#")
  return table.concat(parts)
end

function M.setup()
  M.apply_highlights()
  vim.o.tabline = "%!v:lua.require'colejj.harpoon_tabline'.render()"
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("colejj-harpoon-tabline", { clear = true }),
    callback = function()
      vim.schedule(M.apply_highlights)
    end,
  })
end

return M
