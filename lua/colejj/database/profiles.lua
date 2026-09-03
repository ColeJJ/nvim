-- Benannte Postgres-Profile analog zu Doom `+pg-profiles`.
-- Passwörter stehen bewusst nicht hier, sondern in ~/.pgpass.

local M = {}

local defaults = {
  {
    name = "ENT - Postgres (5432)",
    user = "ent",
    host = "localhost",
    port = 5432,
    database = "Entscheidungen",
  },
  {
    name = "BAS - Postgres (5433)",
    user = "ent",
    host = "localhost",
    port = 5433,
    database = "EntscheidungenBasis",
  },
  {
    name = "ENT - Kundenversion - Entscheidungen (5440)",
    user = "ent",
    host = "localhost",
    port = 5440,
    database = "Entscheidungen",
  },
  {
    name = "ENT - Kundenversion - Basis (5440)",
    user = "ent",
    host = "localhost",
    port = 5440,
    database = "EntscheidungenBasis",
  },
  {
    name = "Guide-Client - magellan (5432)",
    user = "sa",
    host = "localhost",
    port = 5432,
    database = "magellan",
  },
}

local function normalize(profile)
  if type(profile) ~= "table" or not profile.name then
    return nil
  end
  return {
    name = profile.name,
    user = profile.user or "ent",
    host = profile.host or "localhost",
    port = tonumber(profile.port) or 5432,
    database = profile.database or profile.dbname,
    sslmode = profile.sslmode or ((profile.host == nil or profile.host == "localhost") and "disable" or "prefer"),
  }
end

function M.url(profile)
  return string.format(
    "postgresql://%s@%s:%d/%s?sslmode=%s",
    profile.user,
    profile.host,
    profile.port,
    profile.database,
    profile.sslmode
  )
end

local function load_local()
  local path = vim.fn.stdpath("config") .. "/lua/colejj/database/profiles.local.lua"
  if vim.fn.filereadable(path) ~= 1 then
    return {}
  end
  local ok, extra = pcall(dofile, path)
  if not ok or type(extra) ~= "table" then
    vim.notify("profiles.local.lua ungültig: " .. tostring(extra), vim.log.levels.WARN, { title = "Datenbank" })
    return {}
  end
  return extra
end

function M.all()
  local by_name = {}
  local list = {}
  local function add(raw)
    local profile = normalize(raw)
    if not profile or not profile.database then
      return
    end
    profile.url = M.url(profile)
    if by_name[profile.name] then
      for i, existing in ipairs(list) do
        if existing.name == profile.name then
          list[i] = profile
          break
        end
      end
    else
      list[#list + 1] = profile
    end
    by_name[profile.name] = profile
  end
  for _, profile in ipairs(defaults) do
    add(profile)
  end
  for _, profile in ipairs(load_local()) do
    add(profile)
  end
  return list
end

function M.sorted()
  local list = M.all()
  local ok, compat = pcall(require, "colejj.java.compat")
  if not ok or not compat.detect() then
    return list
  end
  table.sort(list, function(a, b)
    local a_ent = a.name:find("^ENT", 1) and 0 or 1
    local b_ent = b.name:find("^ENT", 1) and 0 or 1
    if a_ent ~= b_ent then
      return a_ent < b_ent
    end
    return a.port < b.port
  end)
  return list
end

function M.dadbod_list()
  local dbs = {}
  for _, profile in ipairs(M.all()) do
    dbs[#dbs + 1] = { name = profile.name, url = profile.url }
  end
  return dbs
end

function M.dbee_list()
  local connections = {}
  for _, profile in ipairs(M.all()) do
    connections[#connections + 1] = {
      id = vim.fn.sha256(profile.name):sub(1, 16),
      name = profile.name,
      type = "postgres",
      -- DBee verwendet lib/pq; ein fehlendes Passwort wird aus ~/.pgpass gelesen.
      url = profile.url,
    }
  end
  return connections
end

return M
