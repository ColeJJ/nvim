local project = require("colejj.project")

local M = {
  extra_classpath_dirs = { "src/test/resources/conf" },
  ssl_flags = {
    "-Dmaven.resolver.transport=wagon",
    "-Dmaven.wagon.http.ssl.insecure=true",
    "-Dmaven.wagon.http.ssl.allowall=true",
  },
  profile = "ent-dev",
}

function M.detect(root)
  root = root or project.idea_root()
  if project.has_file(root, "src/test/resources/conf/ent.application.properties") then
    return true
  end
  local module, module_dir = project.maven_module()
  if module_dir and vim.uv.fs_stat(module_dir .. "/src/test/resources/conf/ent.application.properties") then
    return true
  end
  local pom = (module_dir or root) .. "/pom.xml"
  if vim.uv.fs_stat(pom) then
    local text = table.concat(vim.fn.readfile(pom), "\n")
    if text:find("ent%-dev", 1, false) then
      return true
    end
  end
  return module == "entscheidungen-webapp" or vim.fn.fnamemodify(root, ":t") == "entscheidungen"
end

function M.maven_flags(root)
  if not M.detect(root) then
    return {}
  end
  local flags = vim.list_extend({ "-P" .. M.profile }, M.ssl_flags)
  return flags
end

function M.sync_extra_classpath(working_directory)
  if not working_directory or vim.fn.isdirectory(working_directory) == 0 then
    return
  end
  if not M.detect(working_directory) and not M.detect(project.idea_root()) then
    return
  end
  local target = working_directory .. "/target/classes"
  local synced = {}
  for _, relative in ipairs(M.extra_classpath_dirs) do
    local source = working_directory .. "/" .. relative
    if vim.fn.isdirectory(source) == 1 then
      vim.fn.mkdir(target, "p")
      vim.fn.system({ "cp", "-R", source .. "/.", target .. "/" })
      table.insert(synced, source)
    end
  end
  if #synced > 0 then
    vim.notify("Entwicklungsressourcen nach target/classes gespiegelt", vim.log.levels.INFO, { title = "colejj.java" })
  end
end

function M.kotlin_output_dirs(root)
  root = root or project.reactor_root()
  local dirs = {}
  local handle = vim.uv.fs_scandir(root)
  if not handle then
    return dirs
  end
  while true do
    local name, typ = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if typ == "directory" then
      for _, rel in ipairs({
        name .. "/target/classes",
        name .. "/target/kotlin-classes/main",
        name .. "/build/classes/kotlin/main",
      }) do
        local path = root .. "/" .. rel
        if vim.fn.isdirectory(path) == 1 then
          table.insert(dirs, path)
        end
      end
    end
  end
  return dirs
end

return M
