return {
  { "nvim-lua/plenary.nvim", lazy = true },
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    keys = {
      { "<leader>ff" },
      { "<leader><leader>" },
      { "<leader>fF" },
      { "<leader>fc" },
      { "<leader>fw" },
      { "<leader>fx" },
      { "<leader>fo" },
      { "<leader>fu" },
      { "<leader>fb" },
      { "<leader>bl" },
      { "<leader>fm" },
      { "<leader>fT" },
      { "<leader>gr", mode = { "n", "x" } },
      { "<leader>/", mode = { "n", "x" } },
      { "<leader>?" },
      { "<leader>is" },
      { "<leader>si" },
      { "<leader>sI" },
      { "<leader>sC" },
      { "<leader>sc" },
      { "<leader>sa" },
      { "<leader>ss", mode = { "n", "x" } },
      { "<leader>sb", mode = { "n", "x" } },
      { "<leader>sS" },
      { "<leader>sw" },
      { "<leader>sB" },
      { "<leader>sp", mode = { "n", "x" } },
      { "<leader>sF" },
      { "<leader>sP" },
      { "<leader>sd" },
      { "<leader>sD" },
      { "<leader>se" },
      { "<leader>sf" },
      { "<leader>sj" },
      { "<leader>sm" },
      { "<leader>s'" },
      { "<leader>sr" },
      { "<leader>su" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "camgraff/telescope-tmux.nvim",
    },
    config = function()
      local telescope = require("telescope")
      local builtin = require("telescope.builtin")
      local orig_preview_maker = require("telescope.previewers").buffer_previewer_maker
      telescope.setup({
        defaults = {
          file_ignore_patterns = { ".git/", "node_modules/", "dist/", "/bin/", "target/" },
          path_display = { "filename_first" },
          sorting_strategy = "ascending",
          layout_strategy = "vertical",
          layout_config = {
            vertical = {
              prompt_position = "bottom",
              mirror = false,
              preview_cutoff = 0,
              height = 0.9,
              width = 0.8,
            },
          },
          buffer_previewer_maker = function(filepath, bufnr, opts)
            opts = opts or {}
            local prior = opts.callback
            opts.callback = function(buf)
              if prior then
                prior(buf)
              end
              -- find_files nutzt den Grep-Previewer (Callback ohne lnum bleibt in Zeile 1).
              vim.schedule(function()
                local winid = opts.winid
                local line = 1
                if winid and vim.api.nvim_win_is_valid(winid) then
                  line = vim.api.nvim_win_get_cursor(winid)[1]
                end
                if line <= 1 then
                  require("colejj.preview").jump_to_type(buf, winid, filepath)
                end
              end)
            end
            orig_preview_maker(filepath, bufnr, opts)
          end,
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
          },
        },
      })
      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "tmux")

      local ns = { noremap = true, silent = true }
      local function find_project_files()
        local cwd = require("colejj.project").git_root() or require("colejj.project").reactor_root()
        builtin.find_files({
          cwd = cwd,
          hidden = true,
          file_ignore_patterns = { ".git/", "node_modules/", "dist/", "/bin/", "target/", ".m2/" },
        })
      end
      vim.keymap.set("n", "<leader>ff", find_project_files, vim.tbl_extend("force", ns, { desc = "Dateien im Projekt" }))
      vim.keymap.set("n", "<leader><leader>", find_project_files, vim.tbl_extend("force", ns, { desc = "Dateien im Projekt" }))
      vim.keymap.set("n", "<leader>fF", function()
        require("colejj.java.commands").goto_class_anywhere()
      end, vim.tbl_extend("force", ns, { desc = "Klasse inkl. Dependencies" }))
      vim.keymap.set("n", "<leader>fc", function()
        require("colejj.git.commit").pick()
      end, { desc = "Git-Commits (Details)" })
      vim.keymap.set("n", "<leader>fw", builtin.grep_string, { desc = "Wort unter Cursor" })
      vim.keymap.set("n", "<leader>fx", builtin.diagnostics, { desc = "Diagnosen" })
      vim.keymap.set("n", "<leader>fo", function()
        require("colejj.find").oldfiles()
      end, { desc = "Zuletzt geöffnet" })
      vim.keymap.set("n", "<leader>fu", function()
        require("colejj.find").unsaved_in_project()
      end, { desc = "Ungespeicherte Dateien" })
      local function buffer_list()
        builtin.buffers({
          prompt_title = "Buffer  ·  d/x/<C-d> schließen",
          sort_mru = true,
          sort_lastused = true,
          ignore_current_buffer = false,
          show_all_buffers = true,
          attach_mappings = function(_, map)
            local actions = require("telescope.actions")
            map({ "i", "n" }, "<C-d>", actions.delete_buffer)
            map("n", "d", actions.delete_buffer)
            map("n", "x", actions.delete_buffer)
            return true
          end,
        })
      end
      vim.keymap.set("n", "<leader>fb", buffer_list, { desc = "Buffer-Liste" })
      vim.keymap.set("n", "<leader>bl", buffer_list, { desc = "Buffer-Liste" })
      vim.keymap.set({ "n", "x" }, "<leader>gr", function()
        require("colejj.find").search_project()
      end, { desc = "Projekt durchsuchen" })
      local function search_buffer()
        require("colejj.find").search_buffer()
      end
      vim.keymap.set({ "n", "x" }, "<leader>/", search_buffer, { desc = "Im Buffer suchen" })
      vim.keymap.set("n", "<leader>?", builtin.help_tags, { desc = "Hilfe" })
      vim.keymap.set("n", "<leader>fT", "<cmd>Telescope tmux windows<CR>", { desc = "tmux-Fenster" })
      vim.keymap.set("n", "<leader>si", builtin.lsp_document_symbols, { desc = "Symbole dieser Datei" })
      vim.keymap.set("n", "<leader>sI", builtin.lsp_dynamic_workspace_symbols, { desc = "Symbole live (LSP)" })
      vim.keymap.set("n", "<leader>sC", builtin.lsp_workspace_symbols, { desc = "Symbolsuche (LSP, gründlich)" })
      vim.keymap.set("n", "<leader>sc", function()
        builtin.find_files({
          prompt_title = "Go to Class",
          find_command = { "fd", "--type", "f", "--extension", "java", "--extension", "kt", "--extension", "scala" },
        })
      end, { desc = "Go to Class (schnell)" })
      vim.keymap.set("n", "<leader>sa", function()
        require("colejj.java.commands").goto_class_anywhere()
      end, { desc = "Klasse inkl. Dependencies" })
      vim.keymap.set({ "n", "x" }, "<leader>ss", search_buffer, { desc = "Suche im Buffer" })
      vim.keymap.set({ "n", "x" }, "<leader>sb", search_buffer, { desc = "Suche im Buffer" })
      vim.keymap.set("n", "<leader>sS", function()
        require("colejj.find").search_buffer({ default_text = vim.fn.expand("<cword>") })
      end, { desc = "Buffer: Wort unter Cursor" })
      vim.keymap.set("n", "<leader>sw", function()
        local word = vim.fn.expand("<cword>")
        if word == "" then
          vim.notify("Kein Wort unter dem Cursor", vim.log.levels.WARN, { title = "Suche" })
          return
        end
        local path = vim.api.nvim_buf_get_name(0)
        if path == "" then
          builtin.current_buffer_fuzzy_find({ default_text = word })
          return
        end
        builtin.grep_string({
          search = word,
          word_match = "-w",
          search_dirs = { path },
          prompt_title = "Wort in Datei · " .. word,
        })
      end, { desc = "Wort in dieser Datei" })
      vim.keymap.set("n", "<leader>sB", function()
        require("colejj.find").search_buffers()
      end, { desc = "Suche in offenen Buffern" })
      vim.keymap.set({ "n", "x" }, "<leader>sp", function()
        require("colejj.find").search_project()
      end, { desc = "Suche im Projekt" })
      vim.keymap.set("n", "<leader>sF", function()
        require("colejj.find").search_project_regex()
      end, { desc = "Suche Regex" })
      vim.keymap.set("n", "<leader>sP", function()
        require("colejj.find").search_project_latin1()
      end, { desc = "Suche Latin-1" })
      vim.keymap.set("n", "<leader>sd", function()
        require("colejj.find").search_cwd()
      end, { desc = "Suche im Verzeichnis" })
      vim.keymap.set("n", "<leader>sD", function()
        require("colejj.find").search_other_cwd()
      end, { desc = "Suche in anderem Verzeichnis" })
      vim.keymap.set("n", "<leader>se", function()
        require("colejj.find").search_config()
      end, { desc = "Suche in Neovim-Config" })
      vim.keymap.set("n", "<leader>sf", builtin.find_files, { desc = "Datei finden" })
      vim.keymap.set("n", "<leader>sj", builtin.jumplist, { desc = "Jump-Liste" })
      vim.keymap.set("n", "<leader>sm", function()
        require("colejj.find").buffer_method()
      end, { desc = "Methode in dieser Datei" })
      vim.keymap.set("n", "<leader>s'", builtin.marks, { desc = "Marks" })
      vim.keymap.set("n", "<leader>sr", builtin.registers, { desc = "Register" })
      vim.keymap.set("n", "<leader>su", "<cmd>UndotreeToggle<CR>", { desc = "Undo-Historie" })
      vim.keymap.set("n", "<leader>fm", function()
        require("colejj.find").project_method()
      end, { desc = "Methode im Projekt finden" })
      vim.keymap.set("n", "<leader>is", function()
        builtin.live_grep({
          prompt_title = "Snippets (LuaSnip)",
          search_dirs = { vim.fn.stdpath("config") .. "/lua/colejj/snippets" },
        })
      end, { desc = "Snippets durchsuchen" })
    end,
  },
}
