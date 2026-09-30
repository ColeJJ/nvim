-- GitLab-API für den MR-Review (SPC g m). Token nie loggen.

local M = {}

local token_cache = {}

local function git_root()
  return require("colejj.project").git_root()
end

local function git_trim(root, args)
  local cmd = { "git", "-C", root }
  vim.list_extend(cmd, args)
  local result = vim.system(cmd, { text = true, timeout = 5000 }):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.trim(result.stdout or "")
end

local function local_cfg()
  local path = vim.fn.stdpath("config") .. "/lua/colejj/git/review.local.lua"
  if vim.uv.fs_stat(path) == nil then
    return {}
  end
  local ok, cfg = pcall(dofile, path)
  if not ok or type(cfg) ~= "table" then
    vim.notify("review.local.lua ungültig", vim.log.levels.WARN, { title = "GitLab" })
    return {}
  end
  return cfg
end

local function authinfo_token(host)
  local path = vim.fn.expand("~/.authinfo")
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local text = f:read("*a") or ""
  f:close()
  for line in vim.gsplit(text, "\n", { trimempty = true }) do
    local machine = line:match("machine%s+(%S+)")
    local pass = line:match("password%s+(%S+)")
    if machine and pass then
      local mhost = machine:gsub("/api/v4$", "")
      if mhost == host then
        return pass
      end
    end
  end
end

local function credential_token(host)
  local result = vim.system({ "git", "credential", "fill" }, {
    text = true,
    stdin = string.format("protocol=https\nhost=%s\n\n", host),
    timeout = 15000,
  }):wait()
  if result.code ~= 0 then
    return nil
  end
  for line in vim.gsplit(result.stdout or "", "\n", { trimempty = true }) do
    local pass = line:match("^password=(.+)$")
    if pass and pass ~= "" then
      return pass
    end
  end
end

local function token_for(host)
  if token_cache[host] then
    return token_cache[host]
  end
  local cfg = local_cfg()
  local token = os.getenv("GITLAB_TOKEN")
    or os.getenv("GITLAB_PRIVATE_TOKEN")
    or (cfg.tokens and cfg.tokens[host])
    or cfg.token
    or authinfo_token(host)
    or credential_token(host)
  if token and token ~= "" then
    token_cache[host] = token
  end
  return token
end

function M.parse_remote(url)
  if not url or url == "" then
    return nil
  end
  url = url:gsub("%.git$", ""):gsub("%s+$", "")
  local host, path = url:match("^https?://([^/]+)/(.+)$")
  if not host then
    host, path = url:match("^git@([^:]+):(.+)$")
  end
  if not host then
    host, path = url:match("^ssh://[^@]+@([^/]+)/(.+)$")
  end
  if not host or not path then
    return nil
  end
  path = path:gsub("^/+", "")
  return {
    host = host,
    path = path,
    api = "https://" .. host .. "/api/v4",
  }
end

function M.project_id(path)
  return (path or ""):gsub("/", "%%2F")
end

function M.context()
  local root = git_root()
  if not root then
    return nil, "Kein Git-Repository"
  end
  local urls = {}
  local origin = git_trim(root, { "remote", "get-url", "origin" })
  if origin then
    urls[#urls + 1] = origin
  end
  local listed = vim.system({ "git", "-C", root, "remote", "-v" }, { text = true, timeout = 4000 }):wait()
  if listed.code == 0 then
    for line in vim.gsplit(listed.stdout or "", "\n", { trimempty = true }) do
      local url = line:match("%S+%s+(%S+)%s+%(fetch%)")
      if url then
        urls[#urls + 1] = url
      end
    end
  end
  local remote
  for _, url in ipairs(urls) do
    local parsed = M.parse_remote(url)
    if parsed and parsed.host:find("gitlab", 1, true) then
      remote = parsed
      break
    end
    remote = remote or parsed
  end
  if not remote then
    return nil, "Kein GitLab-Remote gefunden"
  end
  local token = token_for(remote.host)
  if not token then
    return nil,
      "Kein GitLab-Token. GITLAB_TOKEN setzen, ~/.authinfo (machine "
        .. remote.host
        .. " login USER password TOKEN) oder lua/colejj/git/review.local.lua"
  end
  local cfg = local_cfg()
  return {
    root = root,
    host = remote.host,
    path = remote.path,
    api = remote.api,
    id = M.project_id(remote.path),
    token = token,
    insecure = cfg.insecure == true,
  }
end

local function decode_body(text)
  if not text or text == "" then
    return nil
  end
  local ok, data = pcall(vim.json.decode, text)
  if ok then
    return data
  end
  return nil
end

local function api_error(status, body)
  if status == 401 or status == 403 then
    return "GitLab: nicht berechtigt (Token / api-Scope prüfen)"
  end
  local data = decode_body(body)
  local msg = data and (data.message or data.error)
  if type(msg) == "table" then
    msg = vim.inspect(msg)
  end
  if msg and msg ~= "" then
    return "GitLab: " .. tostring(msg)
  end
  return "GitLab HTTP " .. tostring(status)
end

function M.request(ctx, method, path, payload)
  if vim.fn.executable("curl") ~= 1 then
    return nil, "curl nicht gefunden"
  end
  local url = ctx.api .. path
  local args = {
    "curl",
    "-sS",
    "-X",
    method,
    "-H",
    "PRIVATE-TOKEN: " .. ctx.token,
    "-H",
    "Content-Type: application/json",
    "--max-time",
    "25",
    "-w",
    "\n%{http_code}",
  }
  if ctx.insecure then
    args[#args + 1] = "-k"
  end
  if payload ~= nil then
    args[#args + 1] = "-d"
    args[#args + 1] = vim.json.encode(payload)
  end
  args[#args + 1] = url
  local result = vim.system(args, { text = true, timeout = 30000 }):wait()
  local out = result.stdout or ""
  local status = tonumber(out:match("\n(%d+)\n?$")) or 0
  local body = out:gsub("\n%d+\n?$", "")
  if result.code ~= 0 and status == 0 then
    return nil, vim.trim(result.stderr or "GitLab nicht erreichbar")
  end
  if status < 200 or status >= 300 then
    return nil, api_error(status, body)
  end
  if body == "" then
    return {}
  end
  local data = decode_body(body)
  if data == nil then
    return nil, "GitLab: ungültige Antwort"
  end
  return data
end

function M.list_mrs(ctx, query)
  query = query or "state=opened&per_page=80&order_by=updated_at&sort=desc"
  return M.request(ctx, "GET", "/projects/" .. ctx.id .. "/merge_requests?" .. query)
end

function M.get_mr(ctx, iid)
  return M.request(ctx, "GET", "/projects/" .. ctx.id .. "/merge_requests/" .. iid)
end

function M.discussions(ctx, iid)
  return M.request(ctx, "GET", "/projects/" .. ctx.id .. "/merge_requests/" .. iid .. "/discussions?per_page=100")
end

function M.approvals(ctx, iid)
  return M.request(ctx, "GET", "/projects/" .. ctx.id .. "/merge_requests/" .. iid .. "/approvals")
end

function M.approve(ctx, iid)
  return M.request(ctx, "POST", "/projects/" .. ctx.id .. "/merge_requests/" .. iid .. "/approve", {})
end

function M.unapprove(ctx, iid)
  return M.request(ctx, "POST", "/projects/" .. ctx.id .. "/merge_requests/" .. iid .. "/unapprove", {})
end

function M.note(ctx, iid, body)
  return M.request(ctx, "POST", "/projects/" .. ctx.id .. "/merge_requests/" .. iid .. "/notes", { body = body })
end

function M.reply(ctx, iid, discussion_id, body)
  return M.request(
    ctx,
    "POST",
    "/projects/" .. ctx.id .. "/merge_requests/" .. iid .. "/discussions/" .. discussion_id .. "/notes",
    { body = body }
  )
end

function M.has_rev(ctx, rev)
  if not rev or rev == "" then
    return false
  end
  local result = vim.system({
    "git",
    "-C",
    ctx.root,
    "cat-file",
    "-e",
    rev .. "^{commit}",
  }, { text = true, timeout = 3000 }):wait()
  return result.code == 0
end

function M.fetch_mr(ctx, mr)
  local iid = tostring(mr.iid)
  local target = mr.target_branch
  local spec = "+refs/merge-requests/" .. iid .. "/head:refs/remotes/origin/mr-" .. iid
  local args = { "git", "-C", ctx.root, "fetch", "--quiet", "origin", spec }
  if target and target ~= "" then
    args[#args + 1] = target
  end
  local result = vim.system(args, { text = true, timeout = 60000 }):wait()
  if result.code ~= 0 then
    return nil, vim.trim(result.stderr or result.stdout or "git fetch fehlgeschlagen")
  end
  return true
end

return M
