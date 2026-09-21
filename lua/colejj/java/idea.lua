local project = require("colejj.project")

local M = {}

local function attr(tag, name)
  return tag:match(name .. '%s*=%s*"([^"]*)"')
end

local function parse_application(xml)
  local conf = xml:match("<configuration%s+(.-)</configuration>")
  if not conf then
    return nil
  end
  local header = xml:match("<configuration%s+([^>]-)/?>") or ""
  if not header:find('type%s*=%s*"Application"') then
    return nil
  end
  local name = attr(header, "name")
  local opts = {}
  for block in xml:gmatch("<option%s+([^/]-)/>") do
    local key = attr(block, "name")
    local value = attr(block, "value")
    if key then
      opts[key] = value
    end
  end
  local module = xml:match('<module%s+name%s*=%s*"([^"]+)"')
  local envs = {}
  for env in xml:gmatch("<env%s+([^/]-)/>") do
    local env_name = attr(env, "name")
    local env_value = attr(env, "value")
    if env_name then
      envs[env_name] = env_value or ""
    end
  end
  return {
    name = name,
    main = opts.MAIN_CLASS_NAME,
    module = module,
    vmargs = opts.VM_PARAMETERS,
    args = opts.PROGRAM_PARAMETERS,
    wd = opts.WORKING_DIRECTORY,
    include_provided = opts.INCLUDE_PROVIDED_SCOPE ~= "false",
    envs = envs,
  }
end

function M.list()
  local root = project.idea_root()
  local dir = root .. "/.idea/runConfigurations"
  if vim.fn.isdirectory(dir) == 0 then
    return {}
  end
  local configs = {}
  for name, typ in vim.fs.dir(dir) do
    if typ == "file" and name:match("%.xml$") then
      local path = dir .. "/" .. name
      local xml = table.concat(vim.fn.readfile(path), "\n")
      local parsed = parse_application(xml)
      if parsed and parsed.name then
        table.insert(configs, parsed)
      end
    end
  end
  table.sort(configs, function(a, b)
    return a.name < b.name
  end)
  return configs
end

function M.module_dir(cfg)
  local root = vim.fn.fnamemodify(project.reactor_root(), ":p"):gsub("/$", "")
  local module = cfg and cfg.module
  if type(module) == "string" and module ~= "" and module ~= "." then
    local dir = root .. "/" .. module
    if vim.uv.fs_stat(dir .. "/pom.xml") then
      return vim.fn.fnamemodify(dir, ":p"):gsub("/$", "")
    end
  end
end

function M.expand_wd(cfg)
  local root = vim.fn.fnamemodify(project.idea_root(), ":p"):gsub("/$", "")
  local wd = cfg and cfg.wd
  if type(wd) == "string" and wd ~= "" then
    wd = wd:gsub("^file://", "")
    wd = wd:gsub("%$PROJECT_DIR%$", root)
    wd = vim.fn.fnamemodify(vim.fn.expand(wd), ":p"):gsub("/$", "")
    if vim.fn.isdirectory(wd) == 1 then
      return wd
    end
  end
  return M.module_dir(cfg) or root
end

function M.pick(callback)
  local configs = M.list()
  if #configs == 0 then
    vim.notify(
      "Keine Application-Run-Configs in .idea/runConfigurations gefunden",
      vim.log.levels.WARN,
      { title = "colejj.java" }
    )
    return
  end
  vim.ui.select(configs, {
    prompt = "Run-Config",
    format_item = function(item)
      return item.name .. (item.main and ("  (" .. item.main .. ")") or "")
    end,
  }, function(cfg)
    if cfg then
      callback(cfg)
    end
  end)
end

return M
