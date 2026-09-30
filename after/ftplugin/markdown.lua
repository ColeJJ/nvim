vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.conceallevel = 2
vim.opt_local.concealcursor = "nvc"

-- Treesitter faerbt die Klammern von [!] und [B] als Link (kursiv, unterstrichen).
-- Das Muster gilt fuer jeden Shortcut-Link. Hier wird es abgeschaltet; die Query
-- darunter setzt es nur fuer echte Links wieder.
if not vim.g.colejj_md_shortcut_patched then
  local query = vim.treesitter.query.get("markdown_inline", "highlights")
  if query then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "[!]" })
    local parser = vim.treesitter.get_parser(buf, "markdown_inline")
    parser:parse(true)
    local root = parser:trees()[1]:root()
    local seen = {}
    for pattern, match, metadata in query:iter_matches(root, buf, 0, -1, { all = true }) do
      if metadata.conceal == "" and not seen[pattern] then
        for id, nodes in pairs(match) do
          local node = nodes[1] or nodes
          if query.captures[id] == "markup.link" and type(node) ~= "table" then
            local text = vim.treesitter.get_node_text(node, buf)
            if text == "[" or text == "]" then
              seen[pattern] = true
              query.query:disable_pattern(pattern)
            end
          end
        end
      end
    end
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.g.colejj_md_shortcut_patched = true
  end
end
