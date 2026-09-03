-- Inline-Blame wie Doom `SPC g B` / IntelliJ Annotate:
-- Hash, Autor, Datum links neben dem Code, nach Alter eingefärbt.

local M = {}

local ns = vim.api.nvim_create_namespace("colejj-git-blame")

local age_colors = {
  { 2, "#ff5555" },
  { 7, "#ff8c42" },
  { 14, "#ffd166" },
  { 30, "#c3e88d" },
  { 60, "#89ddff" },
  { 90, "#82aaff" },
  { 180, "#7e7fff" },
  { 360, "#b085f5" },
}

local very_old = "#6c6f93"
local uncommitted = "#e0e0e0"

local state = {}

local function age_color(days)
  for _, entry in ipairs(age_colors) do
    if days <= entry[1] then
      return entry[2]
    end
  end
  return very_old
end

local function hl_for(hex)
  local name = "ColejjBlame" .. hex:gsub("#", "")
  vim.api.nvim_set_hl(0, name, { fg = hex })
  return name
end

local function short_author(name)
  name = name or "?"
  if vim.fn.strdisplaywidth(name) > 15 then
    return vim.fn.strcharpart(name, 0, 14) .. "…"
  end
  return name
end

local function parse_porcelain(text)
  local data = {}
  local commits = {}
  local hash, final, author, epoch
  for line in vim.gsplit(text, "\n", { trimempty = false }) do
    local h, _, fin = line:match("^(%x+) (%d+) (%d+)")
    if h and #h >= 40 then
      hash = h
      final = tonumber(fin)
      local known = commits[hash]
      if known then
        author = known.author
        epoch = known.epoch
      else
        author, epoch = nil, nil
      end
    elseif line:match("^author ") and not line:match("^author%-") then
      author = line:sub(8)
    elseif line:match("^author%-time ") then
      epoch = tonumber(line:sub(13))
    elseif line:sub(1, 1) == "\t" and hash and final then
      if author then
        commits[hash] = { author = author, epoch = epoch }
      end
      local meta = commits[hash] or { author = author or "?", epoch = epoch }
      data[final] = {
        hash = hash:sub(1, 7),
        full = hash,
        author = meta.author,
        epoch = meta.epoch,
      }
      final = nil
    end
  end
  return data
end

local function apply(bufnr, data)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local now = os.time()
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for lnum = 1, line_count do
    local d = data[lnum]
    if d then
      local zeros = d.full:match("^0+$")
      local label
      local color
      if zeros then
        label = string.format("%-7s %-16s %-10s ", "•••••••", "(lokal)", "")
        color = uncommitted
      else
        local days = d.epoch and ((now - d.epoch) / 86400) or 99999
        color = age_color(days)
        local date = d.epoch and os.date("%Y-%m-%d", d.epoch) or ""
        label = string.format("%-7s %-16s %s ", d.hash, short_author(d.author), date)
      end
      vim.api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, 0, {
        virt_text = { { label, hl_for(color) } },
        virt_text_pos = "inline",
        hl_mode = "combine",
        right_gravity = false,
      })
    end
  end
end

local function set_keys(bufnr, enable)
  local opts = { buffer = bufnr, silent = true }
  if enable then
    vim.keymap.set("n", "<CR>", M.show_commit, vim.tbl_extend("force", opts, { desc = "Blame: Commit der Zeile" }))
    vim.keymap.set("n", "q", M.toggle, vim.tbl_extend("force", opts, { desc = "Blame aus" }))
  else
    pcall(vim.keymap.del, "n", "<CR>", { buffer = bufnr })
    pcall(vim.keymap.del, "n", "q", { buffer = bufnr })
  end
end

local function restore_origin(saved)
  if not saved then
    return
  end
  if saved.file ~= "" and vim.fn.filereadable(saved.file) == 1 then
    local current = vim.api.nvim_buf_get_name(0)
    if vim.fn.fnamemodify(current, ":p") ~= vim.fn.fnamemodify(saved.file, ":p") then
      vim.cmd.edit(vim.fn.fnameescape(saved.file))
    end
  end
  pcall(vim.fn.winrestview, saved.view)
  pcall(vim.api.nvim_win_set_cursor, 0, saved.pos)
  pcall(vim.cmd.normal, { "zv", bang = true })
end

function M.disable(bufnr, opts)
  opts = opts or {}
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local s = state[bufnr]
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  if s then
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.bo[bufnr].modifiable = s.modifiable
      vim.bo[bufnr].readonly = s.readonly
    end
    state[bufnr] = nil
  end
  set_keys(bufnr, false)
  if not opts.skip_restore and s then
    restore_origin(s.origin)
  end
end

function M.show_commit()
  local bufnr = vim.api.nvim_get_current_buf()
  local s = state[bufnr]
  if not s then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local d = s.data[lnum]
  if not d or d.full:match("^0+$") then
    vim.notify("Diese Zeile ist noch nicht committet", vim.log.levels.INFO, { title = "git blame" })
    return
  end
  local diff = require("colejj.git.diffview")
  if s.origin then
    diff.set_origin(s.origin)
  else
    diff.remember()
  end
  local ok = pcall(function()
    vim.cmd("DiffviewOpen " .. d.hash .. "^!")
  end)
  if ok then
    M.disable(bufnr, { skip_restore = true })
    return
  end
  vim.cmd("botright new")
  vim.fn.jobstart({ "git", "show", d.hash }, {
    stdout_buffered = true,
    cwd = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":h"),
    on_stdout = function(_, data)
      if data then
        vim.api.nvim_buf_set_lines(0, 0, -1, false, data)
      end
    end,
  })
  vim.bo.filetype = "git"
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
end

function M.enable()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == "" or vim.fn.filereadable(filename) ~= 1 then
    vim.notify("Kein dateibasierter Buffer", vim.log.levels.WARN, { title = "git blame" })
    return
  end
  local origin = require("colejj.git.diffview").snapshot()
  vim.notify("Inline-Blame lädt …", vim.log.levels.INFO, { title = "git blame" })
  vim.system({ "git", "blame", "--line-porcelain", "--", filename }, {
    cwd = vim.fn.fnamemodify(filename, ":h"),
    text = true,
  }, function(result)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      if result.code ~= 0 then
        vim.notify(result.stderr ~= "" and result.stderr or "Datei nicht in Git?", vim.log.levels.WARN, {
          title = "git blame",
        })
        return
      end
      local data = parse_porcelain(result.stdout)
      if vim.tbl_isempty(data) then
        vim.notify("Keine Blame-Daten", vim.log.levels.WARN, { title = "git blame" })
        return
      end
      state[bufnr] = {
        data = data,
        modifiable = vim.bo[bufnr].modifiable,
        readonly = vim.bo[bufnr].readonly,
        origin = origin,
      }
      apply(bufnr, data)
      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].readonly = true
      set_keys(bufnr, true)
      vim.notify("Inline-Blame AN — Enter: Commit, q / SPC g b: aus", vim.log.levels.INFO, { title = "git blame" })
    end)
  end)
end

function M.toggle()
  local bufnr = vim.api.nvim_get_current_buf()
  if state[bufnr] then
    M.disable(bufnr)
    vim.notify("Inline-Blame AUS", vim.log.levels.INFO, { title = "git blame" })
    return
  end
  M.enable()
end

function M.setup()
  vim.keymap.set("n", "<leader>gb", M.toggle, { desc = "Inline-Blame (Heatmap)" })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = vim.api.nvim_create_augroup("colejj-git-blame", { clear = true }),
    callback = function(event)
      if state[event.buf] then
        M.disable(event.buf, { skip_restore = true })
      end
    end,
  })
end

return M
