return {
  {
    "kdheepak/lazygit.nvim",
    cmd = { "LazyGit", "LazyGitCurrentFile" },
    init = function()
      vim.g.lazygit_use_custom_config_file_path = 1
      vim.g.lazygit_config_file_path = vim.fn.stdpath("config") .. "/lazygit.yml"

      -- LazyGit öffnet `e` mit dem nvim-remote-Preset in einem neuen Tab.
      -- lazygit.nvim springt beim Beenden anschließend in das alte Fenster
      -- zurück; den von LazyGit geöffneten Tab deshalb explizit beibehalten.
      local target_tab
      vim.api.nvim_create_autocmd("TabNew", {
        group = vim.api.nvim_create_augroup("colejj-lazygit-edit", { clear = true }),
        callback = function()
          if vim.g.lazygit_opened == 1 then
            target_tab = vim.api.nvim_get_current_tabpage()
          end
        end,
      })
      vim.g.lazygit_on_exit_callback = function()
        local tab = target_tab
        target_tab = nil
        if tab and vim.api.nvim_tabpage_is_valid(tab) then
          vim.api.nvim_set_current_tabpage(tab)
        end
      end
    end,
    keys = {
      { "<leader>gs", "<cmd>LazyGitCurrentFile<CR>", desc = "LazyGit (Datei)" },
      { "<leader>gg", "<cmd>LazyGit<CR>", desc = "LazyGit" },
      {
        "<leader>gd",
        function()
          require("colejj.git.filediff").open_head()
        end,
        desc = "Datei-Diff vs HEAD",
      },
      {
        "<leader>gD",
        function()
          require("colejj.git.filediff").open_base()
        end,
        desc = "Datei-Diff vs Abzweigpunkt",
      },
    },
  },
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    event = { "BufReadPost", "BufNewFile" },
    config = true,
    keys = {
      { "<leader>gc", "<cmd>GitConflictListQf<CR>", desc = "Merge-Konflikte" },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      current_line_blame = false,
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map("n", "]c", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
          end
        end, "Nächster Hunk")
        map("n", "[c", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
          end
        end, "Vorheriger Hunk")
        map("n", "<leader>gB", gs.toggle_current_line_blame, "Blame der aktuellen Zeile")
        map("n", "<leader>gp", gs.preview_hunk, "Hunk-Vorschau")
        map("n", "<leader>gS", gs.stage_hunk, "Hunk stagen")
        map("n", "<leader>gu", gs.reset_hunk, "Hunk zurücksetzen")
      end,
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    opts = function()
      return require("colejj.git.diffview").opts()
    end,
    keys = {
      {
        "<leader>gh",
        function()
          require("colejj.git.diffview").open("DiffviewFileHistory %")
        end,
        desc = "Datei-Historie",
      },
      {
        "<leader>gH",
        function()
          require("colejj.git.diffview").open("DiffviewFileHistory")
        end,
        desc = "Projekt-Historie",
      },
    },
  },
}
