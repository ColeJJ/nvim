return {
  { "nvim-neotest/nvim-nio", lazy = true },
  {
    "mfussenegger/nvim-dap",
    keys = {
      { "<leader>dd" },
      { "<leader>db" },
      { "<leader>dc" },
      { "<leader>dl" },
      { "<leader>dn" },
      { "<leader>di" },
      { "<leader>do" },
      { "<leader>dq" },
      { "<leader>dL" },
      { "<leader>dh", mode = { "n", "x" } },
      { "<leader>de" },
      { "<leader>dw" },
      { "<leader>dr" },
      { "<leader>du", mode = { "n", "v" } },
      { "<leader>dU", mode = { "n", "v" } },
      { "<F5>" },
      { "<F7>" },
      { "<F8>" },
    },
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      require("nvim-dap-virtual-text").setup({
        commented = true,
        -- Werte an der Definition und an jeder Verwendung, auch vor dem Breakpoint.
        all_references = true,
        highlight_changed_variables = true,
      })

      dapui.setup({
        icons = { expanded = "▾", collapsed = "▸" },
        mappings = {
          expand = { "<CR>", "<2-LeftMouse>" },
          open = "o",
          remove = "d",
          edit = "e",
          repl = "r",
        },
        layouts = {
          {
            elements = {
              { id = "scopes", size = 0.25 },
              { id = "watches", size = 0.25 },
              { id = "stacks", size = 0.25 },
              { id = "breakpoints", size = 0.25 },
            },
            size = 40,
            position = "right",
          },
          {
            elements = { { id = "repl", size = 0.5 }, { id = "console", size = 0.5 } },
            size = 10,
            position = "bottom",
          },
        },
        floating = {
          border = "single",
          mappings = { close = { "q", "<Esc>" } },
        },
      })

      vim.api.nvim_set_hl(0, "DapBreakpoint", { ctermbg = 0, fg = "#993939", bg = "#31353f" })
      vim.api.nvim_set_hl(0, "DapLogPoint", { ctermbg = 0, fg = "#61afef", bg = "#31353f" })
      vim.api.nvim_set_hl(0, "DapStopped", { ctermbg = 0, fg = "#98c379", bg = "#31353f" })
      vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DapBreakpoint", linehl = "DapBreakpoint", numhl = "DapBreakpoint" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "󰯲", texthl = "DapBreakpoint", linehl = "DapBreakpoint", numhl = "DapBreakpoint" })
      vim.fn.sign_define("DapStopped", { text = "", texthl = "DapStopped", linehl = "DapStopped", numhl = "DapStopped" })

      local function expression_at_cursor()
        local mode = vim.fn.mode()
        if mode == "v" or mode == "V" or mode == "\22" then
          local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
          return table.concat(lines, "\n")
        end
        return vim.fn.expand("<cexpr>")
      end

      -- Aufklappbares Fenster wie IntelliJ: Wert, Felder, verschachtelte Objekte.
      -- Zweites Aufrufen derselben Variable springt in das Fenster (<CR> klappt auf).
      local function eval_here()
        local expr = vim.trim(expression_at_cursor() or "")
        if expr == "" then
          return
        end
        require("dapui").eval(expr, { context = "hover", enter = false })
      end

      local mouse_eval = false
      local function set_mouse_eval(enabled)
        if enabled == mouse_eval then
          return
        end
        mouse_eval = enabled
        if enabled then
          vim.keymap.set("n", "<2-LeftMouse>", eval_here, { silent = true, desc = "Variable auswerten" })
        else
          pcall(vim.keymap.del, "n", "<2-LeftMouse>")
        end
      end

      -- DAP-UI erst beim ersten Breakpoint, nicht schon beim Launch.
      dap.listeners.after.event_initialized["dapui_config"] = function() end
      dap.listeners.after.event_stopped["colejj_dapui"] = function(_, body)
        set_mouse_eval(true)
        local reason = body and body.reason or ""
        if reason == "breakpoint" or reason == "exception" then
          dapui.open()
        end
      end
      dap.listeners.after.event_continued["colejj_dapui"] = function()
        set_mouse_eval(false)
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        set_mouse_eval(false)
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        set_mouse_eval(false)
        dapui.close()
      end

      dap.defaults.fallback.terminal_win_cmd = function()
        return require("colejj.java.output").ensure("Debug Console")
      end

      -- Java Attach (Launch-Configs kommen von nvim-java / idea-Picker)
      dap.configurations.java = dap.configurations.java or {}
      table.insert(dap.configurations.java, {
        type = "java",
        request = "attach",
        name = "Attach :5005",
        hostName = "localhost",
        port = 5005,
      })

      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
      end
      map("<leader>dd", dap.continue, "Continue / Start")
      map("<leader>db", dap.toggle_breakpoint, "Breakpoint")
      map("<leader>dc", function()
        dap.set_breakpoint(vim.fn.input("Bedingung: "))
      end, "Bedingter Breakpoint")
      map("<leader>dl", function()
        dap.set_breakpoint(nil, nil, vim.fn.input("Log: "))
      end, "Logpoint")
      map("<leader>dn", dap.step_over, "Step Over")
      map("<leader>di", dap.step_into, "Step Into")
      map("<leader>do", dap.step_out, "Step Out")
      map("<leader>dq", dap.terminate, "Session beenden")
      map("<leader>dL", dap.run_last, "Letzten Debug wiederholen")
      map("<leader>dh", eval_here, "Variable unter Cursor")
      vim.keymap.set("x", "<leader>dh", eval_here, { silent = true, desc = "Auswahl auswerten" })
      map("<leader>de", function()
        vim.ui.input({ prompt = "Ausdruck: " }, function(expr)
          if expr and expr ~= "" then
            require("dapui").eval(expr, { context = "repl", enter = true })
          end
        end)
      end, "Ausdruck eingeben")
      map("<leader>dw", function()
        require("dapui").elements.watches.add()
      end, "Watch hinzufügen")
      map("<leader>dr", dap.repl.open, "REPL")
      map("<F5>", dap.continue, "Continue")
      map("<F7>", dap.step_into, "Step Into")
      map("<F8>", dap.step_over, "Step Over")
      vim.keymap.set({ "n", "v" }, "<leader>du", dapui.toggle, { desc = "DAP-UI" })
      vim.keymap.set({ "n", "v" }, "<leader>dU", function()
        dapui.open({ reset = true })
      end, { desc = "DAP-Layout neu aufbauen" })
    end,
  },
  {
    "mxsdev/nvim-dap-vscode-js",
    dependencies = { "mfussenegger/nvim-dap" },
    ft = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
    config = function()
      local debugger = vim.fn.stdpath("data") .. "/lazy/vscode-js-debug"
      if not vim.uv.fs_stat(debugger) then
        debugger = os.getenv("HOME") .. "/.local/share/nvim/site/pack/packer/opt/vscode-js-debug"
      end
      require("dap-vscode-js").setup({
        debugger_path = debugger,
        adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
      })
      local dap = require("dap")
      for _, ext in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
        dap.configurations[ext] = {
          {
            type = "pwa-node",
            request = "launch",
            name = "Launch Current File (pwa-node with ts-node)",
            args = { "${relativeFile}" },
            runtimeArgs = { "-r", "ts-node/register" },
            runtimeExecutable = "node",
            cwd = "${workspaceFolder}",
            protocol = "inspector",
            sourceMaps = true,
            skipFiles = { "<node_internals>/**", "node_modules/**" },
          },
        }
      end
    end,
  },
  { "rcarriga/nvim-dap-ui", lazy = true },
}
