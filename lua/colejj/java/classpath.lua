local project = require("colejj.project")

local M = {}

local APT_MARKER = ".jdtls-enable-apt"
local repair_timer

local function read_text(path)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end
  return table.concat(vim.fn.readfile(path), "\n")
end

local function write_text(path, text)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile(vim.split(text, "\n", { plain = true }), path)
end

local function relpath(path, root)
  local abs = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
  local base = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  if abs:sub(1, #base + 1) == base .. "/" then
    return abs:sub(#base + 2)
  end
  return abs
end

local function reactor_module_dirs(root)
  root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  local dirs = { root }
  local handle = vim.uv.fs_scandir(root)
  if not handle then
    return dirs
  end
  while true do
    local name, typ = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if typ == "directory" and not name:match("^%.") then
      local dir = root .. "/" .. name
      if vim.uv.fs_stat(dir .. "/.classpath") or vim.uv.fs_stat(dir .. "/pom.xml") then
        table.insert(dirs, dir)
      end
    end
  end
  return dirs
end

local function maven_module_dirs(root)
  root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  local dirs = {}
  local seen = {}
  local function add(dir)
    dir = vim.fn.fnamemodify(dir, ":p"):gsub("/$", "")
    if not seen[dir] then
      seen[dir] = true
      table.insert(dirs, dir)
    end
  end
  add(root)
  for _, pom in ipairs(vim.fs.find("pom.xml", { path = root, type = "file", limit = 80 })) do
    if not pom:find("/target/", 1, true) and not pom:find("/bin/", 1, true) then
      add(vim.fn.fnamemodify(pom, ":h"))
    end
  end
  return dirs
end

local function file_package(path)
  local text = read_text(path)
  if not text then
    return nil
  end
  return text:sub(1, 4000):match("package%s+([%w_.]+)%s*;")
end

local function source_root_of(file)
  local pkg = file_package(file)
  if not pkg then
    return nil
  end
  local tail = pkg:gsub("%.", "/") .. "/" .. vim.fn.fnamemodify(file, ":t")
  if file:sub(-#tail) == tail then
    return file:sub(1, #file - #tail - 1)
  end
end

local function generated_source_roots(module_dir)
  local gen = module_dir .. "/target/generated-sources"
  if vim.fn.isdirectory(gen) == 0 then
    return {}
  end
  local files = vim.fs.find(function(name)
    return name:sub(-5) == ".java"
  end, { path = gen, type = "file", limit = 400 })
  local seen = {}
  local roots = {}
  for _, file in ipairs(files) do
    local root = source_root_of(file)
    if root and not seen[root] then
      seen[root] = true
      table.insert(roots, root)
    end
  end
  return roots
end

local function classpath_add_src(module_dir, rel)
  local cp = module_dir .. "/.classpath"
  local text = read_text(cp)
  if not text or text:find('path="' .. rel .. '"', 1, true) then
    return false
  end
  local entry = table.concat({
    '\t<classpathentry kind="src" path="' .. rel .. '">',
    "\t\t<attributes>",
    '\t\t\t<attribute name="optional" value="true"/>',
    "\t\t</attributes>",
    "\t</classpathentry>\n",
  }, "\n")
  if not text:find("</classpath>", 1, true) then
    return false
  end
  write_text(cp, (text:gsub("</classpath>", entry .. "</classpath>", 1)))
  return true
end

local function strip_classpath_entry(text, needle)
  local pos = text:find(needle, 1, true)
  if not pos then
    return text, false
  end
  local line_start = 1
  for i = pos, 1, -1 do
    if text:sub(i, i) == "\n" then
      line_start = i + 1
      break
    end
  end
  local close = text:find("</classpathentry>", pos, true)
  if not close then
    return text, false
  end
  local after = close + #"</classpathentry>"
  if text:sub(after, after) == "\n" then
    after = after + 1
  end
  return text:sub(1, line_start - 1) .. text:sub(after), true
end

local function classpath_add_lib(module_dir, lib)
  local cp = module_dir .. "/.classpath"
  local rel = relpath(lib, module_dir)
  local text = read_text(cp)
  if not text then
    return false
  end
  local needle = 'kind="lib" path="' .. rel .. '"'
  local existing = text:find(needle, 1, true)
  local output_at = text:find('<classpathentry kind="output"', 1, true)
  if existing and output_at and existing > output_at then
    text = select(1, strip_classpath_entry(text, needle))
    existing = nil
  end
  if existing then
    return false
  end
  local entry = table.concat({
    '\t<classpathentry kind="lib" path="' .. rel .. '">',
    "\t\t<attributes>",
    '\t\t\t<attribute name="optional" value="true"/>',
    "\t\t</attributes>",
    "\t</classpathentry>\n",
  }, "\n")
  output_at = text:find('<classpathentry kind="output"', 1, true)
  if output_at then
    text = text:sub(1, output_at - 1) .. entry .. text:sub(output_at)
  elseif text:find("</classpath>", 1, true) then
    text = text:gsub("</classpath>", entry .. "</classpath>", 1)
  else
    return false
  end
  write_text(cp, text)
  return true
end

local function classpath_remove_lib(module_dir, lib)
  local cp = module_dir .. "/.classpath"
  local rel = relpath(lib, module_dir)
  local text = read_text(cp)
  if not text then
    return false
  end
  local updated, changed = strip_classpath_entry(text, 'kind="lib" path="' .. rel .. '"')
  if not changed then
    return false
  end
  write_text(cp, updated)
  return true
end

local function pom_depends_on(module_dir, artifact)
  local text = read_text(module_dir .. "/pom.xml")
  return text ~= nil and text:find("<artifactId>" .. artifact .. "</artifactId>", 1, true) ~= nil
end

local function module_has_kotlin(module_dir)
  local src = module_dir .. "/src/main"
  if vim.fn.isdirectory(src) == 0 then
    return false
  end
  return #vim.fs.find(function(name)
    return name:sub(-3) == ".kt"
  end, { path = src, type = "file", limit = 1 }) > 0
end

local function newer_class_than(output, jar)
  if vim.fn.filereadable(jar) ~= 1 then
    return true
  end
  local jar_stat = vim.uv.fs_stat(jar)
  local classes = vim.fs.find(function(name)
    return name:sub(-6) == ".class"
  end, { path = output, type = "file", limit = 80 })
  for _, class in ipairs(classes) do
    local st = vim.uv.fs_stat(class)
    if st and jar_stat and st.mtime.sec > jar_stat.mtime.sec then
      return true
    end
  end
  return false
end

local function kotlin_output_jar(module_dir)
  local output = module_dir .. "/target/classes"
  if vim.fn.isdirectory(output) == 0 then
    return nil
  end
  local has_class = #vim.fs.find(function(name)
    return name:sub(-6) == ".class"
  end, { path = output, type = "file", limit = 1 }) > 0
  if not has_class then
    return nil
  end
  local jar = module_dir .. "/.jdtls-kotlin-output.jar"
  if newer_class_than(output, jar) then
    pcall(vim.fn.delete, jar)
    local result = vim.system({ "jar", "cf", jar, "-C", output, "." }):wait()
    if result.code ~= 0 then
      return nil
    end
  end
  if vim.fn.filereadable(jar) == 1 then
    return jar
  end
end

local function set_eclipse_pref(file, key, value)
  local contents = read_text(file) or "eclipse.preferences.version=1\n"
  local lines = vim.split(contents, "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines)
  end
  local line = key .. "=" .. value
  local found = false
  local changed = false
  for i, existing in ipairs(lines) do
    if existing:sub(1, #key + 1) == key .. "=" then
      found = true
      if existing ~= line then
        lines[i] = line
        changed = true
      end
      break
    end
  end
  if not found then
    table.insert(lines, line)
    changed = true
  end
  if not changed then
    return nil
  end
  write_text(file, table.concat(lines, "\n") .. "\n")
  return file
end

function M.notify_changed(files)
  local client = require("colejj.java.lsp").client()
  if not client then
    return
  end
  local changes = {}
  local seen = {}
  for _, file in ipairs(files or {}) do
    local abs = vim.fn.fnamemodify(file, ":p")
    if not seen[abs] and vim.uv.fs_stat(abs) then
      seen[abs] = true
      table.insert(changes, { uri = vim.uri_from_fname(abs), type = 2 })
    end
  end
  if #changes > 0 then
    client:notify("workspace/didChangeWatchedFiles", { changes = changes })
  end
end

function M.ensure_generated_source_roots(root)
  root = root or project.reactor_root()
  local changed_files = {}
  for _, mod in ipairs(reactor_module_dirs(root)) do
    for _, sr in ipairs(generated_source_roots(mod)) do
      if classpath_add_src(mod, relpath(sr, mod)) then
        table.insert(changed_files, mod .. "/.classpath")
      end
    end
  end
  M.notify_changed(changed_files)
  return changed_files
end

function M.ensure_kotlin_output(root)
  root = root or project.reactor_root()
  local modules = reactor_module_dirs(root)
  local changed_files = {}
  for _, producer in ipairs(modules) do
    if module_has_kotlin(producer) then
      local classes = producer .. "/target/classes"
      local jar = kotlin_output_jar(producer)
      if jar and vim.fn.isdirectory(classes) == 1 then
        table.insert(changed_files, jar)
        local artifact = vim.fn.fnamemodify(producer, ":t")
        local legacy = producer .. "/target/.jdtls-kotlin-output.jar"
        local local_jar = producer .. "/.jdtls-kotlin-output.jar"
        for _, consumer in ipairs(modules) do
          if consumer == producer or pom_depends_on(consumer, artifact) then
            local desired = consumer == producer and jar or classes
            for _, stale in ipairs({ legacy, local_jar, classes }) do
              if stale ~= desired and classpath_remove_lib(consumer, stale) then
                table.insert(changed_files, consumer .. "/.classpath")
              end
            end
            if classpath_add_lib(consumer, desired) then
              table.insert(changed_files, consumer .. "/.classpath")
            end
          end
        end
      end
    end
  end
  M.notify_changed(changed_files)
  return changed_files
end

function M.ensure_apt_disabled(root)
  root = root or project.reactor_root()
  local changed = {}
  for _, mod in ipairs(maven_module_dirs(root)) do
    if vim.fn.filereadable(mod .. "/" .. APT_MARKER) ~= 1 then
      local settings = mod .. "/.settings"
      local apt = set_eclipse_pref(settings .. "/org.eclipse.jdt.apt.core.prefs", "org.eclipse.jdt.apt.aptEnabled", "false")
      local core = set_eclipse_pref(
        settings .. "/org.eclipse.jdt.core.prefs",
        "org.eclipse.jdt.core.compiler.processAnnotations",
        "disabled"
      )
      if apt then
        table.insert(changed, apt)
      end
      if core then
        table.insert(changed, core)
      end
    end
  end
  M.notify_changed(changed)
  return changed
end

function M.repair(root)
  root = root or project.reactor_root()
  local ok, experimental = pcall(require, "java.experimental.fix-generated-sources")
  if ok and experimental.patch then
    pcall(experimental.patch, root)
  end
  M.ensure_generated_source_roots(root)
  M.ensure_kotlin_output(root)
  M.ensure_apt_disabled(root)
end

function M.schedule_repair(seconds, root)
  if repair_timer then
    repair_timer:stop()
    repair_timer = nil
  end
  repair_timer = vim.defer_fn(function()
    repair_timer = nil
    M.repair(root)
  end, (seconds or 12) * 1000)
end

function M.setup()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("colejj-java-classpath", { clear = true }),
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client.name == "jdtls" then
        M.schedule_repair(25, client.config.root_dir)
      end
    end,
  })
end

return M
