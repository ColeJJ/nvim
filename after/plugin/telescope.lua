local telescope = require('telescope')
local builtin = require('telescope.builtin')
local monorepo = require("monorepo")

telescope.setup({
    defaults = {
        find_command = { 'fd', '--hidden', '--type', 'f', 'git', 'ls-files', '--exclude-standard', '--cached', '--others', '-v'},
        file_ignore_patterns = { ".git", "node_modules/" },
    },
    extensions = {
        fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
        },
    },
})

-- monorepo
monorepo.setup({
    silent = true,
    autoload_telescope = true,
    data_path = vim.fn.stdpath("data")
})

telescope.load_extension('fzf')
telescope.load_extension('monorepo')
telescope.load_extension("git_worktree")

-- mappings
local ns = { noremap = true, silent = true }
vim.keymap.set('n', '<leader>ff', function()
    builtin.find_files({
        no_ignore = false,
        hidden = true
}) end, ns)
vim.keymap.set('n', '<leader>fa', function()
    builtin.find_files({
        no_ignore = true,
        hidden = true
}) end, ns)
vim.keymap.set('n', '<leader>fc',function() builtin.git_commits() end, ns)
vim.keymap.set('n', '<leader>fw', require('telescope.builtin').grep_string, { desc = '[F]ind current [W]ord' })
vim.keymap.set('n', '<leader>fd', require('telescope.builtin').diagnostics, { desc = '[F]ind [D]iagnostics' })
vim.keymap.set('n', '<leader>fo', require('telescope.builtin').oldfiles, { desc = '[?] Find recently opened files' })
vim.keymap.set('n', '<leader>fb', require('telescope.builtin').buffers, { desc = '[ ] Find existing buffers' })
vim.keymap.set('n', '<leader>gr',function() builtin.live_grep() end, ns)
vim.keymap.set('n', '<leader>me',function() telescope.extensions.monorepo.monorepo() end, ns)
vim.keymap.set('n', '<leader>ma',function() monorepo.add_project() end, ns)
vim.keymap.set('n', '<leader>md',function() monorepo.remove_project() end, ns)
vim.keymap.set('n', '<leader>/', function() require('telescope.builtin').current_buffer_fuzzy_find() end, { desc = '[/] Fuzzily search in current buffer' })
vim.keymap.set('n', '<leader>?', require('telescope.builtin').help_tags, { desc = '[F]ind [H]elp' })
-- neorg
local neorg_callbacks = require("neorg.core.callbacks")
neorg_callbacks.on_event("core.keybinds.events.enable_keybinds", function(_, keybinds)
    -- Map all the below keybinds only when the "norg" mode is active
    keybinds.map_event_to_mode("norg", {
        n = { -- Bind keys in normal mode
            { "<leader>fn", "core.integrations.telescope.find_linkable" },
        }
    }, {
        silent = true,
        noremap = true,
    })
end)
