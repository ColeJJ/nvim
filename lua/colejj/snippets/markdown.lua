local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

-- friendly-snippets liefert h1–h6, link, img, table, task, codeblock, Callouts.
-- Hier nur die Lücken: Frontmatter und ein kurzer Codeblock.
ls.add_snippets("markdown", {
  s({ trig = "fm", name = "Frontmatter", dscr = "YAML-Frontmatter" }, {
    t({ "---", "title: " }),
    i(1, "Titel"),
    t({ "", "---", "" }),
    i(0),
  }),
  s({ trig = "fence", name = "Codeblock", dscr = "Fenced Codeblock mit Sprache" }, {
    t("```"),
    i(1, "java"),
    t({ "", "" }),
    i(2),
    t({ "", "```" }),
  }),
})
