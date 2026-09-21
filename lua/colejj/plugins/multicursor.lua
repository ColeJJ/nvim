return {
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    event = "VeryLazy",
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      -- Wie IntelliJ Alt+J / Ctrl+G: nächste gleiche Stelle, dann tippen.
      vim.keymap.set({ "n", "x" }, "<C-n>", function()
        mc.matchAddCursor(1)
      end, { desc = "Nächste gleiche Stelle (Multicursor)" })
      vim.keymap.set({ "n", "x" }, "<C-S-n>", function()
        mc.matchAddCursor(-1)
      end, { desc = "Vorherige gleiche Stelle (Multicursor)" })
      -- Alle Vorkommen des Worts bzw. der Auswahl in dieser Datei
      vim.keymap.set({ "n", "x" }, "<leader>n", function()
        mc.matchAllAddCursors()
      end, { desc = "Alle gleichen Stellen (Multicursor)" })

      mc.addKeymapLayer(function(layer)
        layer({ "n", "x" }, "n", function()
          mc.matchAddCursor(1)
        end)
        layer({ "n", "x" }, "N", function()
          mc.matchAddCursor(-1)
        end)
        layer("n", "<Esc>", function()
          if not mc.cursorsEnabled() then
            mc.enableCursors()
          else
            mc.clearCursors()
          end
        end)
      end)
    end,
  },
}
