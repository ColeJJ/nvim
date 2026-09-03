-- psql finden, ~/.pgpass prüfen, Verbindung asynchron validieren.

local M = {}

local candidates = {
  "psql",
  "/opt/homebrew/opt/libpq/bin/psql",
  "/usr/local/opt/libpq/bin/psql",
  "/opt/homebrew/bin/psql",
  "/usr/local/bin/psql",
}

function M.bin()
  for _, path in ipairs(candidates) do
    if path == "psql" then
      if vim.fn.executable("psql") == 1 then
        return vim.fn.exepath("psql")
      end
    elseif vim.uv.fs_stat(path) then
      return path
    end
  end
end

function M.ensure_path()
  local bin = M.bin()
  if not bin then
    return nil
  end
  local dir = vim.fn.fnamemodify(bin, ":h")
  local path = vim.env.PATH or ""
  if dir ~= "" and not path:find(dir, 1, true) then
    vim.env.PATH = dir .. ":" .. path
  end
  return bin
end

function M.pgpass_path()
  return vim.fn.expand("~/.pgpass")
end

function M.pgpass_status()
  local path = M.pgpass_path()
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return { ok = false, missing = true, path = path }
  end
  -- uv-mode enthält Dateityp; die unteren 9 Bits sind die Unix-Rechte (0600 = 384).
  local perms = (stat.mode or 0) % 512
  if perms ~= 384 then
    return { ok = false, insecure = true, path = path, perms = perms }
  end
  return { ok = true, path = path }
end

function M.ensure_pgpass()
  local status = M.pgpass_status()
  if status.missing then
    return status
  end
  if status.insecure then
    -- libpq ignoriert die Datei sonst komplett ("no password supplied").
    vim.uv.fs_chmod(status.path, 384)
    status = M.pgpass_status()
    if status.ok then
      vim.notify("~/.pgpass auf 0600 gesetzt (sonst ignoriert psql das Passwort)", vim.log.levels.INFO, {
        title = "Datenbank",
      })
    end
  end
  return status
end

function M.warn_prerequisites()
  if not M.ensure_path() then
    vim.notify(
      "psql nicht gefunden. Homebrew: brew install libpq && brew link --force libpq",
      vim.log.levels.WARN,
      { title = "Datenbank" }
    )
  end
  local pgpass = M.ensure_pgpass()
  if pgpass.missing then
    vim.notify(
      "Keine ~/.pgpass gefunden. Einträge: host:port:database:user:password, danach chmod 600 ~/.pgpass",
      vim.log.levels.WARN,
      { title = "Datenbank" }
    )
  elseif pgpass.insecure then
    vim.notify(
      "~/.pgpass ist nicht 0600. psql ignoriert die Datei sonst. chmod 600 ~/.pgpass",
      vim.log.levels.ERROR,
      { title = "Datenbank" }
    )
  end
end

function M.check(profile, cb)
  local bin = M.ensure_path()
  if not bin then
    vim.notify("psql ist nicht im PATH", vim.log.levels.ERROR, { title = "Datenbank" })
    cb(false)
    return
  end
  local pgpass = M.ensure_pgpass()
  if pgpass.missing then
    vim.notify(
      "Keine ~/.pgpass — psql bekommt kein Passwort. Datei anlegen und chmod 600 ~/.pgpass",
      vim.log.levels.ERROR,
      { title = "Datenbank" }
    )
    cb(false)
    return
  end
  if pgpass.insecure then
    vim.notify(
      profile.name .. ": ~/.pgpass ist zu offen, libpq ignoriert sie. chmod 600 ~/.pgpass",
      vim.log.levels.ERROR,
      { title = "Datenbank" }
    )
    cb(false)
    return
  end
  vim.system({
    bin,
    "-X",
    "-w",
    "--quiet",
    "--no-align",
    "--tuples-only",
    "--set",
    "ON_ERROR_STOP=1",
    "--dbname",
    profile.url,
    "--command",
    "SELECT 1",
  }, {
    text = true,
    timeout = 5000,
  }, vim.schedule_wrap(function(result)
    if result.code == 0 then
      cb(true)
      return
    end
    local detail = vim.trim((result.stderr or "") .. "\n" .. (result.stdout or ""))
    if detail == "" then
      detail = "DB nicht erreichbar oder .pgpass unpassend"
    end
    vim.notify(
      profile.name .. ": Verbindung fehlgeschlagen\n" .. detail,
      vim.log.levels.ERROR,
      { title = "Datenbank" }
    )
    cb(false)
  end))
end

function M.exec(profile, sql, cb)
  local bin = M.ensure_path()
  if not bin then
    cb(nil, "psql ist nicht im PATH")
    return
  end
  local pgpass = M.ensure_pgpass()
  if not pgpass.ok then
    cb(nil, "~/.pgpass fehlt oder ist nicht 0600")
    return
  end
  vim.system({
    bin,
    "-X",
    "-w",
    "--quiet",
    "--set",
    "ON_ERROR_STOP=1",
    "--dbname",
    profile.url,
    "--command",
    sql,
  }, {
    text = true,
    timeout = 15000,
  }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then
      local detail = vim.trim(result.stderr or result.stdout or "Ausführung fehlgeschlagen")
      cb(nil, detail)
      return
    end
    cb(vim.trim(result.stdout or ""), nil)
  end))
end

function M.query(profile, sql, cb)
  local bin = M.ensure_path()
  if not bin then
    cb(nil, "psql ist nicht im PATH")
    return
  end
  local pgpass = M.ensure_pgpass()
  if not pgpass.ok then
    cb(nil, "~/.pgpass fehlt oder ist nicht 0600")
    return
  end
  vim.system({
    bin,
    "-X",
    "-w",
    "--quiet",
    "--no-align",
    "--tuples-only",
    "--set",
    "ON_ERROR_STOP=1",
    "--dbname",
    profile.url,
    "--command",
    sql,
  }, {
    text = true,
    timeout = 15000,
  }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then
      local detail = vim.trim(result.stderr or result.stdout or "Abfrage fehlgeschlagen")
      cb(nil, detail)
      return
    end
    cb(result.stdout or "", nil)
  end))
end

return M
