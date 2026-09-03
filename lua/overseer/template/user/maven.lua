local project = require("colejj.project")
local compat = require("colejj.java.compat")

local goals = {
  { name = "Maven compile (Reactor)", args = { "compile" } },
  { name = "Maven test (Reactor)", args = { "test" } },
  { name = "Maven install (Reactor)", args = { "install" } },
  { name = "Maven clean install", args = { "clean", "install" } },
  { name = "Maven clean install -DskipTests", args = { "clean", "install", "-DskipTests" } },
  { name = "Maven verify", args = { "verify" } },
  { name = "Maven deploy", args = { "deploy" } },
  { name = "Maven dependency:tree", args = { "dependency:tree" } },
}

local function condition()
  return vim.uv.fs_stat(project.reactor_root() .. "/pom.xml") ~= nil
end

local templates = {}

for _, goal in ipairs(goals) do
  table.insert(templates, {
    name = goal.name,
    builder = function()
      local root = project.reactor_root()
      local args = vim.list_extend(compat.maven_flags(root), goal.args)
      return {
        cmd = { project.maven_cmd(root) },
        args = args,
        cwd = root,
        components = {
          { "on_output_quickfix", open = true },
          "on_result_diagnostics",
          "on_exit_set_status",
          "default",
        },
      }
    end,
    condition = { callback = condition },
    tags = { "maven", "build" },
  })
end

table.insert(templates, {
  name = "Maven compile (Modul + Upstream)",
  builder = function()
    local root = project.reactor_root()
    local module = select(1, project.maven_module()) or "."
    local args = vim.list_extend(compat.maven_flags(root), { "-pl", module, "-am", "compile" })
    return {
      cmd = { project.maven_cmd(root) },
      args = args,
      cwd = root,
      components = {
        { "on_output_quickfix", open = true },
        "on_result_diagnostics",
        "on_exit_set_status",
        "default",
      },
    }
  end,
  condition = { callback = condition },
  tags = { "maven", "build" },
})

table.insert(templates, {
  name = "Maven install (Modul + Upstream)",
  builder = function()
    local root = project.reactor_root()
    local module = select(1, project.maven_module()) or "."
    local args = vim.list_extend(compat.maven_flags(root), { "-pl", module, "-am", "-DskipTests", "install" })
    return {
      cmd = { project.maven_cmd(root) },
      args = args,
      cwd = root,
      components = {
        { "on_output_quickfix", open = true },
        "on_result_diagnostics",
        "on_exit_set_status",
        "default",
      },
    }
  end,
  condition = { callback = condition },
  tags = { "maven", "build" },
})

table.insert(templates, {
  name = "Maven Goal eingeben",
  builder = function(params)
    local root = project.reactor_root()
    local extra = vim.split(params.goal or "compile", "%s+")
    local args = vim.list_extend(compat.maven_flags(root), extra)
    return {
      cmd = { project.maven_cmd(root) },
      args = args,
      cwd = root,
      components = {
        { "on_output_quickfix", open = true },
        "on_result_diagnostics",
        "on_exit_set_status",
        "default",
      },
    }
  end,
  params = {
    goal = {
      type = "string",
      default = "clean install -DskipTests",
    },
  },
  condition = { callback = condition },
  tags = { "maven" },
})

return templates
