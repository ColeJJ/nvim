return {
  {
    "nvim-java/nvim-java",
    ft = { "java", "kotlin", "xml", "yaml", "jproperties" },
    dependencies = {
      "MunifTanjim/nui.nvim",
      "mfussenegger/nvim-dap",
      "neovim/nvim-lspconfig",
      "JavaHello/spring-boot.nvim",
    },
    config = function()
      local jdk = require("colejj.java.jdk")
      require("java").setup({
        checks = {
          -- 0.11.0 startet; nvim-java testet offiziell erst ab 0.11.5.
          nvim_version = false,
          nvim_jdtls_conflict = true,
        },
        lombok = { enable = true },
        java_test = { enable = true },
        java_debug_adapter = { enable = true },
        spring_boot_tools = { enable = true },
        jdk = {
          auto_install = jdk.jdtls_home() == nil,
          path = jdk.jdtls_home(),
        },
        experimental = {
          fix_generated_sources = true,
        },
      })
      require("colejj.java").setup()
      vim.lsp.enable("jdtls")
    end,
  },
}
