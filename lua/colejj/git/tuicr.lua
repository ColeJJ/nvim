local M = {}

local function missing(bin, hint)
  if vim.fn.executable(bin) == 1 then
    return false
  end
  vim.notify(bin .. " fehlt.\n" .. hint, vim.log.levels.ERROR, { title = "tuicr" })
  return true
end

local function ready()
  if missing("tuicr", "brew install tuicr") then
    return false
  end
  if missing("glab", "brew install glab\nglab auth login --hostname <gitlab-host>") then
    return false
  end
  return true
end

local function current_mr()
  local root = require("colejj.project").git_root()
  if not root then
    return nil, "Kein Git-Repository"
  end
  local result = vim.system({ "glab", "mr", "view", "--output", "json" }, {
    cwd = root,
    text = true,
    timeout = 20000,
  }):wait()
  if result.code ~= 0 then
    local detail = vim.trim(result.stderr or result.stdout or "glab findet keinen MR zum Branch")
    return nil, detail
  end
  local ok, decoded = pcall(vim.json.decode, result.stdout or "")
  local iid = ok and decoded and (decoded.iid or decoded.IID)
  if not iid then
    return nil, "glab hat keine MR-Nummer geliefert"
  end
  return tostring(iid)
end

function M.open(target)
  if not ready() then
    return
  end
  target = vim.trim(target or "")
  if target == "" then
    local iid, err = current_mr()
    if not iid then
      vim.notify(err, vim.log.levels.ERROR, { title = "tuicr" })
      return
    end
    target = iid
  end
  require("tuicr").open({ extra_args = { "mr", target } })
end

function M.prompt()
  if not ready() then
    return
  end
  vim.ui.input({
    prompt = "GitLab-MR (Nummer oder URL, leer = aktueller Branch): ",
  }, function(value)
    if value == nil then
      return
    end
    M.open(value)
  end)
end

return M
