local project = require("colejj.project")
local jdk = require("colejj.java.jdk")
local compat = require("colejj.java.compat")

local M = {}

local function maven_user_settings()
  local path = vim.fn.expand("~/.m2/settings.xml")
  if vim.uv.fs_stat(path) then
    return path
  end
end

function M.settings()
  local formatter = vim.fn.stdpath("config") .. "/formatter/gc-eclipse-format.xml"
  local user_settings = maven_user_settings()
  return {
    java = {
      home = jdk.jdtls_home(),
      eclipse = { downloadSources = false },
      maven = { downloadSources = false },
      -- Eclipse-Incremental-Build würde nach target/classes schreiben und
      -- dadurch mvn clean blockieren (Datei-Locks). Diagnostik/Completion
      -- laufen weiter über reconcile-on-type, ohne auf Disk zu bauen.
      autobuild = { enabled = false },
      maxConcurrentBuilds = 1,
      import = {
        maven = {
          enabled = true,
          offline = { enabled = compat.detect() or user_settings ~= nil },
        },
        gradle = { enabled = false },
        generatesMetadataFilesAtProjectRoot = true,
      },
      configuration = {
        updateBuildConfiguration = "automatic",
        runtimes = jdk.runtimes(),
        maven = user_settings and { userSettings = user_settings } or nil,
      },
      references = { includeDecompiledSources = false },
      implementationsCodeLens = { enabled = true },
      referencesCodeLens = { enabled = true },
      inlayHints = { parameterNames = { enabled = "all" } },
      signatureHelp = { enabled = true },
      contentProvider = { preferred = "fernflower" },
      format = {
        enabled = true,
        comments = { enabled = true },
        settings = {
          url = formatter,
          profile = "gcIntellijCodeStyle",
        },
      },
      saveActions = {
        organizeImports = false,
      },
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
        importOrder = { "#", "java", "javax", "org", "com", "" },
        filteredTypes = {
          "com.sun.*",
          "io.micrometer.shaded.*",
          "java.awt.*",
          "jdk.*",
          "sun.*",
        },
      },
      sources = {
        organizeImports = {
          starThreshold = 99,
          staticStarThreshold = 99,
        },
      },
      codeGeneration = {
        toString = {
          template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
        },
        useBlocks = true,
        hashCodeEquals = { useJava7Objects = true },
      },
    },
  }
end

local function patch_jdtls_runtime()
  local ok_utils, lsp_utils = pcall(require, "java-core.utils.lsp")
  if ok_utils and not lsp_utils._colejj_workspace then
    lsp_utils.get_jdtls_cache_data_path = function()
      local root = project.reactor_root()
      local workspace = project.jdtls_workspace(root)
      vim.fn.mkdir(workspace, "p")
      return workspace
    end
    lsp_utils._colejj_workspace = true
  end

  local ok_cmd, cmd_mod = pcall(require, "java-core.ls.servers.jdtls.cmd")
  if ok_cmd and not cmd_mod._colejj_vmargs then
    local orig = cmd_mod.get_jvm_args
    cmd_mod.get_jvm_args = function(config)
      local args = orig(config)
      for _, arg in ipairs({
        "-XX:+UseParallelGC",
        "-XX:GCTimeRatio=4",
        "-XX:AdaptiveSizePolicyWeight=90",
        "-Dsun.zip.disableMemoryMapping=true",
        "-Xmx4G",
      }) do
        args:push(arg)
      end
      return args
    end
    cmd_mod._colejj_vmargs = true
  end
end

local function jdt_root(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  local start = name ~= "" and vim.fn.fnamemodify(name, ":p:h") or nil
  return project.reactor_root(start)
end

function M.configure()
  jdk.validate()
  patch_jdtls_runtime()

  local existing = vim.lsp.config.jdtls or {}
  vim.lsp.config("jdtls", {
    root_dir = function(bufnr, on_dir)
      local root = jdt_root(bufnr)
      if type(on_dir) == "function" then
        on_dir(root)
      end
      return root
    end,
    settings = vim.tbl_deep_extend("force", existing.settings or {}, M.settings()),
  })
end

local function is_classfile(name)
  return type(name) == "string" and (name:find("^jdt://") ~= nil or name:find("%.class$") ~= nil)
end

local function is_project_source(item)
  local name = item.filename or ""
  local loc = item.user_data
  local uri = (loc and (loc.uri or loc.targetUri)) or name
  local haystack = name .. "\n" .. tostring(uri)
  if is_classfile(name) or is_classfile(uri) then
    return false
  end
  if haystack:find("jdt://", 1, true) or haystack:find("%%3C") or haystack:find("%3C", 1, true) then
    return false
  end
  if name:find("^<") or name:find("/%<") or vim.fn.fnamemodify(name, ":t"):find("^%%3C") then
    return false
  end
  if name:find("/target/classes/") or name:find("/target/test%-classes/") or name:find("%.jar") then
    return false
  end
  if name:match("%.java$") or name:match("%.kt$") then
    return true
  end
  return name ~= "" and vim.fn.filereadable(name) == 1
end

function M.source_items(items)
  local out = {}
  for _, item in ipairs(items or {}) do
    if is_project_source(item) then
      out[#out + 1] = item
    end
  end
  return out
end

local function fill_classfile(bufnr, uri)
  local client = M.client()
  if not client or not uri then
    return
  end
  local done, text
  client:request("workspace/executeCommand", {
    command = "java.decompile",
    arguments = { uri },
  }, function(err, result)
    if not err and type(result) == "string" then
      text = result
    end
    done = true
  end)
  vim.wait(8000, function()
    return done == true
  end, 20)
  if not text then
    return
  end
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, vim.split(text, "\n", { plain = true }))
  vim.bo[bufnr].filetype = "java"
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].swapfile = false
  if not vim.lsp.buf_is_attached(bufnr, client.id) then
    vim.lsp.buf_attach_client(bufnr, client.id)
  end
end

function M.ensure_decompiled(bufnr, uri)
  bufnr = bufnr or 0
  uri = uri or vim.api.nvim_buf_get_name(bufnr)
  if not is_classfile(uri) then
    return
  end
  local count = vim.api.nvim_buf_line_count(bufnr)
  local first = vim.api.nvim_buf_get_lines(bufnr, 0, 1, true)[1] or ""
  if count > 1 or first ~= "" then
    return
  end
  fill_classfile(bufnr, uri)
end

local function clamp_cursor(bufnr, lnum, col)
  local line_count = math.max(1, vim.api.nvim_buf_line_count(bufnr))
  local line = math.max(1, math.min(tonumber(lnum) or 1, line_count))
  local text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, true)[1] or ""
  local column = math.max(0, math.min((tonumber(col) or 1) - 1, #text))
  return { line, column }
end

function M.open_item(item)
  if not item then
    return
  end
  local loc = item.user_data
  local uri = (loc and (loc.uri or loc.targetUri)) or item.filename
  local bufnr = item.bufnr
  if not bufnr or bufnr == 0 then
    bufnr = vim.uri_to_bufnr(uri)
  end
  M.ensure_decompiled(bufnr, uri)
  pcall(vim.fn.bufload, bufnr)
  M.ensure_decompiled(bufnr, uri)

  vim.cmd("normal! m'")
  vim.bo[bufnr].buflisted = true
  vim.api.nvim_win_set_buf(0, bufnr)
  pcall(vim.api.nvim_win_set_cursor, 0, clamp_cursor(bufnr, item.lnum, item.col))
  vim.cmd("normal! zv")
end

function M.open_location(loc, encoding)
  if not loc or not (loc.uri or loc.targetUri) then
    return
  end
  local items = vim.lsp.util.locations_to_items({ loc }, encoding or "utf-16")
  if items[1] then
    M.open_item(items[1])
    return
  end
  local uri = loc.uri or loc.targetUri
  local range = loc.range or loc.targetSelectionRange or { start = { line = 0, character = 0 } }
  M.open_item({
    filename = uri,
    lnum = (range.start.line or 0) + 1,
    col = (range.start.character or 0) + 1,
    user_data = loc,
  })
end

local function item_is_here(item)
  local here = vim.api.nvim_buf_get_name(0)
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local fname = item.filename or ""
  if fname ~= here then
    local a = vim.fn.fnamemodify(fname, ":p")
    local b = vim.fn.fnamemodify(here, ":p")
    if a ~= b then
      return false
    end
  end
  return item.lnum == lnum
end

local function loc_is_here(loc)
  local uri = loc.uri or loc.targetUri
  local range = loc.range or loc.targetSelectionRange
  if not uri or not range then
    return false
  end
  local here = vim.uri_from_bufnr(0)
  local same = uri == here
  if not same then
    local ok_a, a = pcall(vim.uri_to_fname, uri)
    local ok_b, b = pcall(vim.uri_to_fname, here)
    same = ok_a and ok_b and vim.fn.fnamemodify(a, ":p") == vim.fn.fnamemodify(b, ":p")
  end
  if not same then
    return false
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  local start_line = range.start.line
  local end_line = (range["end"] or range.start).line
  return lnum >= start_line and lnum <= end_line
end

function M.pick_items(items, title)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")

  local displayer = entry_display.create({
    separator = "  ",
    items = {
      { width = 36 },
      { remaining = true },
    },
  })

  pickers
    .new({}, {
      prompt_title = title or "LSP",
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          local name = vim.fn.fnamemodify(item.filename or "", ":t")
          local label = name .. ":" .. (item.lnum or 1)
          return {
            value = item,
            filename = item.filename,
            lnum = item.lnum,
            col = item.col,
            ordinal = name .. " " .. (item.text or ""),
            display = function()
              return displayer({
                { label, "Directory" },
                { vim.trim(item.text or ""), "Comment" },
              })
            end,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.grep_previewer({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry and entry.value then
            M.open_item(entry.value)
          end
        end)
        return true
      end,
    })
    :find()
end

function M.handle_items(items, title)
  if not items or #items == 0 then
    vim.notify("Keine " .. (title or "Fundstellen"), vim.log.levels.INFO, { title = "colejj.java" })
    return
  end
  if #items == 1 then
    M.open_item(items[1])
    return
  end
  M.pick_items(items, title)
end

function M.references_smart()
  vim.lsp.buf.references({ includeDeclaration = false }, {
    on_list = function(options)
      local items = {}
      for _, item in ipairs(M.source_items(options.items or {})) do
        if not item_is_here(item) then
          items[#items + 1] = item
        end
      end
      M.handle_items(items, "Referenzen")
    end,
  })
end

function M.definition_smart()
  local bufnr = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/definition" })
  if not next(clients) then
    vim.notify("Kein LSP für Definitionen", vim.log.levels.WARN, { title = "colejj.java" })
    return
  end

  vim.lsp.buf_request_all(bufnr, "textDocument/definition", function(client)
    return vim.lsp.util.make_position_params(win, client.offset_encoding)
  end, function(results)
    local locations = {}
    local encoding = "utf-16"
    for client_id, res in pairs(results) do
      local client = vim.lsp.get_client_by_id(client_id)
      if client then
        encoding = client.offset_encoding or encoding
      end
      local result = res and res.result
      if type(result) == "table" then
        if result.uri or result.targetUri then
          locations[#locations + 1] = result
        else
          vim.list_extend(locations, result)
        end
      end
    end

    if #locations == 0 or (#locations == 1 and loc_is_here(locations[1])) then
      M.references_smart()
      return
    end

    local items = vim.lsp.util.locations_to_items(locations, encoding)
    M.handle_items(items, "Definitionen")
  end)
end

function M.jump(kind)
  if kind == "definition" then
    M.definition_smart()
    return
  end
  if kind == "references" then
    M.references_smart()
    return
  end
  local fn = vim.lsp.buf[kind]
  if type(fn) ~= "function" then
    return
  end
  fn({
    on_list = function(options)
      M.handle_items(options.items or {}, kind)
    end,
  })
end

function M.setup_navigation()
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = vim.api.nvim_create_augroup("colejj-java-classfile", { clear = true }),
    pattern = { "*.class" },
    callback = function(opts)
      fill_classfile(opts.buf, opts.file)
    end,
  })
end

function M.client()
  for _, client in ipairs(vim.lsp.get_clients({ name = "jdtls" })) do
    return client
  end
end

function M.execute(command, arguments)
  local client = M.client()
  if not client then
    vim.notify("JDT.LS ist nicht aktiv. Eine Java-Datei öffnen.", vim.log.levels.WARN, { title = "colejj.java" })
    return
  end
  client:request("workspace/executeCommand", {
    command = command,
    arguments = arguments or {},
  }, function(err, result)
    if err then
      vim.notify(err.message or vim.inspect(err), vim.log.levels.ERROR, { title = "colejj.java" })
    end
    return result
  end)
end

function M.update_project()
  local buf = vim.uri_from_bufnr(0)
  M.execute("java.projectConfiguration.update", { buf })
  require("colejj.java.classpath").schedule_repair(12)
  vim.notify("Maven-/Gradle-Projekt wird neu importiert", vim.log.levels.INFO, { title = "colejj.java" })
end

function M.organize_imports()
  vim.lsp.buf.code_action({
    context = { only = { "source.organizeImports" }, diagnostics = {} },
    apply = true,
  })
end

function M.generate(kind)
  local mapping = {
    getters = "source.generate.accessors",
    tostring = "source.generate.toString",
    equals = "source.generate.hashCodeEquals",
    override = "source.overrideMethods",
  }
  local only = mapping[kind]
  if not only then
    return
  end
  vim.lsp.buf.code_action({
    context = { only = { only }, diagnostics = {} },
    apply = false,
  })
end

function M.health()
  local client = M.client()
  if not client then
    vim.notify("Kein JDT.LS-Client", vim.log.levels.WARN, { title = "colejj.java" })
    return
  end
  local lines = {
    "JDT.LS aktiv",
    "Root: " .. (client.config.root_dir or "?"),
    "Workspace: " .. project.jdtls_workspace(client.config.root_dir),
    "JDK: " .. (jdk.jdtls_home() or "nicht gefunden"),
  }
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "colejj.java" })
end

function M.reset_workspace()
  local client = M.client()
  local root = (client and client.config.root_dir) or project.project_root()
  local workspace = project.jdtls_workspace(root)
  if client then
    client:stop(true)
  end
  if vim.fn.isdirectory(workspace) == 1 then
    local backup = workspace .. "-backup-" .. os.date("%Y%m%d-%H%M%S")
    vim.fn.rename(workspace, backup)
    vim.notify("Workspace gesichert nach " .. backup, vim.log.levels.INFO, { title = "colejj.java" })
  end
  vim.defer_fn(function()
    vim.cmd.edit()
  end, 500)
end

return M
