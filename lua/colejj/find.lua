-- Projektweite Methodensuche wie Doom `SPC f m` (`+find/project-method`):
-- einmalig per ripgrep alle Java-/Kotlin-Deklarationen, dann flache Telescope-Liste.

local M = {}

local JAVA_RE =
  "^[[:space:]]*(?:public|protected|private|static|final|abstract|synchronized|native|default)[[:space:]][^;{}()=]*[[:space:]][A-Za-z_][A-Za-z0-9_]*[[:space:]]*\\("

local KOTLIN_RE = "\\bfun[[:space:]]+(?:<[^>]+>[[:space:]]*)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\\("

local SKIP = {
  ["if"] = true,
  ["for"] = true,
  ["while"] = true,
  ["switch"] = true,
  ["catch"] = true,
  ["synchronized"] = true,
  ["return"] = true,
  ["new"] = true,
  ["else"] = true,
  ["do"] = true,
  ["try"] = true,
}

local function method_name(text)
  local fun = text:match("%f[%w]fun%s+<[^>]+>%s*([%a_][%w_]*)")
    or text:match("%f[%w]fun%s+([%a_][%w_]*)")
  if fun then
    return fun
  end
  return text:match("([%a_][%w_]*)%s*%(")
end

local function parse_rg(stdout, root)
  local entries = {}
  local seen = {}
  for line in vim.gsplit(stdout or "", "\n", { trimempty = true }) do
    local file, lnum, text = line:match("^(.+):(%d+):%d+:(.*)$")
    if file and text then
      local name = method_name(text)
      if name and not SKIP[name] then
        local rel = file
        if rel:sub(1, 2) == "./" then
          rel = rel:sub(3)
        end
        local abs = file:sub(1, 1) == "/" and file or vim.fs.joinpath(root, rel)
        if file:sub(1, 1) == "/" then
          rel = vim.fn.fnamemodify(file, ":t")
        end
        local key = name .. "\0" .. rel .. "\0" .. lnum
        if not seen[key] then
          seen[key] = true
          entries[#entries + 1] = {
            name = name,
            rel = rel,
            filename = abs,
            lnum = tonumber(lnum),
            text = vim.trim(text),
          }
        end
      end
    end
  end
  return entries
end

local function collect_project(root)
  if vim.fn.executable("rg") ~= 1 then
    vim.notify("ripgrep (rg) nicht gefunden", vim.log.levels.ERROR)
    return {}
  end
  local result = vim.system({
    "rg",
    "--vimgrep",
    "--no-heading",
    "--color=never",
    "-g",
    "!target/",
    "-g",
    "!bin/",
    "-g",
    "!**/node_modules/",
    "-t",
    "java",
    "-t",
    "kotlin",
    "-e",
    JAVA_RE,
    "-e",
    KOTLIN_RE,
    ".",
  }, { cwd = root, text = true }):wait()
  return parse_rg(result.stdout, root)
end

local function looks_like_method(text, filename)
  if text:find("%(") == nil or SKIP[method_name(text) or ""] then
    return false
  end
  if filename:sub(-3) == ".kt" or text:find("%f[%w]fun%f[%W]") then
    return text:find("%f[%w]fun%f[%W]") ~= nil
  end
  return text:find("%f[%w]fun%f[%W]") ~= nil
    or text:find("%f[%w]void%f[%W]") ~= nil
    or text:find("%f[%w]public%f[%W]") ~= nil
    or text:find("%f[%w]private%f[%W]") ~= nil
    or text:find("%f[%w]protected%f[%W]") ~= nil
    or text:find("%f[%w]static%f[%W]") ~= nil
    or text:find("%f[%w]default%f[%W]") ~= nil
    or text:find("%f[%w]abstract%f[%W]") ~= nil
    or text:find("%f[%w]native%f[%W]") ~= nil
end

local function collect_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == "" then
    vim.notify("Kein Dateiname für diesen Buffer", vim.log.levels.WARN)
    return {}
  end
  local rel = vim.fn.fnamemodify(filename, ":t")
  local entries = {}
  local seen = {}
  for lnum, text in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local name = method_name(text)
    if name and looks_like_method(text, filename) then
      local key = name .. "\0" .. lnum
      if not seen[key] then
        seen[key] = true
        entries[#entries + 1] = {
          name = name,
          rel = rel,
          filename = filename,
          lnum = lnum,
          text = vim.trim(text),
        }
      end
    end
  end
  return entries
end

local function pick_methods(entries, title)
  if #entries == 0 then
    vim.notify("Keine Methoden gefunden", vim.log.levels.WARN)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local entry_display = require("telescope.pickers.entry_display")

  local displayer = entry_display.create({
    separator = "  ",
    items = {
      { width = 0.55 },
      { remaining = true },
    },
  })

  pickers
    .new({}, {
      prompt_title = title or "Methode",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(item)
          return {
            value = item,
            ordinal = item.name .. " " .. item.rel .. " " .. (item.text or ""),
            filename = item.filename,
            lnum = item.lnum,
            col = 1,
            display = function(entry)
              return displayer({
                { " " .. entry.value.name, "Function" },
                { entry.value.rel .. ":" .. entry.value.lnum, "Comment" },
              })
            end,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.grep_previewer({}),
    })
    :find()
end

function M.project_method()
  local root = require("colejj.project").project_root()
  pick_methods(collect_project(root), "Methode im Projekt")
end

function M.buffer_method()
  pick_methods(collect_buffer(), "Methode in Datei")
end

local function live_grep(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or require("colejj.project").project_root()
  opts.default_text = opts.default_text or require("colejj.utils").visual_search_text()
  -- IntelliJ-artig: `(`, `.`, `*` sind Text, keine Regex. `opts.regex = true` hebt das auf.
  if opts.regex then
    opts.regex = nil
  else
    local extra = opts.additional_args
    opts.additional_args = function(...)
      local args = { "-F" }
      if type(extra) == "function" then
        vim.list_extend(args, extra(...) or {})
      elseif type(extra) == "table" then
        vim.list_extend(args, extra)
      end
      return args
    end
  end
  require("telescope.builtin").live_grep(opts)
end

function M.search_project()
  live_grep({ prompt_title = "Suche im Projekt" })
end

function M.search_project_regex()
  live_grep({
    prompt_title = "Suche Regex",
    regex = true,
  })
end

function M.search_project_literal()
  live_grep({ prompt_title = "Suche literal" })
end

function M.search_project_latin1()
  live_grep({
    prompt_title = "Suche Latin-1",
    additional_args = function()
      return { "-F", "--encoding=iso-8859-1" }
    end,
  })
end

function M.search_cwd()
  live_grep({
    cwd = vim.fn.expand("%:p:h"),
    prompt_title = "Suche in Verzeichnis",
  })
end

function M.search_other_cwd()
  vim.ui.input({
    prompt = "Verzeichnis: ",
    default = vim.fn.expand("%:p:h"),
    completion = "dir",
  }, function(dir)
    if not dir or dir == "" then
      return
    end
    live_grep({
      cwd = vim.fn.fnamemodify(dir, ":p"),
      prompt_title = "Suche in " .. dir,
    })
  end)
end

function M.search_config()
  live_grep({
    cwd = vim.fn.stdpath("config"),
    prompt_title = "Suche in Neovim-Config",
  })
end

function M.search_buffers()
  live_grep({
    grep_open_files = true,
    prompt_title = "Suche in offenen Buffern",
  })
end

--- Buffer-Suche in Dateireihenfolge (nicht nach Fuzzy-Score).
function M.search_buffer(opts)
  opts = opts or {}
  local default = opts.default_text
  if default == nil then
    default = require("colejj.utils").visual_search_text()
  end
  if default == "" then
    default = nil
  end
  local sorters = require("telescope.sorters")
  require("telescope.builtin").current_buffer_fuzzy_find({
    prompt_title = "Suche im Buffer",
    default_text = default,
    sorter = sorters.Sorter:new({
      scoring_function = function(_, prompt, line, entry)
        if prompt and prompt ~= "" then
          if not (line or ""):lower():find(prompt:lower(), 1, true) then
            return -1
          end
        end
        return (entry and entry.lnum) or 1
      end,
      highlighter = function(_, prompt, display)
        if not prompt or prompt == "" then
          return {}
        end
        local start = (display or ""):lower():find(prompt:lower(), 1, true)
        if not start then
          return {}
        end
        return { { start = start, finish = start + #prompt - 1 } }
      end,
    }),
  })
end

function M.open_dired(path)
  require("oil").open(path)
end

--- Wie Doom `SPC f d` / projectile-find-dir: Verzeichnis im Projekt wählen, dann Oil.
function M.unsaved_in_project()
  local root = vim.fn.fnamemodify(require("colejj.project").project_root(), ":p")
  local items = {}
  for _, info in ipairs(vim.fn.getbufinfo({ bufmodified = 1, buflisted = 1 })) do
    local path = info.name
    if path ~= "" then
      path = vim.fn.fnamemodify(path, ":p")
      if vim.startswith(path, root) then
        items[#items + 1] = {
          bufnr = info.bufnr,
          path = path,
          rel = path:sub(#root + 1),
          lastused = info.lastused or 0,
        }
      end
    end
  end
  table.sort(items, function(a, b)
    return a.lastused > b.lastused
  end)
  if #items == 0 then
    vim.notify("Keine ungespeicherten Dateien im Projekt", vim.log.levels.INFO, { title = "Suche" })
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")
  pickers
    .new({}, {
      prompt_title = "Ungespeichert",
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          return {
            value = item,
            display = item.rel,
            ordinal = item.rel,
            filename = item.path,
            bufnr = item.bufnr,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = previewers.new_buffer_previewer({
        define_preview = function(self, entry)
          if entry.bufnr and vim.api.nvim_buf_is_valid(entry.bufnr) then
            vim.api.nvim_win_set_buf(self.state.winid, entry.bufnr)
          end
        end,
      }),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry and entry.bufnr and vim.api.nvim_buf_is_valid(entry.bufnr) then
            vim.api.nvim_set_current_buf(entry.bufnr)
          end
        end)
        return true
      end,
    })
    :find()
end

function M.find_directory()
  local cwd = require("colejj.project").project_root()
  local find_command
  if vim.fn.executable("fd") == 1 then
    find_command = {
      "fd",
      "--type",
      "d",
      "--hidden",
      "--exclude",
      ".git",
      "--exclude",
      "target",
      "--exclude",
      "node_modules",
      "--exclude",
      "dist",
    }
  else
    find_command = { "find", ".", "-type", "d", "-not", "-path", "*/.git/*", "-not", "-path", "*/target/*" }
  end
  require("telescope.builtin").find_files({
    prompt_title = "Verzeichnis",
    cwd = cwd,
    find_command = find_command,
    attach_mappings = function(prompt_bufnr)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if not entry then
          return
        end
        local dir = entry.path or entry.value
        if not dir:match("^/") then
          dir = cwd .. "/" .. dir
        end
        require("oil").open(dir)
      end)
      return true
    end,
  })
end

local function file_key(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  local abs = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  return vim.uv.fs_realpath(abs) or abs
end

local function last_positions()
  local by_path = {}
  local function remember(path, lnum, col)
    local key = file_key(path)
    if not key or type(lnum) ~= "number" or lnum < 1 then
      return
    end
    by_path[key] = {
      lnum = lnum,
      col = (col and col > 0) and col or 1,
    }
  end

  for _, mark in ipairs(vim.fn.getmarklist()) do
    local pos = mark.pos
    if pos then
      remember(mark.file, pos[2], pos[3])
    end
  end

  local jumplist = vim.fn.getjumplist()[1] or {}
  for _, jump in ipairs(jumplist) do
    local path = jump.filename
    if (not path or path == "") and jump.bufnr and jump.bufnr > 0 and vim.api.nvim_buf_is_valid(jump.bufnr) then
      path = vim.api.nvim_buf_get_name(jump.bufnr)
    end
    remember(path, jump.lnum, (jump.col or 0) + 1)
  end

  for _, info in ipairs(vim.fn.getbufinfo()) do
    if info.name and info.name ~= "" then
      local lnum = info.lnum or 0
      local col = 1
      if info.loaded == 1 and vim.api.nvim_buf_is_valid(info.bufnr) then
        local mark = vim.api.nvim_buf_get_mark(info.bufnr, '"')
        if mark[1] > 0 then
          lnum = mark[1]
          col = mark[2] + 1
        end
      end
      remember(info.name, lnum, col)
    end
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    local pos = vim.api.nvim_win_get_cursor(win)
    remember(name, pos[1], pos[2] + 1)
  end

  return by_path
end

function M.oldfiles()
  local positions = last_positions()
  local make_entry = require("telescope.make_entry")
  local conf = require("telescope.config").values
  local opts = { path_display = { "tail" } }
  local maker = make_entry.gen_from_file(opts)

  opts.entry_maker = function(path)
    local entry = maker(path)
    if not entry then
      return entry
    end
    local pos = positions[file_key(path)]
    if pos then
      entry.lnum = pos.lnum
      entry.col = pos.col
    end
    return entry
  end

  local previewer = conf.grep_previewer(opts)
  local title = previewer.title
  previewer._title_fn = function()
    return "Letzte Position"
  end
  previewer._dyn_title_fn = function(_, entry)
    local name = vim.fn.fnamemodify(entry.path or entry.filename or entry.value or "", ":t")
    if entry.lnum and entry.lnum > 0 then
      return string.format("%s:%d", name, entry.lnum)
    end
    return name
  end
  previewer.title = function(self, entry)
    return title(self, entry, true)
  end
  opts.previewer = previewer

  require("telescope.builtin").oldfiles(opts)
end

return M
