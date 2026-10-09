local project = require("colejj.project")
local jdk = require("colejj.java.jdk")

local M = {}

local entities = {
  quot = '"',
  amp = "&",
  lt = "<",
  gt = ">",
  apos = "'",
}

local function decode(value)
  if not value then
    return nil
  end
  value = value:gsub("&#x(%x+);", function(hex)
    return vim.fn.nr2char(tonumber(hex, 16))
  end)
  value = value:gsub("&#(%d+);", function(dec)
    return vim.fn.nr2char(tonumber(dec))
  end)
  return (value:gsub("&(%a+);", function(name)
    return entities[name] or ("&" .. name .. ";")
  end))
end

-- Attributwerte dürfen "/" enthalten (URLs, $PROJECT_DIR$/…) und über Zeilen gehen.
local function attr(tag, name)
  return decode(tag:match("%f[%w_]" .. name .. '%s*=%s*"([^"]*)"'))
end

local function self_closing(xml, tag)
  local out = {}
  for body in xml:gmatch("<" .. tag .. "%s+([^>]-)/>") do
    table.insert(out, body)
  end
  return out
end

local function project_dir()
  return vim.fn.fnamemodify(project.idea_root(), ":p"):gsub("/$", "")
end

local function pom_artifact_id(pom)
  local ok, lines = pcall(vim.fn.readfile, pom)
  if not ok then
    return nil
  end
  local text = table.concat(lines, "\n"):gsub("<parent>.-</parent>", ""):gsub("<!%-%-.-%-%->", "")
  return text:match("<artifactId>%s*([^<%s]+)%s*</artifactId>")
end

--- Verzeichnis eines IntelliJ-Moduls (Name = artifactId oder Ordnername).
function M.find_module_dir(module)
  if type(module) ~= "string" or module == "" or module == "." then
    return nil
  end
  local root = vim.fn.fnamemodify(project.reactor_root(), ":p"):gsub("/$", "")
  local direct = root .. "/" .. module
  if vim.uv.fs_stat(direct .. "/pom.xml") then
    return direct
  end
  for _, pom in ipairs(vim.fn.globpath(root, "*/pom.xml", false, true)) do
    if pom_artifact_id(pom) == module then
      return vim.fn.fnamemodify(pom, ":h")
    end
  end
  for _, pom in ipairs(vim.fn.globpath(root, "*/*/pom.xml", false, true)) do
    if pom_artifact_id(pom) == module then
      return vim.fn.fnamemodify(pom, ":h")
    end
  end
  if pom_artifact_id(root .. "/pom.xml") == module then
    return root
  end
end

local function expand_macros(value, module_dir)
  if type(value) ~= "string" then
    return value
  end
  local root = project_dir()
  local home = vim.uv.os_homedir()
  local mod = module_dir or root
  return (
    value
      :gsub("%$PROJECT_DIR%$", function()
        return root
      end)
      :gsub("%$MODULE_WORKING_DIR%$", function()
        return mod
      end)
      :gsub("%$MODULE_DIR%$", function()
        return mod
      end)
      :gsub("%$USER_HOME%$", function()
        return home
      end)
  )
end

local function parse_application(xml)
  xml = xml:gsub("<!%-%-.-%-%->", "")
  local header = xml:match("<configuration%s+([^>]-)/?>")
  if not header or attr(header, "type") ~= "Application" then
    return nil
  end

  local opts = {}
  for _, body in ipairs(self_closing(xml, "option")) do
    local key = attr(body, "name")
    if key and opts[key] == nil then
      opts[key] = attr(body, "value") or attr(body, "enabled")
    end
  end

  local module
  for _, body in ipairs(self_closing(xml, "module")) do
    module = attr(body, "name") or module
  end
  local module_dir = M.find_module_dir(module)

  local envs = {}
  local env_block = xml:match("<envs>(.-)</envs>") or ""
  for _, body in ipairs(self_closing(env_block, "env")) do
    local name = attr(body, "name")
    if name then
      envs[name] = expand_macros(attr(body, "value") or "", module_dir)
    end
  end

  local before = {}
  local method = xml:match("<method[^>]*>(.-)</method>") or ""
  local make = true
  for _, body in ipairs(self_closing(method, "option")) do
    local name = attr(body, "name")
    local enabled = attr(body, "enabled") ~= "false"
    if name == "Make" then
      make = enabled
    elseif enabled then
      table.insert(before, attr(body, "run_configuration_name") or name)
    end
  end

  local jre
  if opts.ALTERNATIVE_JRE_PATH_ENABLED == "true" and opts.ALTERNATIVE_JRE_PATH then
    jre = opts.ALTERNATIVE_JRE_PATH
  end

  return {
    name = attr(header, "name"),
    main = opts.MAIN_CLASS_NAME,
    module = module,
    module_dir = module_dir,
    vmargs = expand_macros(opts.VM_PARAMETERS, module_dir),
    args = expand_macros(opts.PROGRAM_PARAMETERS, module_dir),
    wd = opts.WORKING_DIRECTORY,
    include_provided = opts.INCLUDE_PROVIDED_SCOPE == "true",
    pass_parent_envs = opts.PASS_PARENT_ENVS ~= "false",
    jre = jre,
    make = make,
    before_launch = before,
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
  if cfg and cfg.module_dir then
    return cfg.module_dir
  end
  return M.find_module_dir(cfg and cfg.module)
end

function M.expand_wd(cfg)
  local root = project_dir()
  local module_dir = M.module_dir(cfg)
  local wd = cfg and cfg.wd
  if type(wd) == "string" and wd ~= "" then
    wd = expand_macros(wd:gsub("^file://", ""), module_dir)
    wd = vim.fn.fnamemodify(vim.fn.expand(wd), ":p"):gsub("/$", "")
    if vim.fn.isdirectory(wd) == 1 then
      return wd
    end
  end
  return module_dir or root
end

local function java_in(home)
  if type(home) ~= "string" or home == "" then
    return nil
  end
  home = vim.fn.expand(home)
  for _, candidate in ipairs({ home .. "/bin/java", home .. "/Contents/Home/bin/java" }) do
    if vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end
end

local function jdk_by_name(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local home = vim.uv.os_homedir()
  for _, dir in ipairs({
    home .. "/Library/Java/JavaVirtualMachines/" .. name,
    home .. "/Library/Java/JavaVirtualMachines/" .. name .. ".jdk",
    "/Library/Java/JavaVirtualMachines/" .. name,
    "/Library/Java/JavaVirtualMachines/" .. name .. ".jdk",
  }) do
    local java = java_in(dir)
    if java then
      return java
    end
  end
  local version = name:match("(%d+)")
  if version then
    return java_in(jdk.find(version))
  end
end

--- Projekt-SDK aus .idea/misc.xml (project-jdk-name).
function M.project_jdk_name()
  local misc = project.idea_root() .. "/.idea/misc.xml"
  if not vim.uv.fs_stat(misc) then
    return nil
  end
  local text = table.concat(vim.fn.readfile(misc), "\n")
  return decode(text:match('project%-jdk%-name%s*=%s*"([^"]+)"'))
end

--- In IntelliJ aktivierte Maven-Profile (.idea/misc.xml → enabledProfiles).
function M.maven_profiles()
  local misc = project.idea_root() .. "/.idea/misc.xml"
  if not vim.uv.fs_stat(misc) then
    return {}
  end
  local text = table.concat(vim.fn.readfile(misc), "\n")
  local block = text:match('<option%s+name="enabledProfiles"%s*>(.-)</option>') or ""
  local profiles = {}
  for _, body in ipairs(self_closing(block, "option")) do
    local value = attr(body, "value")
    if value and value ~= "" then
      profiles[#profiles + 1] = value
    end
  end
  return profiles
end

--- java-Executable wie in IntelliJ: alternative JRE der Run-Config, sonst Projekt-SDK.
function M.java_executable(cfg)
  local java = (cfg and cfg.jre and (java_in(cfg.jre) or jdk_by_name(cfg.jre))) or jdk_by_name(M.project_jdk_name())
  if java then
    return java
  end
  local java_home = os.getenv("JAVA_HOME")
  return java_in(java_home) or "java"
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
