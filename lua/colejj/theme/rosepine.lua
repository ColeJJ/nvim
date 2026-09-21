-- Rose Pine, an Screenshot 1 (Primeagen) ausgerichtet:
-- weiss, leichtes orange, rot, dunkelgruen, mintgruen.
-- Kein iris-lila, kein pine-blau, kein dunkles gold.

local M = {}

local c = {
  bg = "#191724",
  white = "#e6e4ef",
  peach = "#ebbcba",
  orange = "#e8c4a0",
  dark_green = "#6a9a78",
  neo_green = "#9dccb0",
  muted = "#6e6a86",
}

local function is_main(name)
  name = name or vim.g.colors_name
  return name == "rose-pine" or name == "rose-pine-main"
end

local function fg(color)
  return { fg = color, italic = false, bold = false }
end

local highlights = {
  Normal = { fg = c.white, bg = c.bg },
  NormalNC = { fg = c.white, bg = c.bg },
  NormalFloat = { fg = c.white, bg = c.bg },
  SignColumn = { fg = c.white, bg = c.bg },
  LineNr = { fg = c.muted, bg = c.bg },
  CursorLineNr = { fg = c.white, bg = c.bg },
  Comment = { fg = c.muted, italic = false },

  -- Basis-Syntax
  Constant = fg(c.orange),
  String = fg(c.orange),
  Character = fg(c.orange),
  Number = fg(c.orange),
  Float = fg(c.orange),
  Boolean = fg(c.orange),
  Identifier = fg(c.white),
  Function = fg(c.peach),
  Statement = fg(c.dark_green),
  Conditional = fg(c.dark_green),
  Repeat = fg(c.dark_green),
  Keyword = fg(c.dark_green),
  Exception = fg(c.dark_green),
  Include = fg(c.dark_green),
  StorageClass = fg(c.dark_green),
  Type = fg(c.neo_green),
  Structure = fg(c.neo_green),
  Typedef = fg(c.neo_green),
  Operator = fg(c.white),
  Delimiter = fg(c.white),
  PreProc = fg(c.dark_green),
  Special = fg(c.white),

  ["@comment"] = { fg = c.muted, italic = false },

  -- weiss: punctuation, operatoren, pakete als prefix
  ["@operator"] = fg(c.white),
  ["@punctuation"] = fg(c.white),
  ["@punctuation.delimiter"] = fg(c.white),
  ["@punctuation.bracket"] = fg(c.white),
  ["@punctuation.special"] = fg(c.white),

  -- weiss: variablen, properties, methoden
  ["@variable"] = fg(c.white),
  ["@variable.builtin"] = fg(c.white),
  ["@variable.parameter"] = fg(c.white),
  ["@variable.member"] = fg(c.white),
  ["@property"] = fg(c.white),
  ["@field"] = fg(c.white),
  ["@parameter"] = fg(c.white),
  ["@constant"] = fg(c.orange),
  ["@constant.builtin"] = fg(c.orange),
  ["@constant.macro"] = fg(c.orange),
  ["@string"] = fg(c.orange),
  ["@string.escape"] = fg(c.orange),
  ["@number"] = fg(c.orange),
  ["@float"] = fg(c.orange),
  ["@boolean"] = fg(c.orange),

  -- pfirsich: Funktions- und Methodennamen
  ["@function"] = fg(c.peach),
  ["@function.call"] = fg(c.peach),
  ["@function.builtin"] = fg(c.peach),
  ["@function.method"] = fg(c.peach),
  ["@function.method.call"] = fg(c.peach),
  ["@method"] = fg(c.peach),
  ["@method.call"] = fg(c.peach),

  -- dunkelgruen: keywords, modifier, packages
  ["@keyword"] = fg(c.dark_green),
  ["@keyword.function"] = fg(c.dark_green),
  ["@keyword.storage"] = fg(c.dark_green),
  ["@keyword.modifier"] = fg(c.dark_green),
  ["@keyword.return"] = fg(c.dark_green),
  ["@keyword.import"] = fg(c.dark_green),
  ["@keyword.repeat"] = fg(c.dark_green),
  ["@keyword.conditional"] = fg(c.dark_green),
  ["@keyword.exception"] = fg(c.dark_green),
  ["@keyword.type"] = fg(c.dark_green),
  ["@keyword.operator"] = fg(c.white),
  ["@storageclass"] = fg(c.dark_green),
  ["@conditional"] = fg(c.dark_green),
  ["@repeat"] = fg(c.dark_green),
  ["@include"] = fg(c.dark_green),
  ["@module"] = fg(c.dark_green),
  ["@namespace"] = fg(c.dark_green),
  ["@attribute"] = fg(c.dark_green),

  -- neo-/mintgruen: typen und klassen
  ["@type"] = fg(c.neo_green),
  ["@type.builtin"] = fg(c.neo_green),
  ["@type.definition"] = fg(c.neo_green),
  ["@constructor"] = fg(c.neo_green),
  ["@class"] = fg(c.neo_green),

  -- LSP darf die Farben nicht wieder auf lila/blau ziehen
  ["@lsp.type.class"] = fg(c.neo_green),
  ["@lsp.type.interface"] = fg(c.neo_green),
  ["@lsp.type.enum"] = fg(c.neo_green),
  ["@lsp.type.struct"] = fg(c.neo_green),
  ["@lsp.type.type"] = fg(c.neo_green),
  ["@lsp.type.typeParameter"] = fg(c.neo_green),
  ["@lsp.type.function"] = fg(c.peach),
  ["@lsp.type.method"] = fg(c.peach),
  ["@lsp.type.variable"] = fg(c.white),
  ["@lsp.type.parameter"] = fg(c.white),
  ["@lsp.type.property"] = fg(c.white),
  ["@lsp.type.enumMember"] = fg(c.orange),
  ["@lsp.type.constant"] = fg(c.orange),
  ["@lsp.type.namespace"] = fg(c.dark_green),
  ["@lsp.type.keyword"] = fg(c.dark_green),
  ["@lsp.type.modifier"] = fg(c.dark_green),
  ["@lsp.type.annotation"] = fg(c.dark_green),
  ["@lsp.typemod.keyword.declaration"] = fg(c.dark_green),
  ["@lsp.typemod.keyword.modification"] = fg(c.dark_green),
  ["@lsp.typemod.function.declaration"] = fg(c.peach),
  ["@lsp.typemod.method.declaration"] = fg(c.peach),
  ["@lsp.typemod.variable.readonly"] = fg(c.white),
  ["@lsp.typemod.variable.defaultLibrary"] = fg(c.white),
}

function M.apply_highlights()
  if not is_main() then
    return
  end
  for group, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

function M.setup()
  require("rose-pine").setup({
    variant = "main",
    dark_variant = "main",
    dim_inactive_windows = false,
    palette = {
      main = {
        base = c.bg,
        text = c.white,
        love = c.peach,
        gold = c.orange,
        rose = c.peach,
        pine = c.dark_green,
        foam = c.neo_green,
        iris = c.white,
        leaf = c.dark_green,
      },
    },
    styles = {
      bold = false,
      italic = false,
      transparency = false,
    },
  })
end

function M.apply(color)
  M.setup()
  color = color or "rose-pine"
  vim.cmd.colorscheme(color)
  M.apply_highlights()
end

function M.setup_autocmd()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("colejj-rosepine-primeagen", { clear = true }),
    pattern = { "rose-pine", "rose-pine-main" },
    callback = function()
      vim.schedule(M.apply_highlights)
    end,
  })
end

return M
