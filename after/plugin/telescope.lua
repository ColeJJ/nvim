local telescope = require('telescope')
local builtin = require('telescope.builtin')
local monorepo = require("monorepo")
local ns = { noremap = true, silent = true }
local function telescope_buffer_dir()
    return vim.fn.expand('%:p:h')
end

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
        file_browser = {
            theme = "dropdown",
            hijack_netrw = false,
        }
    },
})

-- monorepo
monorepo.setup({
    silent = true,
    autoload_telescope = true,
    data_path = vim.fn.stdpath("data")
})

telescope.load_extension('fzf')
telescope.load_extension('file_browser')
telescope.load_extension('monorepo')

-- mappings
vim.keymap.set('n', '<leader>ff', function()
    builtin.find_files({
        no_ignore = false,
        hidden = true
}) end, ns)
vim.keymap.set('n', '<leader>gf', function() builtin.git_files() end, ns)
vim.keymap.set('n', '<leader>gr', function() builtin.live_grep() end, ns)
vim.keymap.set('n', '<leader>me', function() telescope.extensions.monorepo.monorepo() end, ns)
vim.keymap.set('n', '<leader>ma', function() monorepo.add_project() end, ns)
vim.keymap.set('n', '<leader>md', function() monorepo.remove_project() end, ns)
vim.keymap.set('n', '<leader>fb', function()
    telescope.extensions.file_browser.file_browser({
        path = "%:p:h",
        cwd = telescope_buffer_dir(),
        respect_gitignore = false,
    }) end, ns)
