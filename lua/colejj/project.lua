local M = {}

--- jdt://, jar: und zipfile:// sind keine Dateisystempfade. Aus ihnen wird
--- sonst ein Workspace-Root wie file://jdt://… gebaut, an dem JDT.LS crash.
function M.is_virtual_path(path)
  if type(path) ~= "string" or path == "" then
    return true
  end
  if path:find("://", 1, true) or path:find("^jar:") or path:find("^zip:") then
    return true
  end
  if path:find("%.jar!") or path:find("%.jar::") or path:find("%.zip::") then
    return true
  end
  return false
end

local function parent_dir(path)
  local parent = vim.fn.fnamemodify(path, ":h")
  if parent == path then
    return nil
  end
  return parent
end

local function start_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= "" and not M.is_virtual_path(name) then
    return vim.fn.fnamemodify(name, ":p:h")
  end
  return vim.uv.cwd()
end

local function find_upwards(start, marker)
  local dir = start
  while dir do
    if vim.uv.fs_stat(dir .. "/" .. marker) then
      return dir
    end
    dir = parent_dir(dir)
  end
end

function M.git_root(start)
  if start and M.is_virtual_path(start) then
    start = nil
  end
  return find_upwards(start or start_dir(), ".git")
end

--- Oberstes pom.xml in der Verzeichniskette (Reactor-Root, nicht das nächste Modul).
function M.reactor_root(start)
  if start and M.is_virtual_path(start) then
    start = nil
  end
  local dir = start or start_dir()
  local root
  while dir do
    local hit = find_upwards(dir, "pom.xml")
    if not hit then
      break
    end
    root = hit
    dir = parent_dir(hit)
  end
  return root or M.git_root(start) or vim.uv.cwd()
end

function M.gradle_root(start)
  if start and M.is_virtual_path(start) then
    start = nil
  end
  local dir = start or start_dir()
  for _, marker in ipairs({ "settings.gradle", "settings.gradle.kts", "gradlew" }) do
    local hit = find_upwards(dir, marker)
    if hit then
      return hit
    end
  end
end

function M.project_root(start)
  return M.git_root(start) or M.reactor_root(start) or M.gradle_root(start) or vim.uv.cwd()
end

function M.idea_root(start)
  if start and M.is_virtual_path(start) then
    start = nil
  end
  return find_upwards(start or start_dir(), ".idea") or M.project_root(start)
end

--- Nächstes Maven-Modul relativ zum Reactor-Root.
function M.maven_module(start)
  local file = vim.api.nvim_buf_get_name(0)
  local from
  if file ~= "" and not M.is_virtual_path(file) then
    from = vim.fn.fnamemodify(file, ":p:h")
  else
    from = start or start_dir()
  end
  local module_dir = find_upwards(from, "pom.xml")
  if not module_dir then
    return nil, nil
  end
  local root = M.reactor_root(from)
  local relative = vim.fn.fnamemodify(module_dir, ":p"):gsub("/$", "")
  local root_abs = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  if relative == root_abs then
    return ".", module_dir
  end
  return relative:sub(#root_abs + 2), module_dir
end

function M.workspace_id(root)
  root = vim.fn.fnamemodify(root or M.project_root(), ":p"):gsub("/$", "")
  local hash = vim.fn.sha256(root):sub(1, 12)
  local name = vim.fn.fnamemodify(root, ":t")
  if name == "" then
    name = "workspace"
  end
  return name .. "-" .. hash
end

function M.jdtls_workspace(root)
  return vim.fn.stdpath("data") .. "/jdtls-workspace/" .. M.workspace_id(root)
end

function M.has_file(root, relative)
  return vim.uv.fs_stat((root or M.project_root()) .. "/" .. relative) ~= nil
end

function M.maven_cmd(root)
  root = root or M.reactor_root()
  if vim.uv.fs_stat(root .. "/mvnw") then
    return root .. "/mvnw"
  end
  return "mvn"
end

function M.gradle_cmd(root)
  root = root or M.project_root()
  if vim.uv.fs_stat(root .. "/gradlew") then
    return root .. "/gradlew"
  end
  return "gradle"
end

return M
