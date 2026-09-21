-- Unified File-Diff wie Magit `SPC g d` / LazyGit nach Enter:
-- eine Datei, readonly, e springt, d verwirft den Hunk nach Nachfrage.

local M = {}

local buf
local win
local origin_win
local meta = {
  file = "",
  root = "",
  rel = "",
  rev = "HEAD",
}
local view = {
  lines = {},
  hunks = {},
  locs = {},
}

local function valid_win()
  return win and vim.api.nvim_win_is_valid(win)
end

local function valid_buf()
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function git_root()
  return require("colejj.project").git_root()
end

local function nvim_tree_file()
  if vim.bo.filetype ~= "NvimTree" then
    return nil
  end
  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then
    return nil
  end
  local node = api.tree.get_node_under_cursor()
  if not node or node.type == "directory" or not node.absolute_path then
    return nil
  end
  return node.absolute_path
end

local function oil_file()
  if vim.bo.filetype ~= "oil" then
    return nil
  end
  local ok, oil = pcall(require, "oil")
  if not ok then
    return nil
  end
  local entry = oil.get_cursor_entry()
  if not entry or entry.type == "directory" or not entry.name then
    return nil
  end
  local dir = oil.get_current_dir()
  if not dir then
    return nil
  end
  return dir .. entry.name
end

local function current_file()
  local from_tree = nvim_tree_file() or oil_file()
  if from_tree then
    return from_tree
  end
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" or require("colejj.project").is_virtual_path(name) then
    return nil
  end
  return vim.fn.fnamemodify(name, ":p")
end

local function relpath(abs, root)
  abs = vim.fn.fnamemodify(abs, ":p")
  root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  if abs:sub(1, #root + 1) == root .. "/" then
    return abs:sub(#root + 2)
  end
  return vim.fn.fnamemodify(abs, ":t")
end

local function git_run(args)
  return vim.system(args, { text = true }):wait()
end

local function git_diff(root, rev, rel)
  local result = git_run({
    "git",
    "-C",
    root,
    "-c",
    "core.quotepath=false",
    "diff",
    "--no-color",
    "--no-ext-diff",
    rev,
    "--",
    rel,
  })
  if result.code ~= 0 and (result.stdout or "") == "" then
    return nil, vim.trim(result.stderr or "git diff fehlgeschlagen")
  end
  local out = result.stdout or ""
  if out == "" then
    local tracked = git_run({ "git", "-C", root, "ls-files", "--error-unmatch", "--", rel })
    if tracked.code ~= 0 then
      result = git_run({
        "git",
        "-C",
        root,
        "-c",
        "core.quotepath=false",
        "diff",
        "--no-color",
        "--no-ext-diff",
        "--no-index",
        "--",
        "/dev/null",
        rel,
      })
      out = result.stdout or ""
      if out == "" then
        return nil, vim.trim(result.stderr or "")
      end
    else
      return nil, nil
    end
  end
  return vim.split(out:gsub("\n$", ""), "\n", { plain = true })
end

local function hunk_count(raw)
  if raw == nil or raw == "" then
    return 1
  end
  return tonumber(raw) or 1
end

local function parse_hunks(lines)
  local hunks = {}
  local locs = {}
  local hunk
  local old_line, new_line
  for i, line in ipairs(lines) do
    local old_s, old_c, new_s, new_c = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
    if old_s then
      hunk = {
        buf_start = i,
        buf_end = i,
        old_start = tonumber(old_s),
        old_count = hunk_count(old_c),
        new_start = tonumber(new_s),
        new_count = hunk_count(new_c),
      }
      old_line = hunk.old_start
      new_line = hunk.new_start
      hunks[#hunks + 1] = hunk
      locs[i] = { kind = "@", new = hunk.new_start, old = hunk.old_start }
    elseif hunk then
      hunk.buf_end = i
      local mark = line:sub(1, 1)
      if mark == "+" then
        locs[i] = { kind = "+", new = new_line, old = old_line }
        new_line = new_line + 1
      elseif mark == "-" then
        locs[i] = { kind = "-", new = new_line, old = old_line }
        old_line = old_line + 1
      elseif mark ~= "\\" then
        locs[i] = { kind = " ", new = new_line, old = old_line }
        old_line = old_line + 1
        new_line = new_line + 1
      end
    end
  end
  return hunks, locs
end

local function hunk_at(lnum, hunks)
  for _, hunk in ipairs(hunks) do
    if lnum >= hunk.buf_start and lnum <= hunk.buf_end then
      return hunk
    end
  end
  return hunks[1]
end

local function location_at(lnum, hunks, locs)
  local loc = locs[lnum]
  if loc and (loc.new or loc.old) then
    return loc
  end
  local hunk = hunk_at(lnum, hunks)
  if hunk then
    return { kind = "@", new = hunk.new_start, old = hunk.old_start }
  end
end

local function header_lines(lines)
  local header = {}
  for _, line in ipairs(lines) do
    if line:find("^@@") then
      break
    end
    header[#header + 1] = line
  end
  if #header == 0 then
    return {
      "diff --git a/" .. meta.rel .. " b/" .. meta.rel,
      "--- a/" .. meta.rel,
      "+++ b/" .. meta.rel,
    }
  end
  return header
end

local function set_winbar(title)
  if not valid_win() then
    return
  end
  vim.wo[win].winbar = "%#Title#"
    .. title
    .. "%*  e/RET Datei  d verwerfen  n/p Hunk  r neu  q"
end

function M.foldexpr(lnum)
  local line = vim.fn.getline(lnum)
  if line:find("^diff ") or line:find("^@@") then
    return ">1"
  end
  return "="
end

local function ensure_window(title)
  if valid_win() and valid_buf() then
    vim.api.nvim_set_current_win(win)
    set_winbar(title)
    return
  end
  origin_win = vim.api.nvim_get_current_win()
  vim.cmd("tabnew")
  win = vim.api.nvim_get_current_win()
  buf = vim.api.nvim_win_get_buf(win)
  pcall(vim.api.nvim_buf_set_name, buf, "colejj-diff://" .. meta.rel)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "diff"
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "1"
  vim.wo[win].foldmethod = "expr"
  vim.wo[win].foldexpr = "v:lua.require'colejj.git.filediff'.foldexpr(v:lnum)"
  vim.wo[win].foldlevel = 99
  set_winbar(title)
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      win = nil
      buf = nil
    end,
  })
end

function M.close()
  if valid_win() then
    local tab = vim.api.nvim_win_get_tabpage(win)
    if #vim.api.nvim_list_tabpages() > 1 then
      vim.cmd(vim.api.nvim_tabpage_get_number(tab) .. "tabclose")
    else
      vim.api.nvim_win_close(win, true)
    end
  end
  win = nil
  buf = nil
end

local function set_lines(lines)
  vim.bo[buf].readonly = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].modified = false
end

local function jump_to_file_line(file_lnum, hunks, locs)
  if not file_lnum or file_lnum < 1 or not hunks then
    return
  end
  local best, best_dist
  for i, loc in pairs(locs) do
    if loc.new then
      local dist = math.abs(loc.new - file_lnum)
      if not best_dist or dist < best_dist then
        best, best_dist = i, dist
      end
    end
  end
  if best then
    pcall(vim.api.nvim_win_set_cursor, win, { best, 0 })
  end
end

local function render(opts)
  opts = opts or {}
  local lines, err = git_diff(meta.root, meta.rev, meta.rel)
  if not lines then
    if err and err ~= "" then
      vim.notify(err, vim.log.levels.ERROR, { title = "Git" })
    elseif not opts.silent_empty then
      vim.notify("Keine Änderungen in " .. meta.rel, vim.log.levels.INFO, { title = "Git" })
    end
    M.close()
    return false
  end
  view.lines = lines
  view.hunks, view.locs = parse_hunks(lines)
  set_lines(lines)
  if opts.file_lnum then
    jump_to_file_line(opts.file_lnum, view.hunks, view.locs)
  end
  return true
end

local function hunk_patch(hunk)
  local lines = view.lines
  local header = header_lines(lines)
  local body = {}
  for i = hunk.buf_start, hunk.buf_end do
    body[#body + 1] = lines[i]
  end
  return table.concat(header, "\n") .. "\n" .. table.concat(body, "\n") .. "\n"
end

local function apply_reverse(patch)
  local args_index = {
    "git",
    "-C",
    meta.root,
    "apply",
    "--reverse",
    "--index",
    "--whitespace=nowarn",
    "-",
  }
  local result = vim.system(args_index, { text = true, stdin = patch }):wait()
  if result.code == 0 then
    return true, ""
  end
  local result2 = vim.system({
    "git",
    "-C",
    meta.root,
    "apply",
    "--reverse",
    "--whitespace=nowarn",
    "-",
  }, { text = true, stdin = patch }):wait()
  if result2.code == 0 then
    return true, ""
  end
  local err = vim.trim(result2.stderr or result.stderr or result.stdout or "")
  return false, err
end

local function reload_file()
  local abs = vim.fn.fnamemodify(meta.file, ":p")
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then
      local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":p")
      if name == abs then
        vim.api.nvim_buf_call(b, function()
          vim.cmd("checktime")
          if vim.bo.buftype == "" and not vim.bo.modified then
            vim.cmd("silent edit")
          end
        end)
      end
    end
  end
end

function M.goto_file()
  if not valid_buf() then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local loc = location_at(lnum, view.hunks, view.locs)
  local target = loc and (loc.new or loc.old) or 1
  local file = meta.file
  local origin = origin_win
  M.close()
  if origin and vim.api.nvim_win_is_valid(origin) then
    local obuf = vim.api.nvim_win_get_buf(origin)
    if vim.bo[obuf].buftype == "" then
      vim.api.nvim_set_current_win(origin)
    end
  end
  vim.cmd.edit(vim.fn.fnameescape(file))
  pcall(vim.api.nvim_win_set_cursor, 0, { math.max(target, 1), 0 })
  vim.cmd.normal({ "zvzz", bang = true })
end

function M.next_hunk(dir)
  local hunks = view.hunks
  if #hunks == 0 then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local dest
  if dir > 0 then
    for _, hunk in ipairs(hunks) do
      if hunk.buf_start > lnum then
        dest = hunk.buf_start
        break
      end
    end
    dest = dest or hunks[1].buf_start
  else
    for i = #hunks, 1, -1 do
      if hunks[i].buf_start < lnum then
        dest = hunks[i].buf_start
        break
      end
    end
    dest = dest or hunks[#hunks].buf_start
  end
  vim.api.nvim_win_set_cursor(0, { dest, 0 })
end

function M.discard()
  if not valid_buf() then
    return
  end
  local hunk = hunk_at(vim.api.nvim_win_get_cursor(0)[1], view.hunks)
  if not hunk then
    vim.notify("Kein Hunk unter dem Cursor", vim.log.levels.WARN, { title = "Git" })
    return
  end
  local choice = vim.fn.confirm("Hunk in " .. meta.rel .. " verwerfen?", "&Verwerfen\n&Abbrechen", 2)
  if choice ~= 1 then
    return
  end
  local ok, err = apply_reverse(hunk_patch(hunk))
  if not ok then
    vim.notify("Verwerfen fehlgeschlagen: " .. (err ~= "" and err or "unbekannt"), vim.log.levels.ERROR, {
      title = "Git",
    })
    return
  end
  reload_file()
  if render({ silent_empty = true }) then
    vim.notify("Hunk verworfen", vim.log.levels.INFO, { title = "Git" })
  else
    vim.notify("Hunk verworfen — keine weiteren Änderungen", vim.log.levels.INFO, { title = "Git" })
  end
end

local function map_buf()
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = desc })
  end
  map("q", M.close, "Diff schließen")
  map("<Esc>", M.close, "Diff schließen")
  map("e", M.goto_file, "Zur Datei springen")
  map("<CR>", M.goto_file, "Zur Datei springen")
  map("d", M.discard, "Hunk verwerfen")
  map("n", function()
    M.next_hunk(1)
  end, "Nächster Hunk")
  map("p", function()
    M.next_hunk(-1)
  end, "Vorheriger Hunk")
  map("]c", function()
    M.next_hunk(1)
  end, "Nächster Hunk")
  map("[c", function()
    M.next_hunk(-1)
  end, "Vorheriger Hunk")
  map("<Tab>", "za", "Hunk ein-/ausklappen")
  map("r", function()
    render()
  end, "Diff aktualisieren")
end

local function open_rev(rev, title)
  local file = current_file()
  if not file then
    vim.notify("Kein Dateipuffer", vim.log.levels.WARN, { title = "Git" })
    return
  end
  local root = git_root()
  if not root then
    vim.notify("Kein Git-Repository", vim.log.levels.WARN, { title = "Git" })
    return
  end
  if vim.bo.buftype == "" and vim.bo.modified then
    pcall(vim.cmd.write)
  end
  local file_lnum = vim.api.nvim_win_get_cursor(0)[1]
  meta.file = file
  meta.root = root
  meta.rel = relpath(file, root)
  meta.rev = rev
  ensure_window(title or ("Diff · " .. meta.rel))
  map_buf()
  render({ file_lnum = file_lnum })
end

function M.open_head()
  open_rev("HEAD", "Datei-Diff vs HEAD")
end

function M.open_base()
  local sha, ref = require("colejj.git.diffview").base_rev()
  if not sha then
    vim.notify("Kein Basis-Branch gefunden (develop, origin/main, origin/master, main, master).", vim.log.levels.WARN, {
      title = "Git",
    })
    return
  end
  open_rev(sha, "Datei-Diff vs " .. (ref or sha:sub(1, 8)))
end

return M
