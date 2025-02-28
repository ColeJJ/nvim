local telescope = require('telescope')
local builtin = require('telescope.builtin')

telescope.setup({
    defaults = {
        find_command = { 'fd', '--hidden', '--type', 'f', 'ls-tree', '--full-tree'},
        file_ignore_patterns = { ".git", "node_modules/*" , ".gitignore", "dist/*"},
        layout_strategy = 'vertical',
        layout_config = {
            vertical = {
                prompt_position = "bottom",
                mirror = false,
                preview_cutoff = 0,
                height = 0.9,
                width = 0.8
            },
        }
    },
    extensions = {
        fzf = {
            fuzzy = false,
            override_generic_sorter = true,
            override_file_sorter = true,
        },
    },
})

telescope.load_extension('fzf')
telescope.load_extension("git_worktree")

-- mappings
local ns = { noremap = true, silent = true }
vim.keymap.set('n', '<leader>ff', function()
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
vim.keymap.set('n', '<leader>/', function() require('telescope.builtin').current_buffer_fuzzy_find() end, { desc = '[/] Fuzzily search in current buffer' })
vim.keymap.set('n', '<leader>?', require('telescope.builtin').help_tags, { desc = '[F]ind [H]elp' })
-- tmux
vim.keymap.set('n', '<leader>ft', ':Telescope tmux windows<CR>', ns)
