local M = {}

function M.setup()
  require("colejj.java.lsp").configure()
  require("colejj.java.lsp").setup_navigation()
  require("colejj.java.classpath").setup()
  require("colejj.java.final").setup()
  require("colejj.java.keymaps").setup()
  require("colejj.java.select").patch_nvim_java()
  require("colejj.java.accessors").patch_nvim_java()
end

return M
