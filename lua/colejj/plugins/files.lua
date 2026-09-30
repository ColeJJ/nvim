return {
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      {
        "<leader>fd",
        function()
          require("colejj.find").find_directory()
        end,
        desc = "Verzeichnis im Projekt",
      },
      {
        "<leader>f.",
        function()
          require("oil").open()
        end,
        desc = "Dired (aktueller Ordner)",
      },
      {
        "<leader>oe",
        function()
          require("colejj.find").open_dired()
        end,
        desc = "Dired (Verzeichnis dieser Datei)",
      },
      {
        "-",
        function()
          require("oil").open()
        end,
        desc = "Dired (aktueller Ordner)",
      },
    },
    opts = {
      default_file_explorer = false,
      columns = { "icon", "permissions", "size" },
      view_options = {
        show_hidden = true,
      },
      keymaps = {
        ["q"] = "actions.close",
        ["<C-c>"] = "actions.close",
        ["<CR>"] = "actions.select",
        ["-"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["g."] = "actions.toggle_hidden",
      },
      use_default_keymaps = true,
    },
  },
}
