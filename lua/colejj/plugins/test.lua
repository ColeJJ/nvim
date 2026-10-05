return {
  {
    "nvim-neotest/neotest",
    keys = {
      { "<leader>rtd", desc = "Test debuggen" },
      { "<leader>rtD", desc = "Datei debuggen" },
    },
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "mfussenegger/nvim-dap",
      "rcasia/neotest-java",
    },
    config = function()
      local neotest = require("neotest")
      neotest.setup({
        adapters = {
          require("neotest-java")({
            incremental_build = true,
          }),
        },
        output = { open_on_run = true },
        summary = { animated = true },
      })

      vim.keymap.set("n", "<leader>rtd", function()
        neotest.run.run({ strategy = "dap" })
      end, { silent = true, desc = "Test debuggen" })
      vim.keymap.set("n", "<leader>rtD", function()
        neotest.run.run({ vim.fn.expand("%"), strategy = "dap" })
      end, { silent = true, desc = "Datei debuggen" })
    end,
  },
}
