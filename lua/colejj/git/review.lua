-- GitLab-MR-Review in Neovim (SPC g m): Picker, Übersicht, Diffview, Kommentar, Approve.

local M = {}

local TITLE = "GitLab"
local ns = vim.api.nvim_create_namespace("colejj-mr")

local session = {
  ctx = nil,
  mr = nil,
  threads = {},
}

local function gitlab()
  return require("colejj.git.gitlab")
end

local function names(list)
  if type(list) ~= "table" or #list == 0 then
    return "—"
  end
  local out = {}
  for _, item in ipairs(list) do
    out[#out + 1] = item.username or item.name or "?"
  end
  return table.concat(out, ", ")
end

local function yn(flag)
  return flag and "ja" or "nein"
end

local function date(iso)
  if not iso or iso == "" then
    return "—"
  end
  return (iso:gsub("T", " "):gsub("Z$", ""):sub(1, 19))
end

local function pipeline_label(mr)
  local pipe = mr.head_pipeline or mr.pipeline
  if not pipe then
    return "—"
  end
  local status = pipe.status or "?"
  local src = pipe.source or ""
  if src ~= "" then
    return status .. " (" .. src .. ")"
  end
  return status
end

local function compose(title, on_submit)
  vim.cmd("botright 12split")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.wo.winbar = "%#Title#" .. title .. "%*  C-s senden  q abbrechen"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
  vim.cmd("startinsert")
  local function close()
    local win = vim.api.nvim_get_current_win()
    if #vim.api.nvim_list_wins() > 1 then
      vim.api.nvim_win_close(win, true)
    else
      vim.cmd("bdelete!")
    end
  end
  local function submit()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local body = vim.trim(table.concat(lines, "\n"))
    close()
    if body == "" then
      vim.notify("Leerer Kommentar", vim.log.levels.WARN, { title = TITLE })
      return
    end
    on_submit(body)
  end
  local opts = { buffer = buf, silent = true }
  vim.keymap.set("n", "q", close, vim.tbl_extend("force", opts, { desc = "Abbrechen" }))
  vim.keymap.set({ "n", "i" }, "<C-s>", submit, vim.tbl_extend("force", opts, { desc = "Senden" }))
end

local function close_win()
  local win = vim.api.nvim_get_current_win()
  if #vim.api.nvim_list_wins() > 1 then
    vim.api.nvim_win_close(win, true)
  else
    vim.cmd("bdelete!")
  end
end

local function existing_win(bufname)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf) == bufname then
      return win, buf
    end
  end
end

local function thread_at(lnum)
  for _, thread in ipairs(session.threads) do
    if lnum >= thread.start and lnum <= thread.stop then
      return thread
    end
  end
end

local function render_lines(mr, discussions, approvals)
  local approved = {}
  if approvals and approvals.approved_by then
    for _, row in ipairs(approvals.approved_by) do
      local user = row.user or row
      approved[#approved + 1] = user.username or user.name
    end
  end
  local req = approvals and (approvals.approvals_required or approvals.approvals_needed)
  local left = approvals and approvals.approvals_left
  local appr = "—"
  if req or #approved > 0 then
    appr = string.format(
      "%s  (%s nötig, %s offen)",
      #approved > 0 and table.concat(approved, ", ") or "keine",
      tostring(req or "—"),
      tostring(left or "—")
    )
  end

  local lines = {
    "MR:           !" .. tostring(mr.iid) .. (mr.draft and "  [Draft]" or ""),
    "Titel:        " .. (mr.title or ""),
    "Status:       " .. (mr.state or "—") .. "   Merge: " .. (mr.detailed_merge_status or mr.merge_status or "—"),
    "Autor:        " .. ((mr.author and (mr.author.username or mr.author.name)) or "—"),
    "Assignees:    " .. names(mr.assignees),
    "Reviewer:     " .. names(mr.reviewers),
    "Quelle:       " .. (mr.source_branch or "—"),
    "Ziel:         " .. (mr.target_branch or "—"),
    "Pipeline:     " .. pipeline_label(mr),
    "Konflikte:    " .. yn(mr.has_conflicts),
    "Approvals:    " .. appr,
    "Aktualisiert: " .. date(mr.updated_at),
    "URL:          " .. (mr.web_url or ""),
    "",
  }
  local desc = vim.trim(mr.description or "")
  if desc ~= "" then
    vim.list_extend(lines, vim.split(desc, "\n", { plain = true }))
  else
    lines[#lines + 1] = "(keine Beschreibung)"
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Diskussionen"
  lines[#lines + 1] = "────────────"

  local threads = {}
  if type(discussions) == "table" then
    for _, disc in ipairs(discussions) do
      local notes = disc.notes or {}
      if #notes > 0 then
        local start = #lines + 1
        local first = notes[1]
        local pos = first.position
        local loc = ""
        if pos and (pos.new_path or pos.old_path) then
          loc = "  "
            .. (pos.new_path or pos.old_path)
            .. ":"
            .. tostring(pos.new_line or pos.old_line or "")
        end
        local mark = first.resolvable and (first.resolved and " [gelöst]" or " [offen]") or ""
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format(
          "· %s  %s%s%s",
          first.author and (first.author.username or "?") or "?",
          date(first.created_at),
          mark,
          loc
        )
        for _, note in ipairs(notes) do
          local prefix = note.system and "  · " or "    "
          local body = vim.split(note.body or "", "\n", { plain = true })
          if #body == 0 then
            body = { "" }
          end
          lines[#lines + 1] = prefix .. (note.system and (body[1] or "") or body[1])
          for i = 2, #body do
            lines[#lines + 1] = "      " .. body[i]
          end
        end
        threads[#threads + 1] = {
          start = start,
          stop = #lines,
          id = disc.id,
          pos = pos,
        }
      end
    end
  end
  if #threads == 0 then
    lines[#lines + 1] = "(noch keine Diskussionen)"
  end
  return lines, threads
end

local function fill(buf, lines, title)
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].modified = false
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    vim.wo[win].winbar = "%#Title#"
      .. title
      .. "%*  d Diff  c Kommentar  R Antwort  e Datei  a/u Approve  b Browser  r Neu  q"
  end
end

function M.diff(mr, ctx)
  ctx = ctx or session.ctx
  mr = mr or session.mr
  if not ctx or not mr then
    vim.notify("Kein Merge Request offen", vim.log.levels.WARN, { title = TITLE })
    return
  end
  vim.notify("Hole MR-Ref …", vim.log.levels.INFO, { title = TITLE })
  local ok, err = gitlab().fetch_mr(ctx, mr)
  if not ok then
    vim.notify(err or "git fetch fehlgeschlagen", vim.log.levels.WARN, { title = TITLE })
  end
  local refs = mr.diff_refs or {}
  local base = refs.base_sha
  local head = refs.head_sha
  local range
  if gitlab().has_rev(ctx, base) and gitlab().has_rev(ctx, head) then
    range = base .. "..." .. head
  elseif gitlab().has_rev(ctx, "origin/mr-" .. mr.iid) and mr.target_branch then
    range = "origin/" .. mr.target_branch .. "...origin/mr-" .. mr.iid
  elseif mr.target_branch and mr.source_branch then
    range = "origin/" .. mr.target_branch .. "...origin/" .. mr.source_branch
  end
  if not range then
    vim.notify("Diff-Refs fehlen. Branches einmal pushen/fetchen.", vim.log.levels.ERROR, { title = TITLE })
    return
  end
  require("colejj.git.diffview").open("DiffviewOpen " .. range)
end

function M.browse(mr)
  mr = mr or session.mr
  if not mr or not mr.web_url then
    vim.notify("Keine MR-URL", vim.log.levels.WARN, { title = TITLE })
    return
  end
  vim.ui.open(mr.web_url)
end

local function reload_overview()
  if not session.ctx or not session.mr then
    return
  end
  M.open(session.mr.iid, session.ctx)
end

function M.approve(unapprove)
  if not session.ctx or not session.mr then
    return
  end
  local fn = unapprove and gitlab().unapprove or gitlab().approve
  local _, err = fn(session.ctx, session.mr.iid)
  if err then
    vim.notify(err, vim.log.levels.ERROR, { title = TITLE })
    return
  end
  vim.notify(unapprove and "Approve entfernt" or "Approved", vim.log.levels.INFO, { title = TITLE })
  reload_overview()
end

function M.comment()
  if not session.ctx or not session.mr then
    return
  end
  local ctx, iid = session.ctx, session.mr.iid
  compose("MR-Kommentar !" .. iid, function(body)
    local _, err = gitlab().note(ctx, iid, body)
    if err then
      vim.notify(err, vim.log.levels.ERROR, { title = TITLE })
      return
    end
    vim.notify("Kommentar gesendet", vim.log.levels.INFO, { title = TITLE })
    reload_overview()
  end)
end

function M.reply()
  if not session.ctx or not session.mr then
    return
  end
  local thread = thread_at(vim.api.nvim_win_get_cursor(0)[1])
  if not thread then
    vim.notify("Cursor auf eine Diskussion setzen", vim.log.levels.WARN, { title = TITLE })
    return
  end
  local ctx, iid, id = session.ctx, session.mr.iid, thread.id
  compose("Antwort !" .. iid, function(body)
    local _, err = gitlab().reply(ctx, iid, id, body)
    if err then
      vim.notify(err, vim.log.levels.ERROR, { title = TITLE })
      return
    end
    vim.notify("Antwort gesendet", vim.log.levels.INFO, { title = TITLE })
    reload_overview()
  end)
end

function M.goto_file()
  local thread = thread_at(vim.api.nvim_win_get_cursor(0)[1])
  if not thread or not thread.pos then
    vim.notify("Keine Dateiposition in dieser Diskussion", vim.log.levels.INFO, { title = TITLE })
    return
  end
  local rel = thread.pos.new_path or thread.pos.old_path
  local lnum = thread.pos.new_line or thread.pos.old_line or 1
  if not rel or not session.ctx then
    return
  end
  local path = session.ctx.root .. "/" .. rel
  if vim.fn.filereadable(path) ~= 1 then
    vim.notify("Datei nicht im Arbeitsbaum: " .. rel, vim.log.levels.WARN, { title = TITLE })
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
  pcall(vim.api.nvim_win_set_cursor, 0, { math.max(tonumber(lnum) or 1, 1), 0 })
  vim.cmd.normal({ "zvzz", bang = true })
end

local function map_overview(buf)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = desc })
  end
  map("q", close_win, "Schließen")
  map("<Esc>", close_win, "Schließen")
  map("d", function()
    M.diff()
  end, "MR-Diff")
  map("<CR>", function()
    M.diff()
  end, "MR-Diff")
  map("b", function()
    M.browse()
  end, "Im Browser öffnen")
  map("c", M.comment, "Allgemeiner Kommentar")
  map("R", M.reply, "Diskussion beantworten")
  map("e", M.goto_file, "Zur kommentierten Datei")
  map("gf", M.goto_file, "Zur kommentierten Datei")
  map("a", function()
    M.approve(false)
  end, "Approve")
  map("u", function()
    M.approve(true)
  end, "Approve entfernen")
  map("r", reload_overview, "Aktualisieren")
end

function M.open(iid, ctx)
  local ctx_err
  if type(ctx) ~= "table" then
    ctx = session.ctx
  end
  if type(ctx) ~= "table" then
    ctx, ctx_err = gitlab().context()
  end
  if type(ctx) ~= "table" then
    vim.notify(ctx_err or "Kein GitLab-Kontext", vim.log.levels.ERROR, { title = TITLE })
    return
  end
  iid = tonumber(iid)
  if not iid then
    vim.notify("Keine MR-IID", vim.log.levels.WARN, { title = TITLE })
    return
  end
  vim.notify("Lade !" .. iid .. " …", vim.log.levels.INFO, { title = TITLE })
  local mr, err = gitlab().get_mr(ctx, iid)
  if not mr then
    vim.notify(err or "MR nicht gefunden", vim.log.levels.ERROR, { title = TITLE })
    return
  end
  local discussions = gitlab().discussions(ctx, iid)
  if type(discussions) ~= "table" then
    discussions = {}
  end
  local approvals = gitlab().approvals(ctx, iid)
  if type(approvals) ~= "table" then
    approvals = {}
  end
  session.ctx = ctx
  session.mr = mr
  local lines, threads = render_lines(mr, discussions, approvals)
  session.threads = threads
  local bufname = "colejj-mr://!" .. iid
  local title = "MR !" .. iid
  local win, buf = existing_win(bufname)
  if win then
    vim.api.nvim_set_current_win(win)
    fill(buf, lines, title)
    return
  end
  local leftover = vim.fn.bufnr(bufname)
  if leftover ~= -1 then
    pcall(vim.api.nvim_buf_delete, leftover, { force = true })
  end
  vim.cmd("botright vsplit")
  buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_win_set_buf(0, buf)
  pcall(vim.api.nvim_buf_set_name, buf, bufname)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = true
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.wo.wrap = false
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  map_overview(buf)
  fill(buf, lines, title)
  pcall(vim.api.nvim_win_set_cursor, 0, { 1, 0 })
end

local function pick_list(ctx, mrs)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")
  local entry_display = require("telescope.pickers.entry_display")

  local displayer = entry_display.create({
    separator = "  ",
    items = {
      { width = 7 },
      { width = 6 },
      { remaining = true },
    },
  })

  pickers
    .new({}, {
      prompt_title = "Merge Requests  ·  Enter Übersicht  ·  d Diff  ·  b Browser",
      layout_strategy = "vertical",
      layout_config = {
        width = 0.7,
        height = 0.85,
        preview_height = 0.45,
        prompt_position = "bottom",
      },
      finder = finders.new_table({
        results = mrs,
        entry_maker = function(mr)
          local draft = mr.draft and "draft" or (mr.state or "")
          return {
            value = mr,
            ordinal = table.concat({
              tostring(mr.iid),
              mr.title or "",
              mr.source_branch or "",
              mr.author and mr.author.username or "",
            }, " "),
            display = function()
              return displayer({
                { "!" .. tostring(mr.iid), "Number" },
                { draft, "Comment" },
                { mr.title or "", "Directory" },
              })
            end,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = previewers.new_buffer_previewer({
        define_preview = function(self, entry)
          local mr = entry.value
          local lines = {
            mr.title or "",
            "",
            (mr.author and mr.author.username or "?")
              .. "  "
              .. (mr.source_branch or "")
              .. " → "
              .. (mr.target_branch or ""),
            "Pipeline: " .. pipeline_label(mr),
            "",
          }
          vim.list_extend(lines, vim.split(mr.description or "(keine Beschreibung)", "\n", { plain = true }))
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.bo[self.state.bufnr].filetype = "markdown"
        end,
      }),
      attach_mappings = function(prompt_bufnr, map)
        local function selected()
          local entry = action_state.get_selected_entry()
          return entry and entry.value
        end
        actions.select_default:replace(function()
          local mr = selected()
          actions.close(prompt_bufnr)
          vim.schedule(function()
            if mr then
              M.open(mr.iid, ctx)
            end
          end)
        end)
        local function bind(lhs, fn)
          map("n", lhs, function()
            local mr = selected()
            actions.close(prompt_bufnr)
            if mr then
              fn(mr)
            end
          end)
        end
        bind("d", function(mr)
          session.ctx = ctx
          session.mr = mr
          M.diff(mr, ctx)
        end)
        bind("b", function(mr)
          M.browse(mr)
        end)
        return true
      end,
    })
    :find()
end

function M.pick()
  local ctx, err = gitlab().context()
  if not ctx then
    vim.notify(err or "Kein GitLab-Kontext", vim.log.levels.ERROR, { title = TITLE })
    return
  end
  vim.notify("Lade Merge Requests …", vim.log.levels.INFO, { title = TITLE })
  vim.schedule(function()
    local mrs, list_err = gitlab().list_mrs(ctx)
    if not mrs then
      vim.notify(list_err or "MRs konnten nicht geladen werden", vim.log.levels.ERROR, { title = TITLE })
      return
    end
    if #mrs == 0 then
      vim.notify("Keine offenen Merge Requests in " .. ctx.path, vim.log.levels.INFO, { title = TITLE })
      return
    end
    pick_list(ctx, mrs)
  end)
end

function M.setup()
  vim.keymap.set("n", "<leader>gm", M.pick, { desc = "Merge Requests" })
  vim.api.nvim_create_user_command("GitLabMR", function(opts)
    local arg = vim.trim(opts.args or "")
    if arg == "" then
      M.pick()
      return
    end
    local iid = tonumber(arg:gsub("^!", ""))
    if not iid then
      vim.notify("Nutzung: :GitLabMR [IID]", vim.log.levels.WARN, { title = TITLE })
      return
    end
    M.open(iid)
  end, { nargs = "?", desc = "GitLab Merge Requests" })
end

return M
