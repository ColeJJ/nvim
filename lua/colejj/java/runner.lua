local project = require("colejj.project")
local compat = require("colejj.java.compat")
local idea = require("colejj.java.idea")
local output = require("colejj.java.output")

local M = {
  build_before_run = true,
  build_dependencies = true,
  debug_port = 5005,
  classpath_file = "target/nvim-classpath.txt",
  args_file = "target/nvim-run.args",
}

local last_run
local source_buf

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "colejj.java" })
end

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
      vim.cmd("wincmd p")
    end
    return true
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

local function maven_args(extra)
  local args = compat.maven_flags()
  vim.list_extend(args, extra)
  return args
end

local function mvn_cmd(root, extra)
  local cmd = { project.maven_cmd(root) }
  vim.list_extend(cmd, maven_args(extra))
  return cmd
end

local function run_maven(cwd, args, title, on_success)
  output.run({
    cmd = mvn_cmd(cwd, args),
    cwd = cwd,
    title = title or "Maven",
    on_exit = on_success and function(code)
      code = tonumber(code) or code
      if code ~= 0 then
        notify("Build fehlgeschlagen — Start abgebrochen", vim.log.levels.ERROR)
        return
      end
      local ok, err = pcall(on_success)
      if not ok then
        notify("Start nach Build fehlgeschlagen: " .. tostring(err), vim.log.levels.ERROR)
      end
    end,
  })
end

--- Shell-artiges Aufteilen von VM-/Programm-Parametern (Quotes, Backslash).
local function split_args(str)
  local args = {}
  if type(str) ~= "string" then
    return args
  end
  local current, quote, has_token = {}, nil, false
  local i = 1
  while i <= #str do
    local c = str:sub(i, i)
    if quote then
      if c == quote then
        quote = nil
      elseif c == "\\" and quote == '"' and i < #str then
        i = i + 1
        current[#current + 1] = str:sub(i, i)
      else
        current[#current + 1] = c
      end
    elseif c == '"' or c == "'" then
      quote = c
      has_token = true
    elseif c:match("%s") then
      if has_token then
        args[#args + 1] = table.concat(current)
        current, has_token = {}, false
      end
    elseif c == "\\" and i < #str then
      i = i + 1
      current[#current + 1] = str:sub(i, i)
      has_token = true
    else
      current[#current + 1] = c
      has_token = true
    end
    i = i + 1
  end
  if has_token then
    args[#args + 1] = table.concat(current)
  end
  return args
end

local function has_arg(args, prefix)
  for _, arg in ipairs(args) do
    if vim.startswith(arg, prefix) then
      return true
    end
  end
  return false
end

local function port_free(port)
  local tcp = vim.uv.new_tcp()
  local ok = tcp:bind("127.0.0.1", port) and tcp:listen(1, function() end)
  tcp:close()
  return ok == 0 or ok == true
end

local function free_port()
  local tcp = vim.uv.new_tcp()
  tcp:bind("127.0.0.1", 0)
  local addr = tcp:getsockname()
  tcp:close()
  return addr and addr.port
end

local function debug_port()
  if port_free(M.debug_port) then
    return M.debug_port
  end
  return free_port() or M.debug_port
end

--- Reactor-Root, Modulpfad relativ zum Root (für -pl) und Modulverzeichnis.
local function module_context(cfg)
  local module_dir = idea.module_dir(cfg)
  local root = vim.fn.fnamemodify(project.reactor_root(module_dir), ":p"):gsub("/$", "")
  module_dir = module_dir and vim.fn.fnamemodify(module_dir, ":p"):gsub("/$", "") or nil
  if not module_dir then
    local _, current = project.maven_module()
    module_dir = current and vim.fn.fnamemodify(current, ":p"):gsub("/$", "") or root
  end
  local rel = module_dir == root and "." or module_dir:sub(#root + 2)
  return root, rel, module_dir
end

--- Ein Maven-Lauf: Modul + Abhängigkeiten bauen (inkl. Test-Klassen, falls ein
--- test-jar eines Reactor-Moduls im Classpath liegt) und Classpath mit Scopes
--- in target/nvim-classpath.txt schreiben. Im Reactor zeigen Geschwistermodule
--- dabei auf ihre target/classes bzw. target/test-classes – wie in IntelliJ.
local function build_args(rel)
  local args = {}
  local active = table.concat(compat.maven_flags(), " ")
  local profiles = vim.tbl_filter(function(profile)
    return not active:find("-P" .. profile, 1, true)
  end, idea.maven_profiles())
  if #profiles > 0 then
    args[#args + 1] = "-P" .. table.concat(profiles, ",")
  end
  if rel ~= "." then
    vim.list_extend(args, { "-pl", rel })
    if M.build_dependencies then
      args[#args + 1] = "-am"
    end
  end
  vim.list_extend(args, {
    "test-compile",
    "dependency:list",
    "-DoutputAbsoluteArtifactFilename=true",
    "-Dmdep.outputScope=true",
    "-DoutputFile=" .. M.classpath_file,
  })
  return args
end

local function read_classpath(cfg, module_dir)
  local file = module_dir .. "/" .. M.classpath_file
  if not vim.uv.fs_stat(file) then
    return nil
  end
  local entries = { module_dir .. "/target/classes" }
  local seen = { [entries[1]] = true }
  for _, line in ipairs(vim.fn.readfile(file)) do
    local clean = vim.trim(line):gsub("%s+%-%-%s+module%s.*$", ""):gsub("%s*%(optional%)%s*$", "")
    local scope, path = clean:match(":(%a+):(/.+)$")
    if scope and path then
      path = vim.trim(path)
      local wanted = scope == "compile"
        or scope == "runtime"
        or scope == "system"
        or (scope == "provided" and cfg.include_provided)
      if wanted and not seen[path] then
        seen[path] = true
        entries[#entries + 1] = path
      end
    end
  end
  return entries
end

local function write_args_file(module_dir, classpath)
  local file = module_dir .. "/" .. M.args_file
  vim.fn.mkdir(vim.fn.fnamemodify(file, ":h"), "p")
  local cp = table.concat(classpath, ":"):gsub("\\", "\\\\"):gsub('"', '\\"')
  vim.fn.writefile({ "-cp", '"' .. cp .. '"' }, file)
  return file
end

local function ensure_java_adapter()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return nil
  end
  if not dap.adapters.java then
    local ok_java, java = pcall(require, "java")
    if ok_java and java.dap and java.dap.config_dap then
      pcall(java.dap.config_dap)
      vim.wait(10000, function()
        return dap.adapters.java ~= nil
      end, 100)
    end
  end
  return dap.adapters.java and dap or nil
end

local function attach_dap(dap, cfg, port)
  restore_source()
  local ok, err = pcall(dap.run, {
    type = "java",
    request = "attach",
    name = (cfg.name or "Java") .. " (Debug :" .. port .. ")",
    hostName = "127.0.0.1",
    port = port,
    projectName = cfg.module,
  })
  if not ok then
    notify("DAP-Attach fehlgeschlagen: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function launch(cfg, debug, module_dir)
  local classpath = read_classpath(cfg, module_dir)
  if not classpath then
    notify("Kein Classpath gefunden (" .. M.classpath_file .. ") — bitte mit Build starten", vim.log.levels.ERROR)
    return
  end

  local java = idea.java_executable(cfg)
  local wd = idea.expand_wd(cfg)
  local cmd = { java }
  local vm = split_args(cfg.vmargs)
  if not has_arg(vm, "-Dfile.encoding=") then
    cmd[#cmd + 1] = "-Dfile.encoding=UTF-8"
  end
  vim.list_extend(cmd, vm)

  local dap, port
  if debug then
    dap = ensure_java_adapter()
    port = debug_port()
    -- Ohne DAP-Adapter nicht suspendieren, sonst hängt die JVM bis zum manuellen Attach.
    local suspend = dap and "y" or "n"
    cmd[#cmd + 1] = "-agentlib:jdwp=transport=dt_socket,server=y,suspend=" .. suspend .. ",address=127.0.0.1:" .. port
    if not dap then
      notify("Kein Java-DAP-Adapter (JDT.LS noch nicht bereit) — JVM lauscht auf :" .. port, vim.log.levels.WARN)
    end
  end

  cmd[#cmd + 1] = "@" .. write_args_file(module_dir, classpath)
  cmd[#cmd + 1] = cfg.main
  vim.list_extend(cmd, split_args(cfg.args))

  local attached = false
  output.run({
    cmd = cmd,
    cwd = wd,
    env = cfg.envs,
    title = (debug and "Debug: " or "Run: ") .. (cfg.name or cfg.main),
    on_output = dap and function(lines)
      if attached then
        return
      end
      for _, line in ipairs(lines) do
        if line:find("Listening for transport dt_socket", 1, true) then
          attached = true
          vim.schedule(function()
            attach_dap(dap, cfg, port)
          end)
          return
        end
      end
    end or nil,
  })
end

function M.start(cfg, debug)
  if not cfg.main or cfg.main == "" then
    notify("Run-Config ohne Main-Klasse: " .. tostring(cfg.name), vim.log.levels.ERROR)
    return
  end
  remember("java", cfg, debug)
  if cfg.before_launch and #cfg.before_launch > 0 then
    notify(
      "Before-Launch-Tasks werden nicht ausgeführt: " .. table.concat(cfg.before_launch, ", "),
      vim.log.levels.WARN
    )
  end

  local root, rel, module_dir = module_context(cfg)
  local has_classpath = vim.uv.fs_stat(module_dir .. "/" .. M.classpath_file) ~= nil
  if not M.build_before_run or (cfg.make == false and has_classpath) then
    launch(cfg, debug, module_dir)
    return
  end
  run_maven(root, build_args(rel), "Build: " .. (cfg.name or rel), function()
    notify("Build OK — starte " .. (cfg.name or cfg.main))
    launch(cfg, debug, module_dir)
  end)
end

function M.run_config()
  remember_source()
  idea.pick(function(cfg)
    vim.ui.select({ "Run", "Debug" }, { prompt = "Aktion" }, function(action)
      if action then
        M.start(cfg, action == "Debug")
      end
    end)
  end)
end

local function start_mvn(cfg, debug)
  local root, rel, module_dir = module_context(cfg)
  local wd = idea.expand_wd(cfg)
  local env = vim.deepcopy(cfg.envs or {})
  local vm = vim.trim(cfg.vmargs or "")
  if debug then
    vm = (vm ~= "" and (vm .. " ") or "")
      .. "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:"
      .. M.debug_port
  end
  if vm ~= "" then
    env.MAVEN_OPTS = vm
  end
  local args = {
    "-f",
    module_dir .. "/pom.xml",
    "exec:java",
    "-Dexec.mainClass=" .. cfg.main,
    "-Dexec.classpathScope=" .. (cfg.include_provided and "compile" or "runtime"),
    "-Dexec.cleanupDaemonThreads=false",
  }
  if cfg.args and cfg.args ~= "" then
    args[#args + 1] = "-Dexec.args=" .. cfg.args
  end
  output.run({
    cmd = mvn_cmd(root, args),
    cwd = wd,
    env = env,
    title = (debug and "Debug: " or "Run: ") .. (cfg.name or "mvn"),
  })
  if debug then
    notify("JDWP auf :" .. M.debug_port .. " — mit <leader>da andocken")
  end
  return rel
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
      local root, rel = module_context(cfg)
      if M.build_dependencies and rel ~= "." then
        run_maven(root, { "-pl", rel, "-am", "-Dmaven.test.skip=true", "install" }, "Install: " .. rel, function()
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
    name = "Attach :" .. M.debug_port,
    hostName = "localhost",
    port = M.debug_port,
  })
end

function M.stop()
  local job = output.job()
  local pid
  if job then
    local ok_info, info = pcall(vim.fn.jobpid, job)
    if ok_info and info and info > 0 then
      pid = info
    end
  end

  local ok, dap = pcall(require, "dap")
  if ok and dap.session() then
    pcall(dap.terminate)
  end
  pcall(function()
    require("dapui").close()
  end)

  output.stop()
  if pid then
    vim.defer_fn(function()
      if vim.uv.kill(pid, 0) == 0 then
        kill_tree(pid)
      end
    end, 3000)
  end

  notify("Run gestoppt")
end

function M.rerun()
  if not last_run then
    notify("Noch kein Run gestartet", vim.log.levels.WARN)
    return
  end
  local kind, cfg, debug = last_run.kind, last_run.cfg, last_run.debug
  M.stop()
  vim.defer_fn(function()
    if kind == "mvn" then
      remember(kind, cfg, debug)
      start_mvn(cfg, debug)
    else
      M.start(cfg, debug)
    end
  end, 800)
end

function M.hotswap()
  local ok_java, java = pcall(require, "java")
  if ok_java and java.runner and java.runner.built_in then
    pcall(function()
      require("dap").restart()
    end)
    notify("HotSwap / Restart angefordert")
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
M._split_args = split_args

return M
