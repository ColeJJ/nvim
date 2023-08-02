local mark = require("harpoon.mark")
local ui = require("harpoon.ui")
local tmux = require("harpoon.tmux")

require("harpoon").setup({
    menu = {
        width = vim.api.nvim_win_get_width(0) - 4,
    },
    -- enable tabline with harpoon marks
    tabline = true,
    tabline_prefix = "   ",
    tabline_suffix = "   ",
})

vim.cmd('highlight! HarpoonInactive guibg=NONE guifg=#63698c')
vim.cmd('highlight! HarpoonActive guibg=NONE guifg=white')
vim.cmd('highlight! HarpoonNumberActive guibg=NONE guifg=#7aa2f7')
vim.cmd('highlight! HarpoonNumberInactive guibg=NONE guifg=#7aa2f7')
vim.cmd('highlight! TabLineFill guibg=NONE guifg=white')

vim.keymap.set("n", "<leader>ha", mark.add_file);
vim.keymap.set("n", "<leader>he", ui.toggle_quick_menu);

vim.keymap.set("n", "<leader>h1", function() ui.nav_file(1) end);
vim.keymap.set("n", "<leader>h2", function() ui.nav_file(2) end);
vim.keymap.set("n", "<leader>h3", function() ui.nav_file(3) end);
vim.keymap.set("n", "<leader>h4", function() ui.nav_file(4) end);
vim.keymap.set("n", "<leader>h5", function() ui.nav_file(5) end);
vim.keymap.set("n", "<leader>h6", function() ui.nav_file(6) end);

-- tmux
-- currently not working 
-- vim.keymap.set("n", "<leader>w1", function() tmux.gotoTerminal(1) end);
-- vim.keymap.set("n", "<leader>w2", function() tmux.gotoTerminal(2) end);
-- vim.keymap.set("n", "<leader>w3", function() tmux.gotoTerminal(3) end);
-- vim.keymap.set("n", "<leader>w4", function() tmux.gotoTerminal(4) end);
