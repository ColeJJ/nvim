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
      { width = 36 },
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
  require("telescope.builtin").live_grep(opts)
end

function M.search_project()
  live_grep({ prompt_title = "Suche im Projekt" })
end

function M.search_project_literal()
  live_grep({
    prompt_title = "Suche literal",
    additional_args = function()
      return { "-F" }
    end,
  })
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

return M
