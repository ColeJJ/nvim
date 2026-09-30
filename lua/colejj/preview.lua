-- Telescope-Datei-Preview: bei Java/Kotlin/Scala zur Typdeklaration springen,
-- statt in den Imports stehenzubleiben.

local M = {}

local EXT = {
  java = true,
  kt = true,
  kts = true,
  scala = true,
  sc = true,
  groovy = true,
}

local TYPE = {
  class = true,
  interface = true,
  enum = true,
  record = true,
  object = true,
  trait = true,
}

local MOD = {
  public = true,
  protected = true,
  private = true,
  abstract = true,
  final = true,
  static = true,
  sealed = true,
  strictfp = true,
  native = true,
  synchronized = true,
  default = true,
  open = true,
  inner = true,
  data = true,
  value = true,
  annotation = true,
  inline = true,
  actual = true,
  expect = true,
  internal = true,
  fun = true,
  case = true,
  implicit = true,
  lazy = true,
  override = true,
  ["non-sealed"] = true,
}

local function strip_comments(line, in_block)
  if in_block then
    local endc = line:find("%*/", 1, true)
    if not endc then
      return "", true
    end
    line = line:sub(endc + 2)
    in_block = false
  end
  local startc = line:find("/%*", 1, true)
  while startc do
    local endc = line:find("%*/", startc + 2, true)
    if endc then
      line = line:sub(1, startc - 1) .. " " .. line:sub(endc + 2)
      startc = line:find("/%*", 1, true)
    else
      line = line:sub(1, startc - 1)
      in_block = true
      break
    end
  end
  line = line:gsub("//.*", "")
  return line, in_block
end

local function strip_leading_annotations(line)
  while true do
    if line:match("^@interface%f[%W]") then
      return line
    end
    local next_line = line:gsub("^@[%w_.]+%b()%s*", ""):gsub("^@[%w_.]+%s+", "")
    if next_line == line then
      return line
    end
    line = next_line
  end
end

function M.first_type_lnum(lines)
  local in_block = false
  local last = math.min(#lines, 500)
  for i = 1, last do
    local line
    line, in_block = strip_comments(lines[i], in_block)
    line = vim.trim(line)
    if line ~= "" and not line:match("^package%s") and not line:match("^import%s") then
      if not (line:match("^@[%w_.]+%s*$") or line:match("^@[%w_.]+%b()%s*$")) then
        line = strip_leading_annotations(line)
        if not line:match("^companion%s+object%f[%W]") then
          local words = {}
          for w in line:gmatch("[%w_@%-]+") do
            words[#words + 1] = w
          end
          local idx = 1
          while words[idx] and (MOD[words[idx]] or (words[idx]:sub(1, 1) == "@" and words[idx] ~= "@interface")) do
            idx = idx + 1
          end
          local word = words[idx]
          local nxt = words[idx + 1]
          if word == "enum" and nxt == "class" then
            return i
          end
          if word == "fun" and nxt == "interface" then
            return i
          end
          if word == "annotation" and nxt == "class" then
            return i
          end
          if TYPE[word] and nxt and nxt:match("^[%a_]") then
            return i
          end
          if word == "@interface" then
            return i
          end
        end
      end
    end
  end
  return nil
end

function M.jump_to_type(bufnr, winid, filepath)
  filepath = tostring(filepath or "")
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 500, false)
  local ext = filepath:match("%.([%w]+)$")
  local jvm = EXT[ext or ""]
  if not jvm then
    for i = 1, math.min(40, #lines) do
      if lines[i]:match("^%s*package%s") or lines[i]:match("^%s*import%s+[%w_.]+;") then
        jvm = true
        break
      end
    end
  end
  if not jvm then
    return
  end
  local lnum = M.first_type_lnum(lines)
  if not lnum then
    return
  end
  if not (winid and vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr) then
    winid = nil
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == bufnr then
        winid = win
        break
      end
    end
  end
  if not winid then
    return
  end
  pcall(vim.api.nvim_win_set_cursor, winid, { lnum, 0 })
  pcall(vim.api.nvim_win_call, winid, function()
    vim.fn.winrestview({ lnum = lnum, col = 0, topline = lnum, curswant = 0 })
  end)
end

return M
