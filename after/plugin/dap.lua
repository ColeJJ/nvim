local dap = require("dap")
local dapui = require("dapui")
local dapGo = require("dap-go")

-- dab ui
-- dap.listeners.after.event_initialized["dapui_config"] = function()
--   dapui.open()
-- end
-- dap.listeners.before.event_terminated["dapui_config"] = function()
--   dapui.close()
-- end
-- dap.listeners.before.event_exited["dapui_config"] = function()
--   dapui.close()
-- end

-- PHP
dap.adapters.php = {
  type = 'executable',
  command = 'node',
  args = { os.getenv("HOME") .. '/.vscode-server/extensions/xdebug.php-debug-1.32.1/out/phpDebug.js' }
}

dap.configurations.php = {
  {
    type = 'php',
    request = 'launch',
    name = 'Listen for Xdebug',
    port = 9000,
    -- pathMappings = {
    --     ["/var/www/html"] = "${workspaceFolder}"
    --     -- { localRoot = '${workspaceRoot}', remoteRoot = '.' }
    -- }
  }
}

-- GO
dapGo.setup()

-- maps
require("colejj.debugmaps")
