-- Commit-Details für SPC f c: Enter öffnet einen vertikalen Buffer
-- (Nachricht, Autor, Datum, Branches, Tags, Statistik, Diff) statt Checkout.

local M = {}

local function git_root()
  return require("colejj.project").git_root()
end

local function git_run(root, args, opts)
  opts = opts or {}
  local cmd = { "git", "-C", root }
  vim.list_extend(cmd, args)
  local result = vim.system(cmd, {
    text = true,
    timeout = opts.timeout or 8000,
  }):wait()
  if result.code ~= 0 then
    return nil, vim.trim(result.stderr or result.stdout or "git fehlgeschlagen")
  end
  return result.stdout or ""
end

local function git_trim(root, args, opts)
  local text, err = git_run(root, args, opts)
  if not text then
    return nil, err
  end
  return vim.trim(text)
end

local function git_list(root, args, opts)
  local text, err = git_run(root, args, opts)
  if not text then
    return nil, err
  end
  local lines = {}
  for line in vim.gsplit(text, "\n", { trimempty = true }) do
    line = vim.trim(line)
    if line ~= "" then
      lines[#lines + 1] = line
    end
  end
  return lines
end

local function csv(items, empty)
  if not items or #items == 0 then
    return empty or "—"
  end
  local limit = 40
  if #items <= limit then
    return table.concat(items, ", ")
  end
  local head = {}
  for i = 1, limit do
    head[i] = items[i]
  end
  return table.concat(head, ", ") .. string.format("  … +%d", #items - limit)
end

local function split_body(text)
  if not text or text == "" then
    return {}
  end
  text = text:gsub("\n$", "")
  if text == "" then
    return {}
  end
  return vim.split(text, "\n", { plain = true })
end

local function pad_msg(lines)
  local out = {}
  for _, line in ipairs(lines) do
    if line == "" then
      out[#out + 1] = ""
    else
      out[#out + 1] = "    " .. line
    end
  end
  return out
end

local function collect(hash)
  local root = git_root()
  if not root then
    return nil, "Kein Git-Repository"
  end
  local full, err = git_trim(root, { "rev-parse", "--verify", hash })
  if not full then
    return nil, err or "Commit nicht gefunden"
  end

  local meta, meta_err = git_trim(root, {
    "show",
    "-s",
    "--date=iso-local",
    "--format=%H%x1f%h%x1f%an%x1f%ae%x1f%ad%x1f%cn%x1f%ce%x1f%cd%x1f%P%x1f%s%x1f%D",
    full,
  })
  if not meta then
    return nil, meta_err
  end
  local f = vim.split(meta, "\x1f", { plain = true })
  local subject = f[10] or ""
  local body = git_trim(root, { "show", "-s", "--format=%b", full }) or ""
  local stats = git_run(root, { "show", "--stat", "--format=", "--no-patch", "--no-color", full }) or ""
  local diff = git_run(root, { "show", "--pretty=format:", "--no-color", "-M", full }) or ""
  local heads = git_list(root, {
    "for-each-ref",
    "--format=%(refname:short)",
    "--contains",
    full,
    "refs/heads",
  }, { timeout = 8000 }) or {}
  local remotes = git_list(root, {
    "for-each-ref",
    "--format=%(refname:short)",
    "--contains",
    full,
    "refs/remotes",
  }, { timeout = 8000 }) or {}
  local tags = git_list(root, {
    "for-each-ref",
    "--format=%(refname:short)",
    "--contains",
    full,
    "refs/tags",
  }, { timeout = 8000 }) or {}
  local head_sha = git_trim(root, { "rev-parse", "HEAD" })
  local head_name = git_trim(root, { "rev-parse", "--abbrev-ref", "HEAD" })

  return {
    root = root,
    full = f[1] or full,
    short = f[2] or full:sub(1, 7),
    author = f[3] or "",
    email = f[4] or "",
    author_date = f[5] or "",
    committer = f[6] or "",
    committer_email = f[7] or "",
    commit_date = f[8] or "",
    parents = f[9] or "",
    subject = subject,
    refs = f[11] or "",
    body = body,
    stats = stats,
    diff = diff,
    heads = heads,
    remotes = remotes,
    tags = tags,
    is_head = head_sha == full,
    head_name = head_name,
  }
end

local function render_lines(info)
  local lines = {
    "Commit:       " .. info.full,
    "Kurz:         " .. info.short,
    "Autor:        " .. info.author .. "  <" .. info.email .. ">",
    "Datum:        " .. info.author_date,
    "Committer:    " .. info.committer .. "  <" .. info.committer_email .. ">",
    "Committed:    " .. info.commit_date,
  }
  if info.parents ~= "" then
    lines[#lines + 1] = "Eltern:       " .. info.parents
  end
  if info.is_head then
    lines[#lines + 1] = "HEAD:         ja (" .. (info.head_name or "HEAD") .. ")"
  end
  local pointed = vim.trim(info.refs or "")
  if pointed ~= "" then
    lines[#lines + 1] = "Zeigt auf:    " .. pointed
  end
  lines[#lines + 1] = "Branches:     " .. csv(info.heads)
  lines[#lines + 1] = "Remotes:      " .. csv(info.remotes)
  lines[#lines + 1] = "Tags:         " .. csv(info.tags)
  lines[#lines + 1] = ""
  vim.list_extend(lines, pad_msg({ info.subject }))
  local body_lines = split_body(info.body)
  if #body_lines > 0 then
    lines[#lines + 1] = ""
    vim.list_extend(lines, pad_msg(body_lines))
  end
  local stats_lines = split_body(info.stats)
  if #stats_lines > 0 then
    lines[#lines + 1] = ""
    vim.list_extend(lines, stats_lines)
  end
  local diff_lines = split_body(info.diff)
  if #diff_lines > 0 then
    if diff_lines[1] ~= "" then
      lines[#lines + 1] = ""
    end
    vim.list_extend(lines, diff_lines)
  end
  return lines
end

local function existing_win(bufname)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf) == bufname then
      return win, buf
    end
  end
end

local function close_win()
  local win = vim.api.nvim_get_current_win()
  if #vim.api.nvim_list_wins() > 1 then
    vim.api.nvim_win_close(win, true)
  else
    vim.cmd("bdelete!")
  end
end

local function map_buf(buf)
  local opts = { buffer = buf, silent = true }
  vim.keymap.set("n", "q", close_win, vim.tbl_extend("force", opts, { desc = "Commit schließen" }))
  vim.keymap.set("n", "<Esc>", close_win, vim.tbl_extend("force", opts, { desc = "Commit schließen" }))
end

local function fill(buf, lines, title)
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].modified = false
  local win = vim.api.nvim_get_current_win()
  vim.wo[win].winbar = "%#Title#" .. title .. "%*  q schließen"
end

function M.open(hash)
  hash = vim.trim(hash or "")
  if hash == "" then
    vim.notify("Kein Commit ausgewählt", vim.log.levels.WARN, { title = "Git" })
    return
  end
  local info, err = collect(hash)
  if not info then
    vim.notify(err or "Commit konnte nicht gelesen werden", vim.log.levels.ERROR, { title = "Git" })
    return
  end
  local bufname = "colejj-commit://" .. info.short
  local lines = render_lines(info)
  local title = "Commit · " .. info.short
  local win = existing_win(bufname)
  if win then
    vim.api.nvim_set_current_win(win)
    fill(vim.api.nvim_win_get_buf(win), lines, title)
    return
  end
  local leftover = vim.fn.bufnr(bufname)
  if leftover ~= -1 then
    pcall(vim.api.nvim_buf_delete, leftover, { force = true })
  end
  vim.cmd("botright vsplit")
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_win_set_buf(0, buf)
  pcall(vim.api.nvim_buf_set_name, buf, bufname)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = true
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "git"
  vim.wo.wrap = false
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.foldmethod = "syntax"
  vim.wo.foldlevel = 99
  map_buf(buf)
  fill(buf, lines, title)
  pcall(vim.api.nvim_win_set_cursor, 0, { 1, 0 })
end

function M.pick()
  local builtin = require("telescope.builtin")
  builtin.git_commits({
    prompt_title = "Git-Commits  ·  Enter Details  ·  c Checkout",
    attach_mappings = function(prompt_bufnr, map)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        local value = entry and entry.value
        actions.close(prompt_bufnr)
        vim.schedule(function()
          if value then
            M.open(value)
          end
        end)
      end)
      map("n", "c", actions.git_checkout)
      return true
    end,
  })
end

return M
