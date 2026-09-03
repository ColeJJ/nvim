local project = require("colejj.project")
local lsp = require("colejj.java.lsp")

local M = {}

local templates = {
  class = "public class %s {\n}\n",
  interface = "public interface %s {\n}\n",
  enum = "public enum %s {\n}\n",
  record = "public record %s() {\n}\n",
  annotation = "public @interface %s {\n}\n",
}

local function package_from_path(path)
  local rel = path:match("src/main/java/(.+)") or path:match("src/test/java/(.+)")
  if not rel then
    return nil
  end
  return rel:gsub("/", "."):gsub("%.[^%.]+$", "")
end

function M.new_type()
  vim.ui.select({ "class", "interface", "enum", "record", "annotation" }, { prompt = "Neuer Typ" }, function(kind)
    if not kind then
      return
    end
    vim.ui.input({ prompt = "Name (optional paket.Name): " }, function(name)
      if not name or name == "" then
        return
      end
      local dir = vim.fn.expand("%:p:h")
      local simple = name
      if name:find("%.") then
        local pkg = name:match("(.+)%.[^%.]+$")
        simple = name:match("([^%.]+)$")
        dir = dir .. "/" .. pkg:gsub("%.", "/")
      end
      vim.fn.mkdir(dir, "p")
      local file = dir .. "/" .. simple .. ".java"
      if vim.uv.fs_stat(file) then
        vim.notify("Datei existiert bereits: " .. file, vim.log.levels.WARN)
        return
      end
      local pkg = package_from_path(file)
      local body = ""
      if pkg then
        body = "package " .. pkg .. ";\n\n"
      end
      body = body .. templates[kind]:format(simple)
      vim.fn.writefile(vim.split(body, "\n"), file)
      vim.cmd.edit(file)
    end)
  end)
end

function M.toggle_impl()
  local file = vim.fn.expand("%:p")
  local alt
  if file:match("Impl%.java$") then
    alt = file:gsub("Impl%.java$", ".java")
  else
    alt = file:gsub("%.java$", "Impl.java")
  end
  if vim.uv.fs_stat(alt) then
    vim.cmd.edit(alt)
  else
    vim.notify("Keine Gegenstück-Datei: " .. alt, vim.log.levels.WARN)
  end
end

function M.check_project(only_module)
  local root = project.reactor_root()
  local args = { project.maven_cmd(root) }
  vim.list_extend(args, require("colejj.java.compat").maven_flags(root))
  if only_module then
    local module = select(1, project.maven_module())
    if module then
      vim.list_extend(args, { "-pl", module, "-amd" })
    end
  end
  table.insert(args, "compile")
  require("colejj.java.output").run({
    cmd = args,
    cwd = root,
    title = "Build Project",
  })
end

function M.super_implementation()
  vim.lsp.buf.declaration()
end

function M.spring_beans()
  require("telescope.builtin").lsp_workspace_symbols({
    prompt_title = "Spring Beans / Symbole",
  })
end

local function symbol_kind_name(kind)
  local kinds = vim.lsp.protocol.SymbolKind
  for name, value in pairs(kinds) do
    if value == kind then
      return name
    end
  end
  return ""
end

function M.goto_class_anywhere()
  local client = lsp.client()
  if not client then
    vim.notify("JDT.LS ist nicht aktiv. Eine Java-Datei öffnen.", vim.log.levels.WARN, { title = "colejj.java" })
    return
  end

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
      { width = 12 },
      { remaining = true },
    },
  })

  pickers
    .new({}, {
      prompt_title = "Klasse (inkl. Dependencies)",
      finder = finders.new_dynamic({
        fn = function(prompt)
          prompt = vim.trim(prompt or "")
          if #prompt < 2 then
            return {}
          end
          local done, items
          client:request("java/searchSymbols", {
            query = prompt .. "*",
            sourceOnly = false,
            maxResults = 80,
          }, function(err, result)
            if err then
              items = {}
            else
              items = result or {}
            end
            done = true
          end)
          vim.wait(2000, function()
            return done == true
          end, 20)
          return items or {}
        end,
        entry_maker = function(sym)
          if type(sym) ~= "table" then
            return nil
          end
          local name = sym.name or ""
          local container = sym.containerName or ""
          local kind = symbol_kind_name(sym.kind)
          local loc = sym.location or {}
          return {
            value = sym,
            ordinal = name .. " " .. container,
            display = function()
              return displayer({
                { name, "Type" },
                { kind, "Comment" },
                { container, "Comment" },
              })
            end,
            filename = loc.uri,
            lnum = loc.range and (loc.range.start.line + 1) or 1,
            col = loc.range and (loc.range.start.character + 1) or 1,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          local loc = entry and entry.value and entry.value.location
          if not loc then
            return
          end
          require("colejj.java.lsp").open_location(loc, client.offset_encoding or "utf-16")
        end)
        return true
      end,
    })
    :find()
end

function M.health()
  lsp.health()
end

function M.reset_workspace()
  lsp.reset_workspace()
end

function M.update_project()
  lsp.update_project()
end

return M
