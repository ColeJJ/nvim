-- Java Language Server configuration.
-- Locations:
-- 'nvim/ftplugin/java.lua'.
-- 'nvim/lang-servers/intellij-java-google-style.xml'

local jdtls = pcall(require, "jdtls")
if not jdtls then
  vim.notify "JDTLS not found, install with `:LspInstall jdtls`"
  return
end

-- PATHES
-- vim.fn.stdpath('data') = /Users/tounland/.local/share/nvim
local jdtls_path = vim.fn.stdpath('data') .. "/mason/packages/jdtls"
local path_to_config_server = jdtls_path .. "/config_mac"
local path_to_plugins = jdtls_path .. "/plugins/"
local path_to_jar = path_to_plugins .. "org.eclipse.equinox.launcher_1.6.700.v20231214-2017.jar"
local lombok_path = jdtls_path .. "/lombok.jar"
local jvm_path = '/Library/Java/JavaVirtualMachines'
local jdk_21_path = jvm_path .. '/jdk-21.jdk'
local jdk_20_path = jvm_path .. '/jdk-20.jdk'
local jdk_19_path = jvm_path .. '/jdk-19.jdk'
local jdk_17_path= jvm_path .. '/jdk-17.jdk'

local root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }
local root_dir = require("jdtls.setup").find_root(root_markers)
if root_dir == "" then
  vim.notify "Root Dir not found."
  return
end

-- WORKSPACE WITH PROJECT 
-- local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
-- local HOME = os.getenv "HOME"
-- local workspace_dir = HOME .. "/ghq/java_workspace/neovim_ws/" .. project_name

-- WORKSPACE WITHOUT PROJECT
local HOME = os.getenv "HOME"
local workspace_dir = HOME .. "/personal/java_workspaces/neovim_ws/"

-- os.execute("mkdir " .. workspace_dir)

local on_attach = function(client, bufnr)
  -- java bindings
  jdtls.setup.add_commands()
  jdtls.setup_dap({ hotcodereplace = 'auto' })
  local opts = { noremap=true, silent=true, buffer=bufnr }
      -- Java specific
      vim.keymap.set("n", "<leader>or", function() jdtls.organize_imports() end, opts)
      vim.keymap.set("n", "<leader>dt", function() jdtls.test_class() end, opts)
      vim.keymap.set("n", "<leader>dn", function() jdtls.test_nearest_method() end, opts)
      vim.keymap.set("n", "<leader>de", function() jdtls.extract_variable(true) end, opts)
      vim.keymap.set("n", "<leader>de", function() jdtls.extract_variable() end, opts)
      vim.keymap.set("n", "<leader>dm", function() jdtls.extract_method(true) end, opts)
  -- debug maps 
  require("colejj.debugmaps")
end

-- setting capabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Main Config
local config = {
  -- The command that starts the language server
  -- See: https://github.com/eclipse/eclipse.jdt.ls#running-from-the-command-line
  cmd = {
    'java',
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=ALL',
    '-Xms1g',
    '--add-modules=ALL-SYSTEM',
    '--add-opens', 'java.base/java.util=ALL-UNNAMED',
    '--add-opens', 'java.base/java.lang=ALL-UNNAMED',

    '-javaagent:' .. lombok_path,
    '-jar', path_to_jar,
    '-configuration', path_to_config_server,
    '-data', workspace_dir,
  },

  root_dir = root_dir,
  on_attach = on_attach,
  capabilities = capabilities,

  -- Here you can configure eclipse.jdt.ls specific settings
  -- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
  -- for a list of options
  settings = {
    java = {
      home = jvm_path .. jdk_21_path .. '/Contents/Home',
      configuration = {
        updateBuildConfiguration = "interactive",
        runtimes = {
          {
            name = "JavaSE-21",
            path = jdk_21_path .. "/Contents/Home",
          },
          {
            name = "JavaSE-20",
            path = jdk_20_path .. "/Contents/Home",
          },
          {
            name = "JavaSE-19",
            path = jdk_19_path .. "/Contents/Home",
          },
          {
            name = "JavaSE-17",
            path = jdk_17_path .. "/Contents/Home",
          }
        }
      },
      import = {
          maven = {
              enabled =  true
          },
          gradle = {
              enabled =  true
          }
      },
      maven = {
        downloadSources = true,
      },
      eclipse = {
        downloadSources = true,
      },
      jdt = {
          ls = {
              lombokSupport = true
          }
      },
      implementationsCodeLens = {
        enabled = true,
      },
      referencesCodeLens = {
        enabled = true,
      },
      references = {
        includeDecompiledSources = true,
      },
      format = {
        enabled = true,
        settings = {
          url = vim.fn.stdpath "config" .. "/lang-servers/intellij-java-google-style.xml",
          profile = "GoogleStyle",
        },
      },
      saveActions = {
          organizeImports = true
      },
      signatureHelp = { enabled = true },
      completion = {
          favoriteStaticMembers = {
              "org.hamcrest.MatcherAssert.assertThat",
              "org.hamcrest.Matchers.*",
              "org.hamcrest.CoreMatchers.*",
              "org.junit.jupiter.api.Assertions.*",
              "java.util.Objects.requireNonNull",
              "java.util.Objects.requireNonNullElse",
              "org.mockito.Mockito.*",
          },
          importOrder = {
              "java",
              "javax",
              "com",
              "org"
          },
          filteredTypes = {
              "com.sun.*",
              "io.micrometer.shaded.*",
              "java.awt.*",
              "jdk.*", "sun.*",
          },
      },
      sources = {
          organizeImports = {
              starThreshold = 9999,
              staticStarThreshold = 9999,
          },
      },
      codeGeneration = {
          toString = {
              template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
          },
          useBlocks = true,
      },
    },
  },

  flags = {
    allow_incremental_sync = true,
  },
}

-- settings init_options 
local extendedClientCapabilities = require('jdtls').extendedClientCapabilities;
extendedClientCapabilities.resolveAdditionalTextEditsSupport = true;
config['init_options'] = {
    bundles = {
        vim.fn.glob(HOME.. "/.config/java/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-0.45.0.jar", 1)
    },
    extendedClientCapabilities = extendedClientCapabilities;
}

-- This starts a new client & server,
-- or attaches to an existing client & server depending on the `root_dir`.
require('jdtls').start_or_attach(config)
