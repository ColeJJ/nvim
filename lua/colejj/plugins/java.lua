return {
  {
    "nvim-java/nvim-java",
    ft = { "java", "kotlin", "jproperties" },
    init = function()
      -- reactor_root() fällt auf Git-Root oder cwd zurück und wäre immer wahr.
      -- Hier zählt nur ein echtes pom.xml in der Verzeichniskette.
      local function in_maven_project(file)
        local dir = vim.fn.fnamemodify(file, ":p:h")
        while dir and dir ~= "" do
          if vim.uv.fs_stat(dir .. "/pom.xml") then
            return true
          end
          local parent = vim.fn.fnamemodify(dir, ":h")
          if parent == dir then
            return false
          end
          dir = parent
        end
        return false
      end

      vim.api.nvim_create_autocmd("BufReadPost", {
        group = vim.api.nvim_create_augroup("colejj-java-project-files", { clear = true }),
        pattern = {
          "pom.xml",
          "application*.yml",
          "application*.yaml",
          "bootstrap*.yml",
          "bootstrap*.yaml",
        },
        callback = function(ev)
          if in_maven_project(ev.file) then
            require("lazy").load({ plugins = { "nvim-java" } })
          end
        end,
      })
    end,
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
        java_test = { enable = false },
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
