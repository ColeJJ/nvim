local project = require("colejj.project")
local compat = require("colejj.java.compat")

local M = {}

local function run(args, cwd, title)
  cwd = cwd or project.reactor_root()
  local cmd = { project.maven_cmd(cwd) }
  vim.list_extend(cmd, compat.maven_flags(cwd))
  vim.list_extend(cmd, args)
  require("colejj.java.output").run({
    cmd = cmd,
    cwd = cwd,
    title = title or "Maven",
  })
end

function M.compile(module_only)
  local args = { "compile" }
  if module_only then
    local module = select(1, project.maven_module())
    if module then
      args = { "-pl", module, "-am", "compile" }
    end
  end
  run(args)
end

function M.install(skip_tests)
  local args = { "install" }
  if skip_tests then
    table.insert(args, 1, "-DskipTests")
  end
  run(args)
end

function M.rebuild()
  run({ "clean", "install", "-DskipTests" })
end

function M.test()
  local module = select(1, project.maven_module())
  if module then
    run({ "-pl", module, "-am", "test" })
  else
    run({ "test" })
  end
end

function M.dependency_tree()
  run({ "dependency:tree" })
end

function M.execute_goal()
  vim.ui.input({ prompt = "Maven Goal: ", default = "clean install -DskipTests" }, function(goal)
    if not goal or goal == "" then
      return
    end
    run(vim.split(goal, "%s+"))
  end)
end

return M
