local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local h = require("colejj.snippets.helpers")

ls.add_snippets("kotlin", {
  s("autowired", {
    t({ "@Autowired", "lateinit var " }),
    i(1, "name"),
    t(" : "),
    f(function(args)
      return h.capitalize_camel(args[1][1])
    end, { 1 }),
  }),
})
