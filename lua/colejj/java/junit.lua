-- Schneller JUnit-Lauf wie Doom/IntelliJ: Console-Standalone + Maven-Classpath.
-- Kein `mvn -am test` (voller Reactor + Surefire).

local project = require("colejj.project")
local compat = require("colejj.java.compat")
local jdk = require("colejj.java.jdk")

local M = {}

local cp_cache = {}

local function java_bin()
  local home = jdk.jdtls_home() or os.getenv("JAVA_HOME")
  if home and vim.uv.fs_stat(home .. "/bin/java") then
    return home .. "/bin/java"
  end
  return "java"
end

function M.runner_jar()
  local m2 = vim.fn.expand("~/.m2/repository/org/junit/platform/junit-platform-console-standalone")
  if vim.fn.isdirectory(m2) ~= 1 then
    return nil
  end
  local jars = vim.fn.glob(m2 .. "/**/junit-platform-console-standalone-*.jar", false, true)
  table.sort(jars)
  return jars[#jars]
end

local function modern_cli(jar)
  local major, minor = jar:match("standalone%-(%d+)%.(%d+)")
  major, minor = tonumber(major), tonumber(minor)
  return major and (major > 1 or (major == 1 and minor >= 10))
end

local function reactor_output_dirs(root)
  local dirs = {}
  local seen = {}
  local function add(dir)
    if dir ~= "" and not seen[dir] and vim.fn.isdirectory(dir) == 1 then
      seen[dir] = true
      dirs[#dirs + 1] = dir
    end
  end
  root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  for _, pom in ipairs(vim.fs.find("pom.xml", { path = root, type = "file", limit = 80 })) do
    if not pom:find("/target/", 1, true) and not pom:find("/bin/", 1, true) then
      local dir = vim.fn.fnamemodify(pom, ":h")
      add(dir .. "/target/test-classes")
      add(dir .. "/target/classes")
    end
  end
  for _, dir in ipairs(compat.kotlin_output_dirs(root)) do
    add(dir)
  end
  return dirs
end

local function class_file(target)
  if not target.class or target.class == "" then
    return nil
  end
  local rel = target.class:gsub("%$", "/"):gsub("%.", "/") .. ".class"
  for _, base in ipairs({ target.module_dir, target.root }) do
    if base then
      local path = base .. "/target/test-classes/" .. rel
      if vim.fn.filereadable(path) == 1 then
        return path
      end
    end
  end
end

function M.needs_compile(target)
  if not target.class then
    local dir = (target.module_dir or target.root) .. "/target/test-classes"
    return vim.fn.isdirectory(dir) ~= 1
  end
  local compiled = class_file(target)
  if not compiled then
    return true
  end
  if not target.file or vim.fn.filereadable(target.file) ~= 1 then
    return false
  end
  local src = vim.uv.fs_stat(target.file)
  local cls = vim.uv.fs_stat(compiled)
  return src and cls and src.mtime.sec > cls.mtime.sec
end

function M.compile_cmd(target)
  local cmd = { project.maven_cmd(target.root) }
  vim.list_extend(cmd, compat.maven_flags(target.root))
  vim.list_extend(cmd, { "-o", "-q", "-DskipTests", "test-compile" })
  if target.module and target.module ~= "." then
    vim.list_extend(cmd, { "-pl", target.module })
  end
  return cmd
end

local function assemble(target, deps)
  local paths = {}
  local seen = {}
  local function add(path)
    if path and path ~= "" and not seen[path] then
      seen[path] = true
      paths[#paths + 1] = path
    end
  end
  for _, dir in ipairs(reactor_output_dirs(target.root)) do
    add(dir)
  end
  if target.module_dir then
    for _, rel in ipairs(compat.extra_classpath_dirs or {}) do
      add(target.module_dir .. "/" .. rel)
    end
  end
  for _, dep in ipairs(deps or {}) do
    add(dep)
  end
  if #paths == 0 then
    return nil
  end
  return table.concat(paths, ":")
end

local function read_deps(file)
  if vim.fn.filereadable(file) ~= 1 then
    return {}
  end
  local raw = table.concat(vim.fn.readfile(file), ""):gsub("%s+$", "")
  pcall(vim.fn.delete, file)
  if raw == "" then
    return {}
  end
  return vim.split(raw, ":", { plain = true, trimempty = true })
end

local function classpath_cmd(target, offline)
  local cmd = { project.maven_cmd(target.root) }
  vim.list_extend(cmd, compat.maven_flags(target.root))
  cmd[#cmd + 1] = "-q"
  if offline then
    cmd[#cmd + 1] = "-o"
  end
  vim.list_extend(cmd, {
    "dependency:build-classpath",
    "-DincludeScope=test",
  })
  return cmd
end

function M.ensure_classpath(target, cb, track)
  local cwd = target.module_dir or target.root
  local key = vim.fn.fnamemodify(cwd, ":p")
  if cp_cache[key] then
    cb(cp_cache[key])
    return
  end
  local function resolve(offline, after)
    local out = vim.fn.tempname()
    local cmd = classpath_cmd(target, offline)
    vim.list_extend(cmd, {
      "-Dmdep.outputFile=" .. out,
      "-Dmdep.pathSeparator=:",
    })
    local id = vim.fn.jobstart(cmd, {
      cwd = cwd,
      on_exit = function()
        vim.schedule(function()
          after(read_deps(out))
        end)
      end,
    })
    if id and id > 0 and track then
      track(id)
    end
    if not id or id <= 0 then
      after({})
    end
  end
  resolve(true, function(deps)
    if #deps == 0 then
      resolve(false, function(online_deps)
        local joined = assemble(target, online_deps)
        if joined then
          cp_cache[key] = joined
        end
        cb(joined)
      end)
      return
    end
    local joined = assemble(target, deps)
    if joined then
      cp_cache[key] = joined
    end
    cb(joined)
  end)
end

function M.run_cmd(target, classpath)
  local jar = M.runner_jar()
  local cp = classpath or cp_cache[vim.fn.fnamemodify(target.module_dir or target.root, ":p")]
  if not jar or not cp then
    return nil
  end
  local reports = target.reports_dir
  local cmd = { java_bin(), "-jar", jar }
  if modern_cli(jar) then
    vim.list_extend(cmd, {
      "execute",
      "--disable-banner",
      "--disable-ansi-colors",
      "--details=tree",
      "--class-path=" .. cp,
    })
    if reports then
      cmd[#cmd + 1] = "--reports-dir=" .. reports
    end
    if target.method and target.class then
      cmd[#cmd + 1] = "--select-method=" .. target.class .. "#" .. target.method
    elseif target.class then
      cmd[#cmd + 1] = "--select-class=" .. target.class
    else
      cmd[#cmd + 1] = "--scan-class-path=" .. (target.module_dir or target.root) .. "/target/test-classes"
    end
  else
    vim.list_extend(cmd, { "-cp", cp, "--disable-banner", "--disable-ansi-colors", "--details=tree" })
    if reports then
      cmd[#cmd + 1] = "--reports-dir=" .. reports
    end
    if target.method and target.class then
      vim.list_extend(cmd, { "-m", target.class .. "#" .. target.method })
    elseif target.class then
      vim.list_extend(cmd, { "-c", target.class })
    else
      vim.list_extend(cmd, { "--scan-class-path", (target.module_dir or target.root) .. "/target/test-classes" })
    end
  end
  return cmd
end

function M.parse_console(lines, class_name)
  local cases = {}
  local by_name = {}
  local function add(name, status, message)
    name = (name or ""):gsub("%(%)%s*$", "")
    if name == "" then
      return
    end
    local case = by_name[name]
    if not case then
      case = { name = name, classname = class_name or "", time = 0, status = status }
      by_name[name] = case
      cases[#cases + 1] = case
    end
    case.status = status
    if message then
      case.message = message
    end
    return case
  end
  local last_name
  local capturing
  for _, line in ipairs(lines or {}) do
    local name = line:match("([%w_]+)%(%)")
    if name then
      last_name = name
      capturing = nil
      if line:find("✘") or line:find("✗") or line:find("FAILED") or line:find("%[X%]") then
        capturing = add(name, "fail")
      elseif line:find("✔") or line:find("✓") or line:find("%[OK%]") then
        add(name, "pass")
      end
    elseif capturing then
      local trimmed = vim.trim(line)
      if trimmed ~= "" then
        if not capturing.message and (trimmed:find("Exception") or trimmed:find("Assertion") or trimmed:find("Error")) then
          capturing.message = trimmed
        end
        capturing.trace = (capturing.trace and (capturing.trace .. "\n") or "") .. trimmed
      end
    elseif last_name and (line:find("Exception") or line:find("Assertion")) then
      capturing = add(last_name, "fail", vim.trim(line))
    end
  end
  if #cases == 0 then
    return nil
  end
  local failed = 0
  for _, case in ipairs(cases) do
    if case.status == "fail" then
      failed = failed + 1
    end
  end
  return {
    name = class_name or "Tests",
    tests = #cases,
    failures = failed,
    errors = 0,
    skipped = 0,
    time = 0,
    cases = cases,
  }
end

function M.surefire_cmd(target)
  local cmd = { project.maven_cmd(target.root) }
  vim.list_extend(cmd, compat.maven_flags(target.root))
  vim.list_extend(cmd, { "-o" })
  if target.module and target.module ~= "." then
    vim.list_extend(cmd, { "-pl", target.module })
  end
  vim.list_extend(cmd, {
    "test",
    "-Dmaven.test.failure.ignore=true",
    "-Dsurefire.failIfNoSpecifiedTests=false",
    "-DfailIfNoTests=false",
  })
  if target.spec and target.spec ~= "" then
    cmd[#cmd + 1] = "-Dtest=" .. target.spec
  end
  return cmd
end

return M
