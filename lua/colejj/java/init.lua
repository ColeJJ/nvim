local M = {}

function M.setup()
  require("colejj.java.lsp").configure()
  require("colejj.java.lsp").setup_navigation()
  require("colejj.java.classpath").setup()
  require("colejj.java.final").setup()
  require("colejj.java.keymaps").setup()
end

return M
