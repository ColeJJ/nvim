-- Speichern (Doom `SPC f s`, macOS ⌘S)
vim.keymap.set({ "n", "v" }, "<leader>fs", "<cmd>write<CR>", { desc = "Datei speichern" })
vim.keymap.set({ "n", "i", "v", "s" }, "<D-s>", "<cmd>write<CR>", { desc = "Datei speichern" })

-- Fenster
vim.keymap.set("n", "<leader><Tab>", "<C-w>w", { desc = "Nächstes Fenster" })
vim.keymap.set("n", "<leader>wh", "<C-w>h", { desc = "Fenster links" })
vim.keymap.set("n", "<leader>wj", "<C-w>j", { desc = "Fenster unten" })
vim.keymap.set("n", "<leader>wk", "<C-w>k", { desc = "Fenster oben" })
vim.keymap.set("n", "<leader>wl", "<C-w>l", { desc = "Fenster rechts" })
vim.keymap.set("n", "<leader>wq", "<C-w>q", { desc = "Fenster schließen" })
vim.keymap.set("n", "<leader>wv", "<C-w>v", { desc = "Fenster vertikal splitten" })
vim.keymap.set("n", "<leader>wV", "<C-w>s", { desc = "Fenster horizontal splitten" })

local function win_has(cmd)
  local cur = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. cmd)
  local other = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(cur)
  return other ~= cur
end

-- Teiler in Pfeilrichtung schieben (nicht nur aktuelles Fenster wachsen).
local function win_push(dir)
  if dir == "right" then
    if win_has("l") then
      vim.cmd("vertical resize +5")
    elseif win_has("h") then
      vim.cmd("vertical resize -5")
    end
  elseif dir == "left" then
    if win_has("h") then
      vim.cmd("vertical resize +5")
    elseif win_has("l") then
      vim.cmd("vertical resize -5")
    end
  elseif dir == "up" then
    if win_has("k") then
      vim.cmd("resize +3")
    elseif win_has("j") then
      vim.cmd("resize -3")
    end
  elseif dir == "down" then
    if win_has("j") then
      vim.cmd("resize +3")
    elseif win_has("k") then
      vim.cmd("resize -3")
    end
  end
end

local function win_key_dir(raw)
  local key = vim.fn.keytrans(raw)
  if key == "<Right>" or key == "<kRight>" then
    return "right"
  end
  if key == "<Left>" or key == "<kLeft>" then
    return "left"
  end
  if key == "<Up>" or key == "<kUp>" then
    return "up"
  end
  if key == "<Down>" or key == "<kDown>" then
    return "down"
  end
  if raw == "\27[C" or raw == "\27OC" then
    return "right"
  end
  if raw == "\27[D" or raw == "\27OD" then
    return "left"
  end
  if raw == "\27[A" or raw == "\27OA" then
    return "up"
  end
  if raw == "\27[B" or raw == "\27OB" then
    return "down"
  end
end

local function win_resize_repeat(dir)
  win_push(dir)
  vim.api.nvim_echo({ { " Fenstergröße  ←→↑↓  (Esc beendet)", "Question" } }, false, {})
  vim.cmd("redraw")
  while true do
    local ok, raw = pcall(vim.fn.getcharstr)
    if not ok or not raw or raw == "" then
      break
    end
    local next_dir = win_key_dir(raw)
    if not next_dir then
      if vim.fn.keytrans(raw) ~= "<Esc>" then
        vim.api.nvim_feedkeys(raw, "m", false)
      end
      break
    end
    win_push(next_dir)
    vim.cmd("redraw")
  end
  vim.api.nvim_echo({}, false, {})
end

vim.keymap.set("n", "<leader>w<Right>", function()
  win_resize_repeat("right")
end, { desc = "Fenster nach rechts schieben" })
vim.keymap.set("n", "<leader>w<Left>", function()
  win_resize_repeat("left")
end, { desc = "Fenster nach links schieben" })
vim.keymap.set("n", "<leader>w<Up>", function()
  win_resize_repeat("up")
end, { desc = "Fenster nach oben schieben" })
vim.keymap.set("n", "<leader>w<Down>", function()
  win_resize_repeat("down")
end, { desc = "Fenster nach unten schieben" })

-- Visuelle Auswahl als Suchtext für / und ?
local function search_with_selection(prefix)
  local text = vim.trim(require("colejj.utils").visual_selection():gsub("[\n\r]+", "\\n"))
  local typed = prefix
  if text ~= "" then
    typed = prefix .. vim.fn.escape(text, [=[\/.*$^~[]]=])
  end
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true) .. typed,
    "n",
    false
  )
end

vim.keymap.set("x", "/", function()
  search_with_selection("/")
end, { desc = "Suche mit Auswahl" })
vim.keymap.set("x", "?", function()
  search_with_selection("?")
end, { desc = "Rückwärtssuche mit Auswahl" })

vim.keymap.set("n", "<leader>oc", function()
  require("colejj.docker").open()
end, { desc = "Podman Compose / LazyDocker" })
vim.keymap.set("n", "<leader>oC", function()
  require("colejj.docker").open_all()
end, { desc = "LazyDocker (alle Container)" })
vim.keymap.set("n", "<leader>ob", function()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" or vim.bo.buftype ~= "" then
    vim.notify("Kein Dateipuffer", vim.log.levels.WARN)
    return
  end
  if vim.bo.modified then
    pcall(vim.cmd.write)
  end
  local ok, err = vim.ui.open(name)
  if not ok then
    vim.notify(tostring(err or "Öffnen fehlgeschlagen"), vim.log.levels.ERROR)
  end
end, { desc = "Im Standard-Browser öffnen" })
vim.api.nvim_create_user_command("LazyDocker", function()
  require("colejj.docker").open()
end, { desc = "LazyDocker öffnen" })

-- Bewegung / Yank
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Zeile nach unten" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Zeile nach oben" })
vim.keymap.set("n", "gj", "<C-d>zz")
vim.keymap.set("n", "gk", "<C-u>zz")
vim.keymap.set("x", "<leader>p", '"_dP', { desc = "Einfügen ohne Yank zu überschreiben" })
vim.keymap.set({ "n", "v" }, "<leader>D", '"_d', { desc = "Löschen ohne Yank" })
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y', { desc = "In System-Clipboard yanken" })
vim.keymap.set("n", "<leader>Y", '"+Y', { desc = "Zeile in System-Clipboard yanken" })
vim.keymap.set("n", "Q", "<nop>")

-- tmux
vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww ~/.config/tmux/tmux-sessionizer.sh<CR>")
vim.keymap.set("n", "<C-c>", "<cmd>silent !tmux neww ~/.config/tmux/tmux-cht.sh<CR>")

-- Ersetzen bleibt als <leader>R, damit <leader>r für Run frei ist
vim.keymap.set("n", "<leader>R", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {
  desc = "Wort unter Cursor ersetzen",
})
vim.keymap.set("x", "<leader>R", function()
  local text = vim.trim(require("colejj.utils").visual_selection():gsub("\n", "\\n"))
  if text == "" then
    return
  end
  local escaped = vim.fn.escape(text, [[/\.*$^~[]])
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
      .. ":%s/"
      .. escaped
      .. "/"
      .. escaped
      .. "/gI"
      .. vim.api.nvim_replace_termcodes("<Left><Left><Left>", true, false, true),
    "n",
    false
  )
end, { desc = "Auswahl ersetzen" })

vim.cmd("command! W :w")

-- Schwere Module erst beim ersten Aufruf laden.
vim.keymap.set("n", "<leader>gb", function()
  local blame = require("colejj.git.blame")
  blame.setup()
  blame.toggle()
end, { desc = "Inline-Blame (Heatmap)" })

vim.keymap.set("n", "<leader>gm", function()
  require("colejj.git.review").pick()
end, { desc = "Merge Requests" })

vim.api.nvim_create_user_command("TuicrMR", function(opts)
  require("colejj.git.tuicr").open(opts.args)
end, { nargs = "?", desc = "GitLab-MR in tuicr öffnen" })

vim.api.nvim_create_user_command("GitLabMR", function(opts)
  local review = require("colejj.git.review")
  local arg = vim.trim(opts.args or "")
  if arg == "" then
    review.pick()
    return
  end
  local iid = tonumber(arg:gsub("^!", ""))
  if not iid then
    vim.notify("Nutzung: :GitLabMR [IID]", vim.log.levels.WARN, { title = "GitLab" })
    return
  end
  review.open(iid)
end, { nargs = "?", desc = "GitLab Merge Requests" })

local function java_test()
  local test = require("colejj.java.test")
  test.setup()
  return test
end

vim.keymap.set("n", "<leader>rtt", function()
  java_test().run_at_point()
end, { silent = true, desc = "Test unter Cursor" })
vim.keymap.set("n", "<leader>rta", function()
  java_test().run_class()
end, { silent = true, desc = "Tests dieser Klasse" })
vim.keymap.set("n", "<leader>rtl", function()
  java_test().rerun()
end, { silent = true, desc = "Letzten Test wiederholen" })
vim.keymap.set("n", "<leader>rto", function()
  java_test().toggle()
end, { silent = true, desc = "Testergebnisse" })
vim.keymap.set("n", "<leader>rts", function()
  java_test().toggle()
end, { silent = true, desc = "Testergebnisse" })
vim.keymap.set("n", "<leader>rtS", function()
  java_test().stop()
end, { silent = true, desc = "Tests stoppen" })

vim.api.nvim_create_user_command("JavaTestAtPoint", function()
  java_test().run_at_point()
end, { desc = "Test unter Cursor" })
vim.api.nvim_create_user_command("JavaTestClass", function()
  java_test().run_class()
end, { desc = "Testklasse ausführen" })
