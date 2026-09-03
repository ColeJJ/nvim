-- IntelliJ "Obsidian Custom" → Neovim (aus Doom custom-obsidian-theme.el)
-- Sehr dunkler blau-schwarzer Grund, goldene Keywords, grüne Strings.

if not vim.g.custom_obsidian_skip_clear then
  vim.cmd("hi clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end
end
vim.g.colors_name = "custom-obsidian"
vim.o.background = "dark"
vim.o.termguicolors = true

local c = {
  bg = "#010611",
  bg_line = "#05111D",
  bg_sel = "#082C3C",
  bg_sel2 = "#0B364B",
  border = "#08212F",
  indent = "#081826",
  fg = "#c9cccd",
  fg_bright = "#e0e0e7",
  sel_fg = "#c2c2c2",
  comment = "#293941",
  linenr = "#293941",
  linenr_cur = "#4b666f",
  keyword = "#e3d363",
  string = "#97cb8f",
  number = "#a3bb97",
  func_decl = "#f8e1aa",
  func_call = "#cadee8",
  type = "#9ba69f",
  field = "#8e97a4",
  constant = "#716994",
  label = "#cd92a1",
  annotation = "#8e8e8e",
  attribute = "#d0d6b5",
  predefined = "#f2c4b3",
  tag = "#e6958f",
  red = "#ff4262",
  warn = "#d9c979",
  warn_eff = "#eeecaa",
  green = "#508654",
  deleted = "#9c1a41",
  modified = "#266c78",
  blue = "#5d82ba",
  cyan = "#0f859b",
  link = "#2b85a8",
  ml_bg = "#0d2c37",
  diff_ins_bg = "#031c1e",
  diff_del_bg = "#2f091b",
  diff_mod_bg = "#1d242f",
  search_bg = "#bfdeba",
}

local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

local function link(from, to)
  vim.api.nvim_set_hl(0, from, { link = to })
end

-- Basis
hi("Normal", { fg = c.fg, bg = c.bg })
hi("NormalNC", { fg = c.fg, bg = c.bg })
hi("NormalFloat", { fg = c.fg, bg = c.bg_line })
hi("FloatBorder", { fg = c.border, bg = c.bg_line })
hi("FloatTitle", { fg = c.keyword, bg = c.bg_line, bold = true })
hi("Cursor", { fg = c.bg, bg = c.fg_bright })
hi("CursorLine", { bg = c.bg_line })
hi("CursorColumn", { bg = c.bg_line })
hi("ColorColumn", { bg = c.indent })
hi("Visual", { fg = c.sel_fg, bg = c.bg_sel })
hi("VisualNOS", { bg = c.bg_sel2 })
hi("Search", { fg = c.bg, bg = c.search_bg, bold = true })
hi("IncSearch", { fg = c.bg, bg = c.search_bg, bold = true })
hi("CurSearch", { fg = c.bg, bg = c.keyword, bold = true })
hi("Substitute", { fg = c.bg, bg = c.red, bold = true })
hi("MatchParen", { fg = c.keyword, bg = c.bg_sel2, bold = true })
hi("LineNr", { fg = c.linenr, bg = c.bg })
hi("CursorLineNr", { fg = c.linenr_cur, bg = c.bg, bold = true })
hi("SignColumn", { fg = c.comment, bg = c.bg })
hi("FoldColumn", { fg = c.comment, bg = c.bg })
hi("Folded", { fg = c.comment, bg = c.bg_line })
hi("VertSplit", { fg = c.border, bg = c.bg })
hi("WinSeparator", { fg = c.border, bg = c.bg })
hi("StatusLine", { fg = c.fg, bg = c.ml_bg })
hi("StatusLineNC", { fg = c.comment, bg = c.bg_line })
hi("WinBar", { fg = c.fg, bg = c.bg })
hi("WinBarNC", { fg = c.comment, bg = c.bg })
hi("TabLine", { fg = c.comment, bg = c.bg_line })
hi("TabLineSel", { fg = c.keyword, bg = c.bg, bold = true })
hi("TabLineFill", { fg = c.comment, bg = c.bg_line })
hi("Pmenu", { fg = c.fg, bg = c.bg_line })
hi("PmenuSel", { fg = c.fg, bg = c.bg_sel })
hi("PmenuSbar", { bg = c.bg })
hi("PmenuThumb", { bg = c.field })
hi("WildMenu", { fg = c.fg, bg = c.bg_sel })
hi("Question", { fg = c.keyword, bold = true })
hi("MoreMsg", { fg = c.string })
hi("ModeMsg", { fg = c.fg, bold = true })
hi("ErrorMsg", { fg = c.red, bold = true })
hi("WarningMsg", { fg = c.warn, bold = true })
hi("Title", { fg = c.keyword, bold = true })
hi("Directory", { fg = c.func_call, bold = true })
hi("NonText", { fg = c.comment })
hi("SpecialKey", { fg = c.comment })
hi("Whitespace", { fg = c.indent })
hi("EndOfBuffer", { fg = c.bg })
hi("Conceal", { fg = c.comment })
hi("QuickFixLine", { bg = c.bg_sel })
hi("qflistLineNr", { fg = c.linenr })

-- Syntax
hi("Comment", { fg = c.comment, italic = true })
hi("Constant", { fg = c.constant, italic = true })
hi("String", { fg = c.string })
hi("Character", { fg = c.string })
hi("Number", { fg = c.number })
hi("Boolean", { fg = c.constant, italic = true })
hi("Float", { fg = c.number })
hi("Identifier", { fg = c.field })
hi("Function", { fg = c.func_decl })
hi("Statement", { fg = c.keyword })
hi("Conditional", { fg = c.keyword })
hi("Repeat", { fg = c.keyword })
hi("Label", { fg = c.label })
hi("Operator", { fg = c.fg_bright })
hi("Keyword", { fg = c.keyword })
hi("Exception", { fg = c.keyword })
hi("PreProc", { fg = c.annotation, bold = true })
hi("Include", { fg = c.keyword })
hi("Define", { fg = c.annotation, bold = true })
hi("Macro", { fg = c.annotation, bold = true })
hi("Type", { fg = c.type, bold = true })
hi("StorageClass", { fg = c.keyword })
hi("Structure", { fg = c.type, bold = true })
hi("Typedef", { fg = c.type, bold = true })
hi("Special", { fg = c.predefined })
hi("SpecialChar", { fg = c.string, bold = true })
hi("Tag", { fg = c.tag })
hi("Delimiter", { fg = c.fg_bright })
hi("SpecialComment", { fg = c.link, italic = true })
hi("Debug", { fg = c.red })
hi("Underlined", { fg = c.link, underline = true })
hi("Ignore", { fg = c.comment })
hi("Error", { fg = c.red, bold = true })
hi("Todo", { fg = c.warn, bold = true })

-- Treesitter
hi("@comment", { fg = c.comment, italic = true })
hi("@comment.documentation", { fg = c.comment, italic = true })
hi("@string", { fg = c.string })
hi("@string.escape", { fg = c.string, bold = true })
hi("@string.regexp", { fg = c.string })
hi("@character", { fg = c.string })
hi("@number", { fg = c.number })
hi("@boolean", { fg = c.constant, italic = true })
hi("@float", { fg = c.number })
hi("@keyword", { fg = c.keyword })
hi("@keyword.function", { fg = c.keyword })
hi("@keyword.return", { fg = c.keyword })
hi("@keyword.operator", { fg = c.keyword })
hi("@keyword.import", { fg = c.keyword })
hi("@keyword.modifier", { fg = c.keyword })
hi("@keyword.type", { fg = c.keyword })
hi("@type.qualifier", { fg = c.keyword })
hi("@conditional", { fg = c.keyword })
hi("@repeat", { fg = c.keyword })
hi("@operator", { fg = c.fg_bright })
hi("@punctuation", { fg = c.fg_bright })
hi("@punctuation.delimiter", { fg = c.fg_bright })
hi("@punctuation.bracket", { fg = c.fg_bright })
hi("@punctuation.special", { fg = c.fg_bright })
hi("@function", { fg = c.func_decl })
hi("@function.method", { fg = c.func_decl })
hi("@function.call", { fg = c.func_call })
hi("@function.method.call", { fg = c.func_call })
hi("@method", { fg = c.func_decl })
hi("@method.call", { fg = c.func_call })
hi("@constructor", { fg = c.type, bold = true })
hi("@type", { fg = c.type, bold = true })
hi("@type.builtin", { fg = c.type, bold = true })
hi("@type.definition", { fg = c.type, bold = true })
hi("@variable", { fg = c.field })
hi("@variable.builtin", { fg = c.predefined })
hi("@variable.parameter", { fg = c.field })
hi("@variable.member", { fg = c.field })
hi("@property", { fg = c.field })
hi("@field", { fg = c.field })
hi("@constant", { fg = c.constant, italic = true })
hi("@constant.builtin", { fg = c.constant, italic = true })
hi("@constant.macro", { fg = c.constant, italic = true })
hi("@attribute", { fg = c.annotation, bold = true })
hi("@attribute.builtin", { fg = c.annotation, bold = true })
hi("@label", { fg = c.label })
hi("@tag", { fg = c.tag })
hi("@tag.attribute", { fg = c.attribute })
hi("@tag.delimiter", { fg = c.fg_bright })
hi("@module", { fg = c.type })
hi("@namespace", { fg = c.type })
hi("@parameter", { fg = c.field })
hi("@text", { fg = c.fg })
hi("@markup.heading", { fg = c.keyword, bold = true })
hi("@markup.heading.1", { fg = c.keyword, bold = true })
hi("@markup.heading.2", { fg = c.func_call, bold = true })
hi("@markup.heading.3", { fg = c.string, bold = true })
hi("@markup.heading.4", { fg = c.label, bold = true })
hi("@markup.heading.5", { fg = c.type })
hi("@markup.heading.6", { fg = c.cyan })
hi("@markup.link", { fg = c.link, underline = true })
hi("@markup.raw", { fg = c.predefined })
hi("@markup.strong", { bold = true })
hi("@markup.italic", { italic = true })
hi("@markup.list", { fg = c.keyword })
hi("@markup.quote", { fg = c.comment, italic = true })

-- LSP semantic tokens
hi("@lsp.type.class", { fg = c.type, bold = true })
hi("@lsp.type.interface", { fg = c.type, bold = true })
hi("@lsp.type.enum", { fg = c.type, bold = true })
hi("@lsp.type.struct", { fg = c.type, bold = true })
hi("@lsp.type.type", { fg = c.type, bold = true })
hi("@lsp.type.typeParameter", { fg = c.cyan })
hi("@lsp.type.function", { fg = c.func_decl })
hi("@lsp.type.method", { fg = c.func_call })
hi("@lsp.type.variable", { fg = c.field })
hi("@lsp.type.parameter", { fg = c.field })
hi("@lsp.type.property", { fg = c.field })
hi("@lsp.type.enumMember", { fg = c.constant, italic = true })
hi("@lsp.type.constant", { fg = c.constant, italic = true })
hi("@lsp.type.namespace", { fg = c.type })
hi("@lsp.type.keyword", { fg = c.keyword })
hi("@lsp.type.modifier", { fg = c.keyword })
hi("@lsp.type.annotation", { fg = c.annotation, bold = true })
hi("@lsp.typemod.keyword.declaration", { fg = c.keyword })
hi("@lsp.typemod.keyword.modification", { fg = c.keyword })
hi("@lsp.typemod.annotation.declaration", { fg = c.annotation, bold = true })
hi("@lsp.typemod.method.declaration", { fg = c.func_decl })
hi("@lsp.typemod.function.declaration", { fg = c.func_decl })
hi("@lsp.typemod.variable.constant", { fg = c.constant, italic = true })
hi("LspReferenceText", { bg = c.bg_sel })
hi("LspReferenceRead", { bg = c.bg_sel })
hi("LspReferenceWrite", { bg = c.bg_sel2 })
hi("LspInlayHint", { fg = c.comment, italic = true })
hi("LspCodeLens", { fg = c.comment, italic = true })
hi("LspSignatureActiveParameter", { fg = c.keyword, bold = true })

-- Diagnostics
hi("DiagnosticError", { fg = c.red })
hi("DiagnosticWarn", { fg = c.warn })
hi("DiagnosticInfo", { fg = c.modified })
hi("DiagnosticHint", { fg = c.cyan })
hi("DiagnosticOk", { fg = c.green })
hi("DiagnosticUnderlineError", { undercurl = true, sp = c.red })
hi("DiagnosticUnderlineWarn", { undercurl = true, sp = c.warn })
hi("DiagnosticUnderlineInfo", { undercurl = true, sp = c.modified })
hi("DiagnosticUnderlineHint", { undercurl = true, sp = c.cyan })
hi("DiagnosticVirtualTextError", { fg = c.red, bg = c.diff_del_bg })
hi("DiagnosticVirtualTextWarn", { fg = c.warn, bg = c.bg_line })
hi("DiagnosticVirtualTextInfo", { fg = c.modified, bg = c.bg_line })
hi("DiagnosticVirtualTextHint", { fg = c.cyan, bg = c.bg_line })
hi("DiagnosticFloatingError", { fg = c.red, bg = c.bg_line })
hi("DiagnosticFloatingWarn", { fg = c.warn, bg = c.bg_line })
hi("DiagnosticFloatingInfo", { fg = c.modified, bg = c.bg_line })
hi("DiagnosticFloatingHint", { fg = c.cyan, bg = c.bg_line })
hi("DiagnosticFloatingOk", { fg = c.green, bg = c.bg_line })
hi("DiagnosticSignError", { fg = c.red, bg = c.bg })
hi("DiagnosticSignWarn", { fg = c.warn, bg = c.bg })
hi("DiagnosticSignInfo", { fg = c.modified, bg = c.bg })
hi("DiagnosticSignHint", { fg = c.cyan, bg = c.bg })
hi("DiagnosticUnnecessary", { fg = c.comment, italic = true })
hi("DiagnosticDeprecated", { fg = c.comment, strikethrough = true })

-- Diff / Git
hi("DiffAdd", { fg = c.green, bg = c.diff_ins_bg })
hi("DiffChange", { fg = c.modified, bg = c.diff_mod_bg })
hi("DiffDelete", { fg = c.deleted, bg = c.diff_del_bg })
hi("DiffText", { fg = c.func_call, bg = c.diff_mod_bg })
hi("GitSignsAdd", { fg = c.green })
hi("GitSignsChange", { fg = c.modified })
hi("GitSignsDelete", { fg = c.deleted })
hi("Added", { fg = c.green })
hi("Changed", { fg = c.modified })
hi("Removed", { fg = c.deleted })

-- Telescope
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_line })
hi("TelescopeBorder", { fg = c.border, bg = c.bg_line })
hi("TelescopePromptBorder", { fg = c.border, bg = c.bg_line })
hi("TelescopeSelection", { bg = c.bg_sel })
hi("TelescopeMatching", { fg = c.keyword, bold = true })
hi("TelescopePromptPrefix", { fg = c.keyword })
hi("TelescopeTitle", { fg = c.keyword, bold = true })

-- Completion
hi("CmpItemAbbr", { fg = c.fg })
hi("CmpItemAbbrMatch", { fg = c.keyword, bold = true })
hi("CmpItemAbbrMatchFuzzy", { fg = c.func_call, bold = true })
hi("CmpItemKind", { fg = c.type })
hi("CmpItemMenu", { fg = c.comment })
hi("CmpItemKindFunction", { fg = c.func_decl })
hi("CmpItemKindMethod", { fg = c.func_call })
hi("CmpItemKindVariable", { fg = c.field })
hi("CmpItemKindClass", { fg = c.type })
hi("CmpItemKindInterface", { fg = c.type })
hi("CmpItemKindKeyword", { fg = c.keyword })
hi("CmpItemKindSnippet", { fg = c.label })
hi("CmpItemKindConstant", { fg = c.constant })

-- nvim-tree
hi("NvimTreeNormal", { fg = c.fg, bg = c.bg })
hi("NvimTreeWinSeparator", { fg = c.border, bg = c.bg })
hi("NvimTreeFolderName", { fg = c.func_call })
hi("NvimTreeOpenedFolderName", { fg = c.func_call, bold = true })
hi("NvimTreeRootFolder", { fg = c.keyword, bold = true })
hi("NvimTreeGitDirty", { fg = c.modified })
hi("NvimTreeGitNew", { fg = c.green })
hi("NvimTreeGitDeleted", { fg = c.deleted })
hi("NvimTreeExecFile", { fg = c.string })
hi("NvimTreeIndentMarker", { fg = c.indent })

-- Markdown / Org-ähnliche Überschriften
hi("markdownH1", { fg = c.keyword, bold = true })
hi("markdownH2", { fg = c.func_call, bold = true })
hi("markdownH3", { fg = c.string, bold = true })
hi("markdownCode", { fg = c.predefined })
hi("markdownCodeBlock", { fg = c.predefined })
hi("markdownUrl", { fg = c.link, underline = true })

-- Indent
hi("IblIndent", { fg = c.indent })
hi("IblScope", { fg = c.border })
hi("IndentBlanklineChar", { fg = c.indent })

-- Neotest / Overseer / DAP-UI
hi("NeotestPassed", { fg = c.green })
hi("NeotestFailed", { fg = c.red })
hi("NeotestRunning", { fg = c.keyword })
hi("NeotestSkipped", { fg = c.comment })
hi("NeotestDir", { fg = c.func_call })
hi("NeotestFile", { fg = c.fg })
hi("OverseerSUCCESS", { fg = c.green })
hi("OverseerFAILURE", { fg = c.red })
hi("OverseerCANCELED", { fg = c.warn })
hi("OverseerRUNNING", { fg = c.func_call })
hi("DapUIBreakpointsCurrentLine", { fg = c.keyword, bold = true })
hi("DapUIWatchesEmpty", { fg = c.comment })
hi("DapUIWatchesValue", { fg = c.string })
hi("DapUIWatchesError", { fg = c.red })
hi("DapUIScope", { fg = c.keyword })
hi("DapUIType", { fg = c.type })
hi("DapUIValue", { fg = c.field })
hi("DapUIModifiedValue", { fg = c.warn, bold = true })

-- Datenbank: Dadbod-Ausgabe; DBee nutzt die normalen Syntax-/UI-Gruppen.
hi("dbout", { fg = c.fg, bg = c.bg })

-- which-key
hi("WhichKey", { fg = c.keyword, bold = true })
hi("WhichKeyGroup", { fg = c.func_call })
hi("WhichKeyDesc", { fg = c.fg })
hi("WhichKeySeparator", { fg = c.comment })
hi("WhichKeyFloat", { bg = c.bg_line })

-- DAP
hi("DapBreakpoint", { fg = c.red, bg = c.bg })
hi("DapLogPoint", { fg = c.func_call, bg = c.bg })
hi("DapStopped", { fg = c.string, bg = c.bg_line })

-- Terminal
hi("TermCursor", { fg = c.bg, bg = c.fg_bright })
vim.g.terminal_color_0 = c.bg_line
vim.g.terminal_color_1 = c.red
vim.g.terminal_color_2 = c.string
vim.g.terminal_color_3 = c.keyword
vim.g.terminal_color_4 = c.func_call
vim.g.terminal_color_5 = c.label
vim.g.terminal_color_6 = c.cyan
vim.g.terminal_color_7 = c.fg
vim.g.terminal_color_8 = c.comment
vim.g.terminal_color_9 = c.red
vim.g.terminal_color_10 = c.green
vim.g.terminal_color_11 = c.warn
vim.g.terminal_color_12 = c.blue
vim.g.terminal_color_13 = c.constant
vim.g.terminal_color_14 = c.cyan
vim.g.terminal_color_15 = c.fg_bright

-- lualine kann das Theme über vim.g.colors_name automatisch ableiten;
-- explizite Palette für colejj.statusline_theme bleibt kompatibel.
vim.g.custom_obsidian_lualine = {
  normal = { a = { fg = c.bg, bg = c.func_call, gui = "bold" }, b = { fg = c.fg, bg = c.ml_bg }, c = { fg = c.fg, bg = c.bg } },
  insert = { a = { fg = c.bg, bg = c.green, gui = "bold" } },
  visual = { a = { fg = c.bg, bg = c.keyword, gui = "bold" } },
  replace = { a = { fg = c.bg, bg = c.red, gui = "bold" } },
  command = { a = { fg = c.bg, bg = c.warn, gui = "bold" } },
  inactive = { a = { fg = c.comment, bg = c.bg_line }, b = { fg = c.comment, bg = c.bg_line }, c = { fg = c.comment, bg = c.bg } },
}
