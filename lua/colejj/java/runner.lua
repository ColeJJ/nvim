local project = require("colejj.project")
local compat = require("colejj.java.compat")
local idea = require("colejj.java.idea")
local output = require("colejj.java.output")

local M = {
  build_before_run = true,
  build_dependencies = true,
}

local last_run
local source_buf

local function remember(kind, cfg, debug)
  last_run = { kind = kind, cfg = cfg, debug = debug }
end

local function remember_source()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype == "java" or vim.bo[bufnr].filetype == "kotlin" then
    source_buf = bufnr
  end
end

local function restore_source()
  if source_buf and vim.api.nvim_buf_is_valid(source_buf) then
    local wins = vim.fn.win_findbuf(source_buf)
    if #wins > 0 then
      vim.api.nvim_set_current_win(wins[1])
    else
      vim.api.nvim_set_current_buf(source_buf)
    end
    return true
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == "java" then
      vim.api.nvim_set_current_buf(bufnr)
      return true
    end
  end
  return false
end

local function descendant_pids(pid)
  local out = vim.fn.systemlist({ "pgrep", "-P", tostring(pid) })
  local pids = {}
  for _, child in ipairs(out) do
    local n = tonumber(child)
    if n then
      vim.list_extend(pids, descendant_pids(n))
      table.insert(pids, n)
    end
  end
  return pids
end

local function kill_tree(pid)
  for _, child in ipairs(descendant_pids(pid)) do
    pcall(vim.uv.kill, child, "sigkill")
  end
  pcall(vim.uv.kill, pid, "sigkill")
end

local start_mvn

local function maven_args(extra)
  local args = compat.maven_flags()
  vim.list_extend(args, extra)
  return args
end

local function run_maven(cwd, args, title, on_exit)
  local cmd = { project.maven_cmd(cwd) }
  vim.list_extend(cmd, args)
  output.run({
    cmd = cmd,
    cwd = cwd,
    title = title or "Maven",
    on_exit = function(code)
      code = tonumber(code) or code
      if code ~= 0 then
        vim.notify("Build fehlgeschlagen — Start abgebrochen", vim.log.levels.ERROR, { title = "colejj.java" })
        return
      end
      if not on_exit then
        return
      end
      local ok, err = pcall(on_exit)
      if not ok then
        vim.notify("Start nach Build fehlgeschlagen: " .. tostring(err), vim.log.levels.ERROR, { title = "colejj.java" })
      end
    end,
  })
end

local function open_dap_ui()
  local ok, dapui = pcall(require, "dapui")
  if ok then
    dapui.open()
  end
end

local function launch_dap(cfg, debug)
  restore_source()
  local ok_java, java = pcall(require, "java")
  if ok_java and java.dap and java.dap.config_dap then
    pcall(java.dap.config_dap)
  end
  local ok, dap = pcall(require, "dap")
  if not ok then
    vim.notify("nvim-dap ist nicht geladen — starte über Maven", vim.log.levels.WARN, { title = "colejj.java" })
    start_mvn(cfg, debug)
    return
  end
  local wd = idea.expand_wd(cfg)
  compat.sync_extra_classpath(wd)
  local config = {
    type = "java",
    request = "launch",
    name = cfg.name,
    mainClass = cfg.main,
    projectName = cfg.module,
    vmArgs = cfg.vmargs or "",
    args = cfg.args or "",
    cwd = wd,
    env = cfg.envs,
    noDebug = not debug,
    console = "integratedTerminal",
  }
  local ok_run, err = pcall(dap.run, config)
  if not ok_run then
    vim.notify("DAP-Start fehlgeschlagen: " .. tostring(err) .. " — Fallback Maven", vim.log.levels.WARN, { title = "colejj.java" })
    start_mvn(cfg, debug)
    return
  end
  vim.defer_fn(open_dap_ui, 200)
end

local function start_after_build(cfg, debug)
  vim.notify("Build OK — starte " .. (cfg.name or "Run-Config"), vim.log.levels.INFO, { title = "colejj.java" })
  if debug then
    launch_dap(cfg, true)
  else
    -- Run: App-Logs im selben unteren Fenster, wie IntelliJs Run-Tool-Window
    start_mvn(cfg, false)
  end
end

local function maybe_build(cfg, after)
  if not M.build_before_run then
    after()
    return
  end
  local root = project.reactor_root()
  local module = cfg.module or select(1, project.maven_module()) or "."
  local args = maven_args({ "-pl", module, "-am", "-Dmaven.test.skip=true", "compile" })
  run_maven(root, args, "Build: " .. module, after)
end

start_mvn = function(cfg, debug)
  local root = project.reactor_root()
  local wd = idea.expand_wd(cfg)
  local env = vim.tbl_extend("force", vim.fn.environ(), cfg.envs or {})
  local vm = cfg.vmargs or ""
  if debug then
    vm = vm .. " -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
  end
  env.MAVEN_OPTS = vm
  local args = maven_args({
    "compile",
    "exec:java",
    "-Dexec.mainClass=" .. (cfg.main or ""),
    "-Dexec.classpathScope=compile",
  })
  local cmd = { project.maven_cmd(wd or root) }
  vim.list_extend(cmd, args)
  output.run({
    cmd = cmd,
    cwd = wd or root,
    env = env,
    title = (debug and "Debug: " or "Run: ") .. (cfg.name or "mvn"),
  })
  if debug then
    vim.notify("JDWP auf :5005 — mit <leader>da andocken", vim.log.levels.INFO, { title = "colejj.java" })
  end
end

function M.run_config()
  remember_source()
  idea.pick(function(cfg)
    vim.ui.select({ "Run", "Debug" }, { prompt = "Aktion" }, function(action)
      if not action then
        return
      end
      local debug = action == "Debug"
      remember(debug and "dap" or "mvn", cfg, debug)
      maybe_build(cfg, function()
        start_after_build(cfg, debug)
      end)
    end)
  end)
end

function M.run_mvn()
  remember_source()
  idea.pick(function(cfg)
    vim.ui.select({ "Run", "Debug" }, { prompt = "Aktion" }, function(action)
      if not action then
        return
      end
      local debug = action == "Debug"
      remember("mvn", cfg, debug)
      local root = project.reactor_root()
      local module = cfg.module or "."
      if M.build_dependencies then
        run_maven(root, maven_args({ "-pl", module, "-am", "-Dmaven.test.skip=true", "install" }), "Install: " .. module, function()
          start_mvn(cfg, debug)
        end)
      else
        start_mvn(cfg, debug)
      end
    end)
  end)
end

function M.attach()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return
  end
  dap.run({
    type = "java",
    request = "attach",
    name = "Attach :5005",
    hostName = "localhost",
    port = 5005,
  })
  vim.defer_fn(open_dap_ui, 200)
end

function M.stop()
  local stopped = 0
  output.stop()
  stopped = stopped + 1

  local job = output.job()
  if job then
    local ok_info, info = pcall(vim.fn.jobpid, job)
    if ok_info and info and info > 0 then
      kill_tree(info)
    end
  end

  local ok, dap = pcall(require, "dap")
  if ok and dap.session() then
    dap.terminate()
    stopped = stopped + 1
  end
  pcall(function()
    require("dapui").close()
  end)

  vim.notify("Run gestoppt", vim.log.levels.INFO, { title = "colejj.java" })
  return stopped
end

function M.rerun()
  if not last_run then
    vim.notify("Noch kein Run gestartet", vim.log.levels.WARN, { title = "colejj.java" })
    return
  end
  local kind, cfg, debug = last_run.kind, last_run.cfg, last_run.debug
  M.stop()
  vim.defer_fn(function()
    remember(kind, cfg, debug)
    if kind == "mvn" then
      start_mvn(cfg, debug)
    else
      maybe_build(cfg, function()
        launch_dap(cfg, debug)
      end)
    end
  end, 800)
end

function M.hotswap()
  local ok_java, java = pcall(require, "java")
  if ok_java and java.runner and java.runner.built_in then
    pcall(function()
      require("dap").restart()
    end)
    vim.notify("HotSwap / Restart angefordert", vim.log.levels.INFO, { title = "colejj.java" })
    return
  end
  pcall(function()
    require("dap").repl.execute(".hotcode")
  end)
end

function M.spring_run()
  local ok, java = pcall(require, "java")
  if ok and java.runner then
    java.runner.built_in.run_app({})
    return
  end
  M.run_config()
end

M._kill_tree = kill_tree

return M
