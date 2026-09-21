local M = {}

function M.uuid()
  if vim.fn.executable("uuidgen") == 1 then
    return vim.fn.system("uuidgen"):gsub("%s+", ""):lower()
  end
  return vim.fn.system("python3 -c 'import uuid; print(uuid.uuid4())'"):gsub("%s+", "")
end

function M.fk_suffix()
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local out = {}
  for _ = 1, 22 do
    local idx = math.random(#chars)
    table.insert(out, chars:sub(idx, idx))
  end
  return table.concat(out)
end

function M.fk_name()
  return "FK_" .. M.fk_suffix()
end

--- Gleicher FK-Name an mehreren Stellen einer Expansion (Constraint + Index).
function M.fk_once(snip, key)
  snip.colejj_fk = snip.colejj_fk or {}
  if not snip.colejj_fk[key] then
    snip.colejj_fk[key] = M.fk_name()
  end
  return snip.colejj_fk[key]
end

function M.class_name()
  local ok, utils = pcall(require, "colejj.utils")
  if ok then
    local name = utils.get_current_class_name()
    if name and name ~= "" then
      return name
    end
  end
  return vim.fn.expand("%:t:r")
end

function M.decap(text)
  if not text or text == "" then
    return ""
  end
  return text:sub(1, 1):lower() .. text:sub(2)
end

function M.capitalize_camel(text)
  if not text or text == "" then
    return ""
  end
  local parts = vim.split(text, "[^%w]+", { trimempty = true })
  if #parts == 0 then
    return ""
  end
  local camel = parts[1]
  for i = 2, #parts do
    camel = camel .. parts[i]:sub(1, 1):upper() .. parts[i]:sub(2)
  end
  return camel:sub(1, 1):upper() .. camel:sub(2)
end

return M
