-- Material Theme Community Edition · Deep Ocean
-- Palette: https://material-theme.com/docs/reference/color-palette/
-- Token-Mapping wie VS Code Community Material Theme (Equinusocio).

if not vim.g.material_deep_ocean_skip_clear then
  vim.cmd("hi clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end
end
vim.g.colors_name = "material-deep-ocean"
vim.o.background = "dark"
vim.o.termguicolors = true

local c = {
  bg = "#0F111A",
  bg_alt = "#090B10",
  bg_btn = "#191A21",
  bg_2nd = "#181A1F",
  bg_active = "#1A1C25",
  bg_hl = "#1F2233",
  bg_excl = "#292D3E",
  border = "#0F111A",
  fg = "#8F93A2",
  fg_ui = "#8F93A2",
  text = "#4B526D",
  white = "#EEFFFF",
  sel_fg = "#FFFFFF",
  comment = "#717CB4",
  disabled = "#464B5D",
  accent = "#84FFFF",
  green = "#C3E88D",
  yellow = "#FFCB6B",
  blue = "#82AAFF",
  red = "#F07178",
  purple = "#C792EA",
  orange = "#F78C6C",
  cyan = "#89DDFF",
  gray = "#717CB4",
  error = "#FF5370",
  link = "#80CBC4",
  caret = "#FFCC00",
  pale = "#B0C9FF",
  visual = "#404667",
}

local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

local function link(from, to)
  vim.api.nvim_set_hl(0, from, { link = to })
end

-- Basis
hi("Normal", { fg = c.white, bg = c.bg })
hi("NormalNC", { fg = c.white, bg = c.bg })
hi("NormalFloat", { fg = c.white, bg = c.bg_alt })
hi("FloatBorder", { fg = c.bg_hl, bg = c.bg_alt })
hi("FloatTitle", { fg = c.accent, bg = c.bg_alt, bold = true })
hi("Cursor", { fg = c.bg, bg = c.caret })
hi("iCursor", { fg = c.bg, bg = c.white })
hi("vCursor", { fg = c.bg, bg = c.white })
hi("lCursor", { fg = c.bg, bg = c.white })
hi("CursorLine", { bg = c.bg_active })
hi("CursorColumn", { bg = c.bg_active })
hi("ColorColumn", { bg = c.bg_active })
hi("Visual", { bg = c.visual })
hi("VisualNOS", { bg = c.bg_hl })
hi("Search", { fg = c.bg, bg = c.yellow, bold = true })
hi("IncSearch", { fg = c.bg, bg = c.orange, bold = true })
hi("CurSearch", { fg = c.bg, bg = c.yellow, bold = true })
hi("Substitute", { fg = c.bg, bg = c.error, bold = true })
hi("MatchParen", { fg = c.yellow, bold = true })
hi("LineNr", { fg = c.text, bg = c.bg })
hi("CursorLineNr", { fg = c.accent, bg = c.bg, bold = true })
hi("SignColumn", { fg = c.comment, bg = c.bg })
hi("FoldColumn", { fg = c.blue, bg = c.bg })
hi("Folded", { fg = c.disabled, bg = c.bg_alt, italic = true })
hi("VertSplit", { fg = c.bg_hl, bg = c.bg })
hi("WinSeparator", { fg = c.bg_hl, bg = c.bg })
hi("StatusLine", { fg = c.white, bg = c.bg_active })
hi("StatusLineNC", { fg = c.disabled, bg = c.bg_alt })
hi("WinBar", { fg = c.fg, bg = c.bg })
hi("WinBarNC", { fg = c.disabled, bg = c.bg })
hi("TabLine", { fg = c.fg, bg = c.bg_alt })
hi("TabLineSel", { fg = c.bg, bg = c.accent, bold = true })
hi("TabLineFill", { fg = c.fg, bg = c.bg_alt })
hi("Pmenu", { fg = c.white, bg = c.bg_2nd })
hi("PmenuSel", { fg = c.bg, bg = c.accent })
hi("PmenuSbar", { bg = c.bg_active })
hi("PmenuThumb", { bg = c.comment })
hi("WildMenu", { fg = c.orange, bold = true })
hi("Question", { fg = c.yellow, bold = true })
hi("MoreMsg", { fg = c.accent })
hi("ModeMsg", { fg = c.accent, bold = true })
hi("ErrorMsg", { fg = c.error, bold = true })
hi("WarningMsg", { fg = c.yellow, bold = true })
hi("Title", { fg = c.cyan, bold = true })
hi("Directory", { fg = c.blue, bold = true })
hi("NonText", { fg = c.disabled })
hi("SpecialKey", { fg = c.purple })
hi("Whitespace", { fg = c.disabled })
hi("EndOfBuffer", { fg = c.bg })
hi("Conceal", { fg = c.disabled })
hi("QuickFixLine", { bg = c.bg_hl })
hi("qflistLineNr", { fg = c.text })
hi("SpellBad", { fg = c.red, italic = true, undercurl = true, sp = c.red })
hi("SpellCap", { fg = c.blue, italic = true, undercurl = true, sp = c.blue })
hi("SpellLocal", { fg = c.cyan, italic = true, undercurl = true, sp = c.cyan })
hi("SpellRare", { fg = c.purple, italic = true, undercurl = true, sp = c.purple })

-- Syntax (VS Code tokenColors)
hi("Comment", { fg = c.comment, italic = true })
hi("Constant", { fg = c.orange })
hi("String", { fg = c.green })
hi("Character", { fg = c.orange })
hi("Number", { fg = c.orange })
hi("Boolean", { fg = c.orange })
hi("Float", { fg = c.orange })
hi("Identifier", { fg = c.white })
hi("Function", { fg = c.blue })
hi("Statement", { fg = c.cyan })
hi("Conditional", { fg = c.purple, italic = true })
hi("Repeat", { fg = c.purple, italic = true })
hi("Label", { fg = c.purple })
hi("Operator", { fg = c.cyan })
hi("Keyword", { fg = c.purple, italic = true })
hi("Exception", { fg = c.red })
hi("PreProc", { fg = c.cyan })
hi("Include", { fg = c.purple, italic = true })
hi("Define", { fg = c.cyan })
hi("Macro", { fg = c.cyan })
hi("Type", { fg = c.yellow })
hi("StorageClass", { fg = c.purple, italic = true })
hi("Structure", { fg = c.yellow })
hi("Typedef", { fg = c.red })
hi("Special", { fg = c.cyan })
hi("SpecialChar", { fg = c.red })
hi("Tag", { fg = c.red })
hi("Delimiter", { fg = c.cyan })
hi("SpecialComment", { fg = c.comment, italic = true })
hi("Debug", { fg = c.red })
hi("Underlined", { fg = c.link, underline = true })
hi("Ignore", { fg = c.disabled })
hi("Error", { fg = c.error, bold = true })
hi("Todo", { fg = c.yellow, bold = true })

-- Treesitter
hi("@comment", { fg = c.comment, italic = true })
hi("@comment.documentation", { fg = c.comment, italic = true })
hi("@string", { fg = c.green })
hi("@string.escape", { fg = c.comment })
hi("@string.regexp", { fg = c.yellow })
hi("@character", { fg = c.orange })
hi("@number", { fg = c.orange })
hi("@boolean", { fg = c.orange })
hi("@float", { fg = c.orange })
hi("@keyword", { fg = c.purple, italic = true })
hi("@keyword.function", { fg = c.purple, italic = true })
hi("@keyword.return", { fg = c.purple, italic = true })
hi("@keyword.operator", { fg = c.purple, italic = true })
hi("@keyword.import", { fg = c.purple, italic = true })
hi("@keyword.modifier", { fg = c.purple, italic = true })
hi("@keyword.type", { fg = c.purple, italic = true })
hi("@keyword.conditional", { fg = c.purple, italic = true })
hi("@keyword.repeat", { fg = c.purple, italic = true })
hi("@keyword.exception", { fg = c.red })
hi("@keyword.directive", { fg = c.cyan })
hi("@keyword.storage", { fg = c.cyan })
hi("@type.qualifier", { fg = c.cyan })
hi("@conditional", { fg = c.purple, italic = true })
hi("@repeat", { fg = c.purple, italic = true })
hi("@operator", { fg = c.cyan })
hi("@punctuation", { fg = c.cyan })
hi("@punctuation.delimiter", { fg = c.cyan })
hi("@punctuation.bracket", { fg = c.cyan })
hi("@punctuation.special", { fg = c.cyan })
hi("@function", { fg = c.blue })
hi("@function.method", { fg = c.blue })
hi("@function.call", { fg = c.blue })
hi("@function.method.call", { fg = c.blue })
hi("@function.builtin", { fg = c.blue })
hi("@function.macro", { fg = c.blue })
hi("@method", { fg = c.blue })
hi("@method.call", { fg = c.blue })
hi("@constructor", { fg = c.blue })
hi("@type", { fg = c.yellow })
hi("@type.builtin", { fg = c.purple, italic = true })
hi("@type.definition", { fg = c.yellow })
hi("@variable", { fg = c.white })
hi("@variable.builtin", { fg = c.error, italic = true })
hi("@variable.parameter", { fg = c.orange })
hi("@variable.member", { fg = c.comment })
hi("@property", { fg = c.comment })
hi("@field", { fg = c.comment })
hi("@constant", { fg = c.yellow })
hi("@constant.builtin", { fg = c.yellow })
hi("@constant.macro", { fg = c.cyan })
hi("@attribute", { fg = c.yellow })
hi("@attribute.builtin", { fg = c.yellow })
hi("@label", { fg = c.yellow })
hi("@tag", { fg = c.red })
hi("@tag.attribute", { fg = c.purple })
hi("@tag.delimiter", { fg = c.cyan })
hi("@module", { fg = c.yellow })
hi("@namespace", { fg = c.yellow })
hi("@parameter", { fg = c.orange })
hi("@text", { fg = c.white })
hi("@markup.heading", { fg = c.cyan, bold = true })
hi("@markup.heading.1", { fg = c.cyan, bold = true })
hi("@markup.heading.2", { fg = c.blue, bold = true })
hi("@markup.heading.3", { fg = c.green, bold = true })
hi("@markup.heading.4", { fg = c.yellow, bold = true })
hi("@markup.heading.5", { fg = c.purple })
hi("@markup.heading.6", { fg = c.orange })
hi("@markup.link", { fg = c.red })
hi("@markup.link.url", { fg = c.link, underline = true })
hi("@markup.raw", { fg = c.purple })
hi("@markup.strong", { bold = true })
hi("@markup.italic", { italic = true })
hi("@markup.list", { fg = c.cyan })
hi("@markup.quote", { fg = c.comment, italic = true })

-- LSP semantic tokens (Java)
hi("@lsp.type.class", { fg = c.yellow })
hi("@lsp.type.interface", { fg = c.green, italic = true })
hi("@lsp.type.enum", { fg = c.yellow })
hi("@lsp.type.struct", { fg = c.yellow })
hi("@lsp.type.type", { fg = c.yellow })
hi("@lsp.type.typeParameter", { fg = c.yellow })
hi("@lsp.type.function", { fg = c.blue })
hi("@lsp.type.method", { fg = c.blue })
hi("@lsp.type.variable", { fg = c.white })
hi("@lsp.type.parameter", { fg = c.orange })
hi("@lsp.type.property", { fg = c.comment })
hi("@lsp.type.enumMember", { fg = c.yellow })
hi("@lsp.type.constant", { fg = c.yellow })
hi("@lsp.type.namespace", { fg = c.yellow })
hi("@lsp.type.keyword", { fg = c.purple, italic = true })
hi("@lsp.type.modifier", { fg = c.purple, italic = true })
hi("@lsp.type.annotation", { fg = c.yellow })
hi("@lsp.type.selfKeyword", { fg = c.error, italic = true })
hi("@lsp.typemod.keyword.declaration", { fg = c.purple, italic = true })
hi("@lsp.typemod.keyword.modification", { fg = c.purple, italic = true })
hi("@lsp.typemod.annotation.declaration", { fg = c.yellow })
hi("@lsp.typemod.method.declaration", { fg = c.blue })
hi("@lsp.typemod.function.declaration", { fg = c.blue })
hi("@lsp.typemod.variable.constant", { fg = c.yellow })
hi("LspReferenceText", { bg = c.bg_hl })
hi("LspReferenceRead", { bg = c.bg_hl })
hi("LspReferenceWrite", { bg = c.bg_hl })
hi("LspInlayHint", { fg = c.comment, italic = true })
hi("LspCodeLens", { fg = c.comment, italic = true })
hi("LspSignatureActiveParameter", { fg = c.orange, bold = true })

-- Diagnostics
hi("DiagnosticError", { fg = c.error })
hi("DiagnosticWarn", { fg = c.yellow })
hi("DiagnosticInfo", { fg = c.pale })
hi("DiagnosticHint", { fg = c.purple })
hi("DiagnosticOk", { fg = c.green })
hi("DiagnosticUnderlineError", { undercurl = true, sp = c.error })
hi("DiagnosticUnderlineWarn", { undercurl = true, sp = c.yellow })
hi("DiagnosticUnderlineInfo", { undercurl = true, sp = c.pale })
hi("DiagnosticUnderlineHint", { undercurl = true, sp = c.purple })
hi("DiagnosticVirtualTextError", { fg = c.error, bg = "#2A1218" })
hi("DiagnosticVirtualTextWarn", { fg = c.yellow, bg = c.bg_active })
hi("DiagnosticVirtualTextInfo", { fg = c.pale, bg = c.bg_active })
hi("DiagnosticVirtualTextHint", { fg = c.purple, bg = c.bg_active })
hi("DiagnosticFloatingError", { fg = c.error, bg = c.bg_alt })
hi("DiagnosticFloatingWarn", { fg = c.yellow, bg = c.bg_alt })
hi("DiagnosticFloatingInfo", { fg = c.pale, bg = c.bg_alt })
hi("DiagnosticFloatingHint", { fg = c.purple, bg = c.bg_alt })
hi("DiagnosticFloatingOk", { fg = c.green, bg = c.bg_alt })
hi("DiagnosticSignError", { fg = c.error, bg = c.bg })
hi("DiagnosticSignWarn", { fg = c.yellow, bg = c.bg })
hi("DiagnosticSignInfo", { fg = c.pale, bg = c.bg })
hi("DiagnosticSignHint", { fg = c.purple, bg = c.bg })
hi("DiagnosticUnnecessary", { fg = c.disabled, italic = true })
hi("DiagnosticDeprecated", { fg = c.disabled, strikethrough = true })

-- Diff / Git
hi("DiffAdd", { fg = c.green, bg = "#1A2A1A" })
hi("DiffChange", { fg = c.blue, bg = "#1A2233" })
hi("DiffDelete", { fg = c.red, bg = "#2A1218" })
hi("DiffText", { fg = c.cyan, bg = "#1A2233" })
hi("GitSignsAdd", { fg = c.green })
hi("GitSignsChange", { fg = c.blue })
hi("GitSignsDelete", { fg = c.red })
hi("Added", { fg = c.green })
hi("Changed", { fg = c.blue })
hi("Removed", { fg = c.red })

-- Telescope
hi("TelescopeNormal", { fg = c.white, bg = c.bg_alt })
hi("TelescopeBorder", { fg = c.bg_hl, bg = c.bg_alt })
hi("TelescopePromptBorder", { fg = c.bg_hl, bg = c.bg_alt })
hi("TelescopeSelection", { bg = c.bg_hl })
hi("TelescopeMatching", { fg = c.accent, bold = true })
hi("TelescopePromptPrefix", { fg = c.accent })
hi("TelescopeTitle", { fg = c.accent, bold = true })

-- Completion
hi("CmpItemAbbr", { fg = c.white })
hi("CmpItemAbbrMatch", { fg = c.accent, bold = true })
hi("CmpItemAbbrMatchFuzzy", { fg = c.blue, bold = true })
hi("CmpItemKind", { fg = c.yellow })
hi("CmpItemMenu", { fg = c.comment })
hi("CmpItemKindFunction", { fg = c.blue })
hi("CmpItemKindMethod", { fg = c.blue })
hi("CmpItemKindVariable", { fg = c.white })
hi("CmpItemKindClass", { fg = c.yellow })
hi("CmpItemKindInterface", { fg = c.green })
hi("CmpItemKindKeyword", { fg = c.purple })
hi("CmpItemKindSnippet", { fg = c.orange })
hi("CmpItemKindConstant", { fg = c.yellow })

-- nvim-tree
hi("NvimTreeNormal", { fg = c.fg, bg = c.bg_alt })
hi("NvimTreeWinSeparator", { fg = c.bg_alt, bg = c.bg_alt })
hi("NvimTreeFolderName", { fg = c.blue })
hi("NvimTreeOpenedFolderName", { fg = c.blue, bold = true })
hi("NvimTreeRootFolder", { fg = c.accent, bold = true })
hi("NvimTreeGitDirty", { fg = c.blue })
hi("NvimTreeGitNew", { fg = c.green })
hi("NvimTreeGitDeleted", { fg = c.red })
hi("NvimTreeExecFile", { fg = c.green })
hi("NvimTreeIndentMarker", { fg = c.bg_excl })

-- Markdown
hi("markdownH1", { fg = c.cyan, bold = true })
hi("markdownH2", { fg = c.blue, bold = true })
hi("markdownH3", { fg = c.green, bold = true })
hi("markdownCode", { fg = c.purple })
hi("markdownCodeBlock", { fg = c.purple })
hi("markdownUrl", { fg = c.link, underline = true })

-- Indent
hi("IblIndent", { fg = c.bg_excl })
hi("IblScope", { fg = c.bg_hl })
hi("IndentBlanklineChar", { fg = c.bg_excl })

-- Tests / DAP
hi("NeotestPassed", { fg = c.green })
hi("NeotestFailed", { fg = c.error })
hi("NeotestRunning", { fg = c.yellow })
hi("NeotestSkipped", { fg = c.comment })
hi("NeotestDir", { fg = c.blue })
hi("NeotestFile", { fg = c.white })
hi("OverseerSUCCESS", { fg = c.green })
hi("OverseerFAILURE", { fg = c.error })
hi("OverseerCANCELED", { fg = c.yellow })
hi("OverseerRUNNING", { fg = c.blue })
hi("DapUIBreakpointsCurrentLine", { fg = c.accent, bold = true })
hi("DapUIWatchesEmpty", { fg = c.comment })
hi("DapUIWatchesValue", { fg = c.green })
hi("DapUIWatchesError", { fg = c.error })
hi("DapUIScope", { fg = c.accent })
hi("DapUIType", { fg = c.yellow })
hi("DapUIValue", { fg = c.white })
hi("DapUIModifiedValue", { fg = c.yellow, bold = true })
hi("DapBreakpoint", { fg = c.error, bg = c.bg })
hi("DapLogPoint", { fg = c.blue, bg = c.bg })
hi("DapStopped", { fg = c.green, bg = c.bg_active })

hi("dbout", { fg = c.white, bg = c.bg })

-- which-key
hi("WhichKey", { fg = c.accent, bold = true })
hi("WhichKeyGroup", { fg = c.blue })
hi("WhichKeyDesc", { fg = c.white })
hi("WhichKeySeparator", { fg = c.comment })
hi("WhichKeyFloat", { bg = c.bg_alt })

hi("TermCursor", { fg = c.bg, bg = c.caret })
vim.g.terminal_color_0 = "#000000"
vim.g.terminal_color_1 = "#DC6068"
vim.g.terminal_color_2 = "#ABCF76"
vim.g.terminal_color_3 = "#E6B455"
vim.g.terminal_color_4 = "#6E98EB"
vim.g.terminal_color_5 = "#B480D6"
vim.g.terminal_color_6 = "#71C6E7"
vim.g.terminal_color_7 = c.white
vim.g.terminal_color_8 = c.disabled
vim.g.terminal_color_9 = c.red
vim.g.terminal_color_10 = c.green
vim.g.terminal_color_11 = c.yellow
vim.g.terminal_color_12 = c.blue
vim.g.terminal_color_13 = c.purple
vim.g.terminal_color_14 = c.cyan
vim.g.terminal_color_15 = c.white

vim.g.material_deep_ocean_lualine = {
  normal = {
    a = { fg = c.bg, bg = c.accent, gui = "bold" },
    b = { fg = c.white, bg = c.bg_active },
    c = { fg = c.fg, bg = c.bg },
  },
  insert = { a = { fg = c.bg, bg = c.green, gui = "bold" } },
  visual = { a = { fg = c.bg, bg = c.purple, gui = "bold" } },
  replace = { a = { fg = c.bg, bg = c.error, gui = "bold" } },
  command = { a = { fg = c.bg, bg = c.yellow, gui = "bold" } },
  inactive = {
    a = { fg = c.disabled, bg = c.bg_alt },
    b = { fg = c.disabled, bg = c.bg_alt },
    c = { fg = c.disabled, bg = c.bg },
  },
}
