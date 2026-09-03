return {
  {
    "stevearc/overseer.nvim",
    cmd = { "OverseerRun", "OverseerToggle", "OverseerQuickAction" },
    keys = {
      { "<leader>mm", "<cmd>OverseerRun<CR>", desc = "Maven / Tasks" },
      { "<leader>mo", "<cmd>OverseerToggle<CR>", desc = "Task-Liste" },
    },
    opts = {
      templates = { "builtin", "user.maven" },
      task_list = {
        direction = "bottom",
        min_height = 12,
      },
    },
  },
}
