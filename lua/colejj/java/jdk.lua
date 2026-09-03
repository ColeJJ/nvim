local M = {}

local version_names = {
  ["17"] = "JavaSE-17",
  ["19"] = "JavaSE-19",
  ["20"] = "JavaSE-20",
  ["21"] = "JavaSE-21",
  ["22"] = "JavaSE-22",
  ["23"] = "JavaSE-23",
  ["24"] = "JavaSE-24",
  ["25"] = "JavaSE-25",
}

local function exists(path)
  return path and vim.uv.fs_stat(path) ~= nil
end

local function java_home_candidates(version)
  local homes = {}
  local patterns = {
    "/Library/Java/JavaVirtualMachines/temurin-%s.jdk/Contents/Home",
    "/Library/Java/JavaVirtualMachines/temurin-%s.jdk/Contents/Home",
    "/Library/Java/JavaVirtualMachines/jdk-%s.jdk/Contents/Home",
    "/Library/Java/JavaVirtualMachines/openjdk-%s.jdk/Contents/Home",
    "/Library/Java/JavaVirtualMachines/zulu-%s.jdk/Contents/Home",
    "/opt/homebrew/opt/openjdk@%s",
    "/usr/local/opt/openjdk@%s",
    "/opt/jdk-%s",
  }
  for _, pattern in ipairs(patterns) do
    table.insert(homes, pattern:format(version))
  end
  return homes
end

function M.find(version)
  for _, path in ipairs(java_home_candidates(version)) do
    if exists(path .. "/bin/java") then
      return path
    end
  end
end

function M.runtimes()
  local runtimes = {}
  local seen = {}
  for version, name in pairs(version_names) do
    local path = M.find(version)
    if path and not seen[path] then
      seen[path] = true
      table.insert(runtimes, {
        name = name,
        path = path,
        default = version == "17",
      })
    end
  end
  table.sort(runtimes, function(a, b)
    return a.name < b.name
  end)
  return runtimes
end

function M.jdtls_home()
  return M.find("21") or M.find("25") or M.find("17") or os.getenv("JAVA_HOME")
end

function M.validate()
  local home = M.jdtls_home()
  if not home then
    vim.notify(
      "Kein JDK 21/17 gefunden. JDT.LS braucht mindestens Java 21. Installiere Temurin oder setze JAVA_HOME.",
      vim.log.levels.WARN,
      { title = "colejj.java" }
    )
  end
  return home
end

return M
