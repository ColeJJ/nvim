return {
  {
    "rparrapy/tuicr.nvim",
    cmd = { "Tuicr", "TuicrToggle" },
    keys = {
      {
        "<leader>gt",
        function()
          require("colejj.git.tuicr").prompt()
        end,
        desc = "GitLab-MR mit tuicr",
      },
    },
    opts = {
      close_on_exit = true,
      close_strategy = "clip_then_quit",
      win = {
        style = "float",
        border = "rounded",
        width = 0.95,
        height = 0.95,
        title = " tuicr ",
        title_pos = "center",
      },
      keymaps = {
        q = { action = "close", mode = "n" },
        ["<C-q>"] = { action = "close", mode = { "n", "t" } },
        ["<Esc><Esc>"] = { action = "normal_mode", mode = "t" },
      },
    },
  },
}
