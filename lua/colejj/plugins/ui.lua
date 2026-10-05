return {
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,
    config = function()
      require("colejj.theme.rosepine").setup()
    end,
  },
  {
    "tjdevries/colorbuddy.nvim",
    lazy = true,
  },
  {
    "norcalli/nvim-colorizer.lua",
    event = "VeryLazy",
    config = function()
      require("colorizer").setup({ "css", "html", "lua", "conf", "tmux" })
    end,
  },
  {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    opts = {
      input = {
        win_options = {
          winhighlight = "NormalFloat:DiagnosticError",
        },
      },
    },
  },
  { "nvim-tree/nvim-web-devicons", lazy = true },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    config = function(_, opts)
      if vim.g.colors_name == "tj" then
        opts.options.theme = vim.g.tj_lualine or "auto"
      elseif vim.g.colors_name == "custom-obsidian" then
        opts.options.theme = vim.g.custom_obsidian_lualine or "auto"
      elseif vim.g.colors_name == "material-deep-ocean" then
        opts.options.theme = vim.g.material_deep_ocean_lualine or "auto"
      else
        opts.options.theme = "auto"
      end
      require("lualine").setup(opts)
    end,
    opts = {
      options = {
        icons_enabled = true,
        theme = "auto",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        always_divide_middle = false,
        globalstatus = true,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = { { "filename", file_status = true, path = 1 } },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    keys = {
      { "<leader>e", "<cmd>NvimTreeToggle<CR>", desc = "Dateibaum" },
    },
    opts = {
      disable_netrw = true,
      hijack_netrw = true,
      hijack_cursor = true,
      hijack_unnamed_buffer_when_opening = false,
      hijack_directories = { enable = false },
      sync_root_with_cwd = true,
      update_focused_file = {
        enable = true,
        update_cwd = false,
      },
      renderer = {
        root_folder_modifier = ":t",
        highlight_opened_files = "none",
        icons = {
          webdev_colors = true,
          git_placement = "before",
          show = {
            file = true,
            folder = true,
            folder_arrow = true,
            git = true,
          },
        },
      },
      diagnostics = {
        enable = true,
        show_on_dirs = false,
      },
      view = { adaptive_size = true },
      filters = {
        dotfiles = false,
        -- git_ignored bleibt an (kein target/, node_modules/); SQL trotzdem zeigen
        exclude = { "%.sql$" },
      },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>b", group = "buffer" },
        { "<leader>bl", desc = "Buffer-Liste" },
        { "<leader>c", group = "code" },
        { "<leader>cf", desc = "Format (IntelliJ-Profil)" },
        { "<leader>ce", desc = "Nächster Fehler" },
        { "<leader>cw", desc = "Nächste Warnung" },
        { "<leader>cn", desc = "Nächste Methode/Klasse" },
        { "<leader>cN", desc = "Vorherige Methode/Klasse" },
        { "<leader>fm", desc = "Methode im Projekt finden" },
        { "<leader>sm", desc = "Methode in dieser Datei" },
        { "ge", desc = "Diagnosen dieser Datei" },
        { "]e", desc = "Nächster Fehler" },
        { "[e", desc = "Vorheriger Fehler" },
        { "]w", desc = "Nächste Warnung" },
        { "[w", desc = "Vorherige Warnung" },
        { "<leader>d", group = "debug" },
        { "<leader>f", group = "finden" },
        { "<leader>fs", desc = "Datei speichern" },
        { "<leader>ff", desc = "Dateien im Projekt" },
        { "<leader><leader>", desc = "Dateien im Projekt" },
        { "<leader>fF", desc = "Klasse inkl. Dependencies" },
        { "<leader>fd", desc = "Verzeichnis im Projekt" },
        { "<leader>f.", desc = "Dired (aktueller Ordner)" },
        { "<leader>ft", desc = "DB-Tabelle finden" },
        { "<leader>fT", desc = "tmux-Fenster" },
        { "<leader>fc", desc = "Git-Commits (Details)" },
        { "<leader>fu", desc = "Ungespeicherte Dateien" },
        { "<leader>fx", desc = "Diagnosen" },
        { "<leader>g", group = "git" },
        { "<leader>gb", desc = "Inline-Blame (Heatmap)" },
        { "<leader>gB", desc = "Blame der aktuellen Zeile" },
        { "<leader>gd", desc = "Datei-Diff vs HEAD" },
        { "<leader>gD", desc = "Datei-Diff vs Abzweigpunkt" },
        { "<leader>gm", desc = "Merge Requests" },
        { "<leader>h", group = "harpoon" },
        { "<leader>T", desc = "Theme wählen" },
        { "<leader>C", desc = "Cursor-Stil umschalten" },
        { "<leader>j", group = "java" },
        { "<leader>jn", desc = "Neuer Typ" },
        { "<leader>jr", desc = "JDT.LS neu starten" },
        { "<leader>jW", desc = "JDT.LS Workspace reset" },
        { "<leader>n", desc = "Alle gleichen Stellen (Multicursor)" },
        { "<leader>m", group = "maven" },
        { "<leader>r", group = "run" },
        { "<leader>rt", group = "tests" },
        { "<leader>rtt", desc = "Test unter Cursor" },
        { "<leader>rta", desc = "Tests dieser Klasse" },
        { "<leader>rtl", desc = "Letzten Test wiederholen" },
        { "<leader>rto", desc = "Testergebnisse" },
        { "<leader>rts", desc = "Testergebnisse" },
        { "<leader>rtS", desc = "Tests stoppen" },
        { "<leader>rtd", desc = "Test debuggen" },
        { "<leader>rtD", desc = "Datei debuggen" },
        { "<leader>s", group = "suche" },
        { "<leader>sc", desc = "Go to Class (schnell)" },
        { "<leader>sC", desc = "Symbolsuche (LSP)" },
        { "<leader>sa", desc = "Klasse inkl. Dependencies" },
        { "<leader>sp", desc = "Suche im Projekt" },
        { "<leader>sF", desc = "Suche Regex" },
        { "<leader>sP", desc = "Suche Latin-1" },
        { "<leader>ss", desc = "Suche im Buffer" },
        { "<leader>sw", desc = "Wort in dieser Datei" },
        { "<leader>t", group = "tabelle" },
        { "<leader>tc", desc = "DB-Spalte finden" },
        { "<leader>tw", desc = "DB-WHERE-Filter" },
        { "<leader>o", group = "öffnen" },
        { "<leader>ob", desc = "Im Standard-Browser öffnen" },
        { "<leader>oc", desc = "Podman Compose / LazyDocker" },
        { "<leader>oC", desc = "LazyDocker (alle Container)" },
        { "<leader>od", desc = "Datenbank-Viewer" },
        { "<leader>oe", desc = "Dired (Verzeichnis dieser Datei)" },
        { "<leader>w", group = "fenster" },
        { "<leader>wh", desc = "Fenster links" },
        { "<leader>wj", desc = "Fenster unten" },
        { "<leader>wk", desc = "Fenster oben" },
        { "<leader>wl", desc = "Fenster rechts" },
        { "<leader>wq", desc = "Fenster schließen" },
        { "<leader>wv", desc = "Fenster vertikal splitten" },
        { "<leader>wV", desc = "Fenster horizontal splitten" },
      },
    },
  },
}
