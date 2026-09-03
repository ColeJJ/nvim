-- Ein Buffer: Testmethoden mit Lauf-/Haken-/Fehler-Icon, Fehler unter der Methode.

local project = require("colejj.project")
local junit = require("colejj.java.junit")

local M = {}

local ns = vim.api.nvim_create_namespace("colejj-java-test")
local buf, win, job, timer, last
local jobs = {}
local run_gen = 0
local log = {}
local started_at = 0
local locs = {}
local running = false
local expected = {}
local live = {}

local ICONS = {
  pass = "✓",
  fail = "✗",
  skip = "○",
  run = "▶",
}

local function valid_buf()
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function valid_win()
  return win and vim.api.nvim_win_is_valid(win)
end

local function node_text(node, bufnr)
  local ok, value = pcall(vim.treesitter.get_node_text, node, bufnr or 0)
  return ok and value or ""
end

local function find_parent(node, types)
  local parent = node
  while parent do
    if types[parent:type()] then
      return parent
    end
    parent = parent:parent()
  end
end

local function field_ident(node)
  for _, name in ipairs({ "name", "identifier" }) do
    local fields = node:field(name)
    if fields and fields[1] then
      return fields[1]
    end
  end
  for child in node:iter_children() do
    local typ = child:type()
    if typ == "identifier" or typ == "simple_identifier" or typ == "type_identifier" then
      return child
    end
  end
end

local function fqcn_from_path(path)
  local rel = path:match("src/test/java/(.+)")
    or path:match("src/test/kotlin/(.+)")
    or path:match("src/main/java/(.+)")
    or path:match("src/main/kotlin/(.+)")
  if not rel then
    return vim.fn.fnamemodify(path, ":t:r")
  end
  return rel:gsub("%.java$", ""):gsub("%.kt$", ""):gsub("/", ".")
end

local function current_type_suffix(node)
  local names = {}
  local parent = node
  while parent do
    local typ = parent:type()
    if typ == "class_declaration" or typ == "object_declaration" then
      local ident = field_ident(parent)
      if ident then
        table.insert(names, 1, node_text(ident))
      end
    end
    parent = parent:parent()
  end
  if #names == 0 then
    return nil
  end
  return table.concat(names, "$")
end

function M.target(opts)
  opts = opts or {}
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" or not (path:match("%.java$") or path:match("%.kt$")) then
    return nil, "Kein Java-/Kotlin-Buffer"
  end
  local file_fqcn = fqcn_from_path(path)
  local class = file_fqcn
  local method
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = 0 })
  if ok and node then
    local method_node = find_parent(node, {
      method_declaration = true,
      function_declaration = true,
    })
    if method_node then
      local ident = field_ident(method_node)
      if ident then
        method = node_text(ident)
      end
      local nested = current_type_suffix(method_node)
      if nested and nested ~= "" then
        local pkg = file_fqcn:match("^(.*)%.[^%.]+$")
        class = pkg and (pkg .. "." .. nested) or nested
      end
    end
  end
  if opts.class_only then
    method = nil
    class = file_fqcn
  end
  if not class or class == "" then
    return nil, "Keine Testklasse gefunden"
  end
  local spec = class
  if method and method ~= "" then
    spec = class .. "#" .. method
  end
  local module, module_dir = project.maven_module()
  return {
    file = path,
    class = class,
    method = method,
    spec = spec,
    module = module,
    module_dir = module_dir,
    root = project.reactor_root(),
  }
end

local TEST_ANN = {
  Test = true,
  ParameterizedTest = true,
  RepeatedTest = true,
  TestFactory = true,
  TestTemplate = true,
}

local function method_is_test(node)
  local mods = node:field("modifiers")[1] or node:child(0)
  if not mods then
    return false
  end
  local text = node_text(mods)
  for name in text:gmatch("@([%w]+)") do
    if TEST_ANN[name] then
      return true
    end
  end
  return false
end

local function methods_from_file(path)
  local names = {}
  if not path or path == "" or vim.fn.filereadable(path) ~= 1 then
    return names
  end
  local lang = path:match("%.kt$") and "kotlin" or "java"
  local bufnr = vim.fn.bufnr(path)
  local ok, parser
  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  else
    local src = table.concat(vim.fn.readfile(path), "\n")
    ok, parser = pcall(vim.treesitter.get_string_parser, src, lang)
  end
  if not ok or not parser then
    return names
  end
  parser:parse()
  local tree = parser:trees()[1]
  if not tree then
    return names
  end
  local function walk(node)
    local typ = node:type()
    if typ == "method_declaration" or typ == "function_declaration" then
      if method_is_test(node) then
        local ident = field_ident(node)
        if ident then
          names[#names + 1] = node_text(ident, bufnr ~= -1 and bufnr or 0)
        end
      end
    end
    for child in node:iter_children() do
      walk(child)
    end
  end
  walk(tree:root())
  return names
end

local function unescape(text)
  return (text or "")
    :gsub("&lt;", "<")
    :gsub("&gt;", ">")
    :gsub("&amp;", "&")
    :gsub("&quot;", '"')
    :gsub("&apos;", "'")
end

local function attr(tag, name)
  return unescape(tag:match(name .. '%s*=%s*"([^"]*)"') or tag:match(name .. "%s*=%s*'([^']*)'") or "")
end

local function cdata_or(raw)
  if not raw then
    return nil
  end
  return unescape((raw:match("<!%[CDATA%[(.-)%]%]>") or raw):gsub("\r\n", "\n"))
end

local function inner(body, tag)
  return cdata_or(body:match("<" .. tag .. "[^>]*>(.-)</" .. tag .. ">"))
end

local function child_block(body, tag)
  local open = body:match("<" .. tag .. "([^>]*)>")
  if not open then
    return nil, nil, nil
  end
  return unescape(attr(open, "message")), inner(body, tag), unescape(attr(open, "type"))
end

local function parse_suite(xml)
  local open = xml:match("<testsuite([^>]*)>")
  if not open then
    return nil
  end
  local suite = {
    name = attr(open, "name"),
    tests = tonumber(attr(open, "tests")) or 0,
    failures = tonumber(attr(open, "failures")) or 0,
    errors = tonumber(attr(open, "errors")) or 0,
    skipped = tonumber(attr(open, "skipped")) or 0,
    time = tonumber(attr(open, "time")) or 0,
    cases = {},
  }
  local i = 1
  while true do
    local s, e = xml:find("<testcase", i, true)
    if not s then
      break
    end
    local gt = xml:find(">", e, true)
    if not gt then
      break
    end
    local head = xml:sub(s, gt)
    local body = ""
    if head:find("/>%s*$") then
      i = gt + 1
    else
      local close = xml:find("</testcase>", gt, true)
      if not close then
        break
      end
      body = xml:sub(gt + 1, close - 1)
      i = close + 11
    end
    local status = "pass"
    local message, trace, errtype
    if body:find("<failure") then
      status = "fail"
      message, trace, errtype = child_block(body, "failure")
    elseif body:find("<error") then
      status = "fail"
      message, trace, errtype = child_block(body, "error")
    elseif body:find("<skipped") then
      status = "skip"
      message = select(1, child_block(body, "skipped"))
    end
    suite.cases[#suite.cases + 1] = {
      name = attr(head, "name"),
      classname = attr(head, "classname"),
      time = tonumber(attr(head, "time")) or 0,
      status = status,
      message = message,
      trace = trace,
      errtype = errtype,
    }
  end
  return suite
end

local function format_time(sec)
  local ms = math.floor((sec or 0) * 1000 + 0.5)
  if ms >= 1000 then
    local s = math.floor(ms / 1000)
    local rem = ms % 1000
    if rem == 0 then
      return s .. " sec"
    end
    return string.format("%d sec %d ms", s, rem)
  end
  return ms .. " ms"
end

local function report_dirs(target)
  local dirs = {}
  local seen = {}
  local function add(dir)
    if dir and not seen[dir] and vim.fn.isdirectory(dir) == 1 then
      seen[dir] = true
      dirs[#dirs + 1] = dir
    end
  end
  add(target and target.reports_dir)
  local bases = {}
  if target and target.module_dir then
    bases[#bases + 1] = target.module_dir
  end
  if target and target.root then
    bases[#bases + 1] = target.root
  end
  for _, base in ipairs(bases) do
    for _, rel in ipairs({
      "target/junit-console-reports",
      "target/surefire-reports",
      "target/failsafe-reports",
    }) do
      add(base .. "/" .. rel)
    end
  end
  return dirs
end

local function collect_suites(target)
  local suites = {}
  local seen = {}
  for _, dir in ipairs(report_dirs(target)) do
        for _, file in ipairs(vim.fn.glob(dir .. "/*.xml", false, true)) do
      local stat = vim.uv.fs_stat(file)
      if stat and stat.mtime.sec + 2 >= math.floor(started_at) and not seen[file] then
        seen[file] = true
        local xml = table.concat(vim.fn.readfile(file), "\n")
        local suite = parse_suite(xml)
        if suite and (not target.class or suite.name:find(target.class, 1, true) or target.class:find(suite.name, 1, true)) then
          suites[#suites + 1] = suite
        end
      end
    end
  end
  table.sort(suites, function(a, b)
    return (a.name or "") < (b.name or "")
  end)
  return suites
end

local function find_source(fqcn, root)
  if not fqcn or fqcn == "" then
    return nil
  end
  local rel = fqcn:gsub("%$", "."):gsub("%.", "/")
  local found = vim.fs.find({ rel .. ".java", rel .. ".kt" }, {
    path = root or project.reactor_root(),
    type = "file",
    limit = 1,
    upward = false,
  })
  return found[1]
end

local function jump_to(loc)
  if not loc then
    return
  end
  local file = loc.file or find_source(loc.classname or loc.class, last and last.root)
  if not file then
    vim.notify("Quelle nicht gefunden", vim.log.levels.WARN, { title = "Tests" })
    return
  end
  vim.cmd("wincmd p")
  vim.cmd.edit(vim.fn.fnameescape(file))
  if loc.method and loc.method ~= "" then
    local name = loc.method:match("^([%w_]+)") or loc.method
    pcall(vim.fn.search, "\\<" .. vim.fn.escape(name, "\\") .. "\\s*(", "w")
    pcall(vim.cmd.normal, { "zvzz", bang = true })
  end
end

local function hl_for(status)
  if status == "pass" then
    return "ColejjTestPass"
  end
  if status == "fail" then
    return "ColejjTestFail"
  end
  if status == "skip" then
    return "ColejjTestSkip"
  end
  return "ColejjTestRun"
end

local function first_error_line(case)
  if case.errtype and case.errtype ~= "" then
    local msg = case.message
    if msg and msg ~= "" and not msg:find(case.errtype, 1, true) then
      return case.errtype .. ": " .. msg:match("^[^\n]*")
    end
    return case.errtype
  end
  if case.message and case.message ~= "" then
    return case.message:match("^[^\n]*")
  end
  if case.trace and case.trace ~= "" then
    return case.trace:match("^[^\n]*")
  end
  return "Test failed"
end

local function short_trace(trace)
  local lines = {}
  if not trace or trace == "" then
    return lines
  end
  local n = 0
  for line in (trace .. "\n"):gmatch("([^\n]*)\n") do
    if line:find("at ") then
      n = n + 1
      if n > 6 then
        lines[#lines + 1] = "        …"
        break
      end
      lines[#lines + 1] = "        " .. vim.trim(line)
    end
  end
  return lines
end

local function ensure_window()
  if valid_buf() and valid_win() then
    return
  end
  if not valid_buf() then
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = "colejj-test"
    pcall(vim.api.nvim_buf_set_name, buf, "Test-Ergebnisse")
  end
  if not valid_win() then
    local src = vim.api.nvim_get_current_win()
    local width = math.max(48, math.floor(vim.o.columns * 0.38))
    vim.cmd("botright vsplit")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_width(win, width)
    vim.wo[win].winfixwidth = true
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].wrap = false
    vim.wo[win].cursorline = true
    if vim.api.nvim_win_is_valid(src) then
      vim.api.nvim_set_current_win(src)
    end
  end
  local opts = { buffer = buf, silent = true }
  vim.keymap.set("n", "q", M.close, vim.tbl_extend("force", opts, { desc = "Testergebnisse schließen" }))
  vim.keymap.set("n", "g", M.rerun, vim.tbl_extend("force", opts, { desc = "Tests erneut" }))
  vim.keymap.set("n", "<CR>", function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local loc = locs[lnum]
    if not loc then
      for i = lnum, 1, -1 do
        if locs[i] then
          loc = locs[i]
          break
        end
      end
    end
    jump_to(loc)
  end, vim.tbl_extend("force", opts, { desc = "Zur Testmethode" }))
end

local function paint(lines, highlights)
  ensure_window()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for _, hl in ipairs(highlights) do
    if hl.virt then
      vim.api.nvim_buf_set_extmark(buf, ns, hl.line, 0, {
        virt_text = hl.virt,
        virt_text_pos = "eol",
      })
    else
      pcall(vim.api.nvim_buf_add_highlight, buf, ns, hl.group, hl.line, hl.col or 0, hl.end_col or -1)
    end
  end
  vim.bo[buf].modifiable = false
end

local function add(lines, highlights, locs_map, text, group, loc, time)
  lines[#lines + 1] = text
  local lnum = #lines
  if group then
    highlights[#highlights + 1] = { group = group, line = lnum - 1 }
  end
  if time then
    highlights[#highlights + 1] = { line = lnum - 1, virt = { { "  " .. format_time(time), "Comment" } } }
  end
  if loc then
    locs_map[lnum] = loc
  end
end

local function case_key(name)
  return (name or ""):match("^([%w_]+)") or name
end

local function merge_cases(suites)
  local by_name = {}
  local order = {}
  for _, name in ipairs(expected) do
    if not by_name[name] then
      by_name[name] = live[name] or { name = name, status = running and "run" or "skip", time = 0 }
      order[#order + 1] = name
    end
  end
  for name, case in pairs(live) do
    if not by_name[name] then
      by_name[name] = case
      order[#order + 1] = name
    end
  end
  for _, suite in ipairs(suites) do
    for _, case in ipairs(suite.cases) do
      local key = case_key(case.name)
      if not by_name[key] then
        order[#order + 1] = key
      end
      by_name[key] = case
    end
  end
  local out = {}
  for _, name in ipairs(order) do
    out[#out + 1] = by_name[name]
  end
  return out
end

local function render(opts)
  opts = opts or {}
  running = opts.running == true
  locs = {}
  local lines, highlights = {}, {}
  local target = last
  local suites = target and collect_suites(target) or {}
  local simple = target and ((target.class or ""):match("([^%.]+)$") or target.spec or "Tests") or "Tests"

  if opts.compile_failed and #suites == 0 then
    add(lines, highlights, locs, ICONS.fail .. "  Build fehlgeschlagen", "ColejjTestFail")
    add(lines, highlights, locs, "")
    for _, line in ipairs(log) do
      if line:find("%[ERROR%]") or line:find("FAILURE") or line:find("error:") then
        add(lines, highlights, locs, "  " .. line, "ColejjTestFail")
      end
    end
    paint(lines, highlights)
    return
  end

  local parsed = junit.parse_console(log, target and target.class)
  if parsed then
    for _, case in ipairs(parsed.cases) do
      live[case_key(case.name)] = case
    end
  end
  local cases = merge_cases(suites)
  local failed, passed = 0, 0
  for _, case in ipairs(cases) do
    if case.status == "fail" then
      failed = failed + 1
    elseif case.status == "pass" then
      passed = passed + 1
    end
  end
  local class_status = running and #suites == 0 and "run" or (failed > 0 and "fail" or (#cases > 0 and "pass" or "run"))
  add(lines, highlights, locs, ICONS[class_status] .. "  " .. simple, hl_for(class_status), {
    class = target and target.class,
    classname = target and target.class,
    file = target and target.file,
  })
  if running and #suites == 0 then
    add(lines, highlights, locs, "    " .. (target.phase or "Tests laufen …"), "ColejjTestRun")
  end

  for _, case in ipairs(cases) do
    local loc = {
      class = target and target.class,
      classname = case.classname ~= "" and case.classname or (target and target.class),
      method = case_key(case.name),
      file = target and target.file,
    }
    add(
      lines,
      highlights,
      locs,
      "    " .. ICONS[case.status] .. "  " .. case.name,
      hl_for(case.status),
      loc,
      case.time > 0 and case.time or nil
    )
    if case.status == "fail" then
      add(lines, highlights, locs, "        " .. first_error_line(case), "ColejjTestFail", loc)
      for _, line in ipairs(short_trace(case.trace)) do
        add(lines, highlights, locs, line, "Comment", loc)
      end
    end
  end

  if #cases == 0 and not running then
    add(lines, highlights, locs, "    Keine Testergebnisse", "Comment")
  end
  paint(lines, highlights)
end

local function stop_timer()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

local function job_running(id)
  return id and vim.fn.jobwait({ id }, 0)[1] == -1
end

local function any_running()
  for _, id in ipairs(jobs) do
    if job_running(id) then
      return true
    end
  end
  return false
end

function M.stop()
  run_gen = run_gen + 1
  for _, id in ipairs(jobs) do
    if job_running(id) then
      pcall(vim.fn.jobstop, id)
    end
  end
  jobs = {}
  job = nil
  stop_timer()
  running = false
end

function M.close()
  if valid_win() then
    vim.api.nvim_win_close(win, true)
  end
  win = nil
end

function M.toggle()
  if valid_win() then
    M.close()
    return
  end
  if last then
    ensure_window()
    render()
  else
    vim.notify("Noch kein Testlauf", vim.log.levels.INFO, { title = "Tests" })
  end
end

local function start_watch()
  stop_timer()
  timer = vim.uv.new_timer()
  timer:start(250, 250, vim.schedule_wrap(function()
    if any_running() then
      render({ running = true })
    end
  end))
end

local function append_log(data)
  if not data then
    return
  end
  for _, line in ipairs(data) do
    if line ~= "" then
      log[#log + 1] = line
    end
  end
end

local function start_cmd(cmd, cwd, on_exit)
  local id = vim.fn.jobstart(cmd, {
    cwd = cwd,
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      append_log(data)
    end,
    on_stderr = function(_, data)
      append_log(data)
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        on_exit(code)
      end)
    end,
  })
  if not id or id <= 0 then
    on_exit(1)
    return
  end
  jobs[#jobs + 1] = id
  job = id
end

local function run_target(target)
  if not target or not target.root then
    vim.notify("Kein Maven-Projekt", vim.log.levels.WARN, { title = "Tests" })
    return
  end
  M.stop()
  local this_run = run_gen
  last = target
  log = {}
  live = {}
  started_at = os.time()
  if target.method then
    expected = { target.method }
  else
    expected = methods_from_file(target.file)
  end
  if target.file and vim.bo.modified and vim.api.nvim_buf_get_name(0) == target.file then
    pcall(vim.cmd.write)
  end
  target.reports_dir = (target.module_dir or target.root) .. "/target/junit-console-reports"
  vim.fn.delete(target.reports_dir, "rf")
  vim.fn.mkdir(target.reports_dir, "p")
  ensure_window()
  target.phase = "Starte …"
  render({ running = true })

  local compile_done, compile_ok = false, true
  local cp_done, classpath = false, nil
  local started_junit = false

  local function set_phase()
    if not compile_done then
      target.phase = "Kompiliere …"
    elseif not cp_done then
      target.phase = "Classpath …"
    else
      target.phase = "Tests laufen …"
    end
  end

  local function alive()
    return this_run == run_gen
  end

  local function finish_run(code)
    if not alive() then
      return
    end
    job = nil
    stop_timer()
    local suites = collect_suites(target)
    local parsed = junit.parse_console(log, target.class)
    if parsed then
      for _, case in ipairs(parsed.cases) do
        live[case_key(case.name)] = case
      end
    end
    render({ compile_failed = code ~= 0 and #suites == 0 and not parsed })
  end

  local function try_junit()
    if not alive() or started_junit or not compile_done or not cp_done then
      return
    end
    if not compile_ok then
      finish_run(1)
      return
    end
    started_junit = true
    target.phase = "Tests laufen …"
    local cmd = junit.run_cmd(target, classpath)
    local cwd = target.module_dir or target.root
    if not cmd then
      cmd = junit.surefire_cmd(target)
      cwd = target.root
    end
    start_cmd(cmd, cwd, finish_run)
  end

  if junit.needs_compile(target) then
    compile_ok = false
    target.phase = "Kompiliere …"
    start_cmd(junit.compile_cmd(target), target.root, function(code)
      if not alive() then
        return
      end
      compile_ok = code == 0
      compile_done = true
      set_phase()
      try_junit()
    end)
  else
    compile_done = true
  end

  if not compile_done then
    target.phase = "Kompiliere …"
  else
    target.phase = "Classpath …"
  end
  junit.ensure_classpath(target, function(cp)
    if not alive() then
      return
    end
    classpath = cp
    cp_done = true
    set_phase()
    try_junit()
  end, function(id)
    jobs[#jobs + 1] = id
    job = id
  end)

  try_junit()
  start_watch()
end

function M.run_at_point()
  local target, err = M.target()
  if not target then
    vim.notify(err, vim.log.levels.WARN, { title = "Tests" })
    return
  end
  run_target(target)
end

function M.run_class()
  local target, err = M.target({ class_only = true })
  if not target then
    vim.notify(err, vim.log.levels.WARN, { title = "Tests" })
    return
  end
  run_target(target)
end

function M.run_module()
  local module, module_dir = project.maven_module()
  run_target({
    spec = nil,
    class = nil,
    module = module,
    module_dir = module_dir,
    root = project.reactor_root(),
  })
end

function M.rerun()
  if not last then
    vim.notify("Kein letzter Testlauf", vim.log.levels.INFO, { title = "Tests" })
    return
  end
  run_target(last)
end

function M.setup()
  vim.api.nvim_set_hl(0, "ColejjTestPass", { default = true, link = "NeotestPassed" })
  vim.api.nvim_set_hl(0, "ColejjTestFail", { default = true, link = "NeotestFailed" })
  vim.api.nvim_set_hl(0, "ColejjTestSkip", { default = true, link = "NeotestSkipped" })
  vim.api.nvim_set_hl(0, "ColejjTestRun", { default = true, link = "NeotestRunning" })

  vim.api.nvim_create_user_command("JavaTestAtPoint", M.run_at_point, { desc = "Test unter Cursor" })
  vim.api.nvim_create_user_command("JavaTestClass", M.run_class, { desc = "Testklasse ausführen" })
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
  end
  map("<leader>rtt", M.run_at_point, "Test unter Cursor")
  map("<leader>rta", M.run_class, "Tests dieser Klasse")
  map("<leader>rtl", M.rerun, "Letzten Test wiederholen")
  map("<leader>rto", M.toggle, "Testergebnisse")
  map("<leader>rts", M.toggle, "Testergebnisse")
  map("<leader>rtS", M.stop, "Tests stoppen")
end

return M
