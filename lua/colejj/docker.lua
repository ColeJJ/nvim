local M = {}

local prev_win
local float_win
local float_buf

local COMPOSE_NAMES = {
  "compose.yaml",
  "compose.yml",
  "docker-compose.yaml",
  "docker-compose.yml",
}

local GLOB_PATTERNS = {
  "/**/docker-compose*.yml",
  "/**/docker-compose*.yaml",
  "/**/compose.yml",
  "/**/compose.yaml",
  "/**/compose.*.yml",
  "/**/compose.*.yaml",
}

local SKIP = {
  "/node_modules/",
  "/target/",
  "/.git/",
  "/dist/",
  "/vendor/",
  "/.devcontainer/",
  "override.template",
}

local function is_standard_compose_name(name)
  name = (name or ""):lower()
  for _, candidate in ipairs(COMPOSE_NAMES) do
    if name == candidate then
      return true
    end
  end
  return false
end

local function is_compose_filename(path)
  local name = vim.fn.fnamemodify(path or "", ":t"):lower()
  if is_standard_compose_name(name) then
    return true
  end
  return name:find("compose.*%.ya?ml$") ~= nil
end

local function skipped(path)
  for _, needle in ipairs(SKIP) do
    if path:find(needle, 1, true) then
      return true
    end
  end
  return false
end

local function relpath(path, root)
  root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  path = vim.fn.fnamemodify(path, ":p")
  if path:sub(1, #root + 1) == root .. "/" then
    return path:sub(#root + 2)
  end
  return path
end

local function yaml_has_services(bufnr)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 120, false)) do
    if line:match("^services%s*:") then
      return true
    end
  end
  return false
end

local function common_dir_prefix(rels)
  if #rels == 0 then
    return ""
  end
  local prefix = rels[1]
  for i = 2, #rels do
    local s = rels[i]
    local n = math.min(#prefix, #s)
    local j = 0
    while j < n and prefix:byte(j + 1) == s:byte(j + 1) do
      j = j + 1
    end
    prefix = prefix:sub(1, j)
  end
  local dir = prefix:match("^(.*)/")
  return dir and (dir .. "/") or ""
end

local function pretty_label(rel, prefix)
  local short = rel
  if prefix ~= "" and rel:sub(1, #prefix) == prefix then
    short = rel:sub(#prefix + 1)
  end
  local file = vim.fn.fnamemodify(short, ":t")
  local dir = vim.fn.fnamemodify(short, ":h")
  if is_standard_compose_name(file) then
    if dir ~= "." then
      return dir
    end
    return prefix:match("([^/]+)/$") or file
  end
  if dir == "." then
    return file
  end
  return dir .. "/" .. file
end

local function collect_from_git(root)
  local result = vim.system({
    "git",
    "-C",
    root,
    "ls-files",
    "-z",
    "*compose*.yml",
    "*compose*.yaml",
  }, { text = true, timeout = 800 }):wait()
  if result.code ~= 0 or not result.stdout or result.stdout == "" then
    return {}
  end
  local files = {}
  for path in vim.gsplit(result.stdout, "\0", { plain = true }) do
    if path ~= "" then
      files[#files + 1] = vim.fn.fnamemodify(root .. "/" .. path, ":p")
    end
  end
  return files
end

local function collect_from_glob(root)
  local seen = {}
  local files = {}
  for _, pat in ipairs(GLOB_PATTERNS) do
    for _, path in ipairs(vim.fn.glob(root .. pat, false, true)) do
      path = vim.fn.fnamemodify(path, ":p")
      if not seen[path] then
        seen[path] = true
        files[#files + 1] = path
      end
    end
  end
  return files
end

function M.list_compose_files()
  local root = require("colejj.project").project_root()
  local raw = collect_from_git(root)
  if #raw == 0 then
    raw = collect_from_glob(root)
  end
  local files = {}
  local rels = {}
  for _, path in ipairs(raw) do
    if not skipped(path) and is_compose_filename(path) then
      files[#files + 1] = path
      rels[#rels + 1] = relpath(path, root)
    end
  end
  local prefix = common_dir_prefix(rels)
  local items = {}
  for i, path in ipairs(files) do
    items[#items + 1] = {
      path = path,
      rel = rels[i],
      dir = vim.fn.fnamemodify(path, ":h"),
      name = pretty_label(rels[i], prefix),
      project = vim.fn.fnamemodify(path, ":h:t"):lower():gsub("[^a-z0-9_-]", "-"),
    }
  end
  table.sort(items, function(a, b)
    return a.name < b.name
  end)
  return items
end

function M.compose_file()
  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file ~= "" and (is_compose_filename(file) or yaml_has_services(bufnr)) then
    return vim.fn.fnamemodify(file, ":p")
  end
end

local function config_file()
  return vim.fn.stdpath("config") .. "/lazydocker.yml"
end

--- LazyDocker hat kein `-ucf`; es liest `config.yml` aus `CONFIG_DIR`.
local function config_dir()
  local src = config_file()
  if vim.uv.fs_stat(src) == nil then
    vim.notify("lazydocker.yml fehlt unter " .. src, vim.log.levels.WARN, { title = "Docker" })
  end
  local dir = vim.fn.stdpath("cache") .. "/colejj-lazydocker"
  vim.fn.mkdir(dir, "p")
  local link = dir .. "/config.yml"
  local target = vim.uv.fs_readlink(link)
  if target ~= src then
    if target or vim.uv.fs_stat(link) then
      vim.uv.fs_unlink(link)
    end
    vim.uv.fs_symlink(src, link)
  end
  return dir
end

local function close_float()
  if float_win and vim.api.nvim_win_is_valid(float_win) then
    pcall(vim.api.nvim_win_close, float_win, true)
  end
  if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
    pcall(vim.api.nvim_buf_delete, float_buf, { force = true })
  end
  float_win, float_buf = nil, nil
end

local function open_float()
  local scale = vim.g.lazygit_floating_window_scaling_factor or 0.9
  if type(scale) == "table" then
    scale = scale[false] or 0.9
  end
  local height = math.ceil(vim.o.lines * scale) - 1
  local width = math.ceil(vim.o.columns * scale)
  local row = math.ceil((vim.o.lines - height) / 2)
  local col = math.ceil((vim.o.columns - width) / 2)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    style = "minimal",
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = vim.g.lazygit_floating_window_border_chars or "rounded",
  })
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "lazydocker"
  vim.wo[win].cursorcolumn = false
  vim.wo[win].signcolumn = "no"
  vim.api.nvim_set_hl(0, "LazyGitBorder", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "LazyGitFloat", { link = "Normal", default = true })
  vim.wo[win].winhl = "FloatBorder:LazyGitBorder,NormalFloat:LazyGitFloat"
  vim.wo[win].winblend = vim.g.lazygit_floating_window_winblend or 0
  return win, buf
end

local function compose_cmd(item, args)
  local cmd = { "docker", "compose", "-f", item.path, "-p", item.project }
  vim.list_extend(cmd, args)
  vim.notify(table.concat(args, " ") .. ": " .. item.name, vim.log.levels.INFO, { title = "Docker" })
  vim.system(cmd, { cwd = item.dir, text = true, env = { COMPOSE_PROJECT_NAME = item.project } }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        vim.notify(item.name .. " · " .. table.concat(args, " ") .. " ok", vim.log.levels.INFO, { title = "Docker" })
      else
        local err = vim.trim(result.stderr or result.stdout or "")
        vim.notify(err ~= "" and err or "Compose fehlgeschlagen", vim.log.levels.ERROR, { title = "Docker" })
      end
    end)
  end)
end

function M.start_lazydocker(file, project)
  if vim.fn.executable("lazydocker") ~= 1 then
    vim.notify("lazydocker nicht gefunden. Homebrew: brew install lazydocker", vim.log.levels.ERROR, {
      title = "Docker",
    })
    return
  end

  close_float()
  prev_win = vim.api.nvim_get_current_win()
  float_win, float_buf = open_float()
  local cwd = file and vim.fn.fnamemodify(file, ":h") or require("colejj.project").project_root()
  project = project or (file and vim.fn.fnamemodify(file, ":h:t"):lower():gsub("[^a-z0-9_-]", "-")) or nil
  local cmd = { "lazydocker" }
  -- Kein `-f`: LazyDocker matched sonst laufende Stacks nur über Service-Namen.
  -- `-p` + CWD der Compose-Datei hält Projekt und `up`/`down` am gewählten Ordner.
  local env = { CONFIG_DIR = config_dir() }
  if project and project ~= "" then
    cmd = { "lazydocker", "-p", project }
    env.COMPOSE_PROJECT_NAME = project
  end

  vim.api.nvim_create_autocmd("TermOpen", {
    buffer = float_buf,
    once = true,
    callback = function()
      if float_win and vim.api.nvim_win_is_valid(float_win) then
        vim.api.nvim_set_current_win(float_win)
      end
      vim.cmd("startinsert!")
    end,
  })
  -- Falls man doch im Neovim-Normalmodus landet: i oder Esc schickt die Tasten wieder an LazyDocker.
  vim.keymap.set("n", "i", "i", { buffer = float_buf, silent = true })
  vim.keymap.set("n", "<Esc>", "i", { buffer = float_buf, silent = true, desc = "Zurück zu LazyDocker" })

  vim.fn.jobstart(cmd, {
    term = true,
    cwd = cwd,
    env = env,
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 and code ~= 130 then
          vim.notify("lazydocker beendet mit Code " .. tostring(code), vim.log.levels.WARN, { title = "Docker" })
        end
        close_float()
        if prev_win and vim.api.nvim_win_is_valid(prev_win) then
          vim.api.nvim_set_current_win(prev_win)
        end
        prev_win = nil
      end)
    end,
  })
  vim.schedule(function()
    if float_win and vim.api.nvim_win_is_valid(float_win) then
      vim.api.nvim_set_current_win(float_win)
      vim.cmd("startinsert!")
    end
  end)
end

local function pick_compose(items)
  local current = M.compose_file()
  local default_idx = 1
  for i, item in ipairs(items) do
    if current and item.path == current then
      default_idx = i
      break
    end
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")

  local displayer = entry_display.create({
    separator = "  ",
    items = {
      { remaining = true },
    },
  })

  pickers
    .new({}, {
      prompt_title = "Docker Compose  ·  Enter LazyDocker  ·  u up  ·  d down",
      default_selection_index = default_idx,
      layout_strategy = "vertical",
      layout_config = {
        width = 0.45,
        height = 0.7,
        preview_height = 0.45,
        prompt_position = "bottom",
      },
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          return {
            value = item,
            filename = item.path,
            ordinal = item.name .. " " .. item.rel,
            display = function()
              return displayer({
                { item.name, "Directory" },
              })
            end,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.file_previewer({}),
      attach_mappings = function(prompt_bufnr, map)
        local function selected()
          local entry = action_state.get_selected_entry()
          return entry and entry.value
        end
        actions.select_default:replace(function()
          local item = selected()
          local path = item and item.path
          local project = item and item.project
          actions.close(prompt_bufnr)
          -- Telescope setzt nach dem Schließen Normalmodus; erst danach das Terminal öffnen.
          vim.schedule(function()
            if path then
              M.start_lazydocker(path, project)
            end
          end)
        end)
        local function bind(modes, lhs, fn)
          map(modes, lhs, function()
            local item = selected()
            actions.close(prompt_bufnr)
            if item then
              fn(item)
            end
          end)
        end
        -- `u`/`d` nur im Normalmodus, sonst stört das die Filterzeile.
        bind("n", "u", function(item)
          compose_cmd(item, { "up", "-d" })
        end)
        bind("n", "d", function(item)
          compose_cmd(item, { "down" })
        end)
        return true
      end,
    })
    :find()
end

function M.open()
  local items = M.list_compose_files()
  if #items == 0 then
    vim.notify("Keine Compose-Dateien im Projekt. LazyDocker zeigt nur Container.", vim.log.levels.WARN, {
      title = "Docker",
    })
    M.start_lazydocker(nil)
    return
  end
  pick_compose(items)
end

return M
