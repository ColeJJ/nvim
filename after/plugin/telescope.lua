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

require("dir-telescope").setup({
    -- these are the default options set
    hidden = true,
    no_ignore = true,
    show_preview = true,
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
telescope.load_extension("dir")

-- mappings
vim.keymap.set('n', '<leader>ff', function()
    builtin.find_files({
        no_ignore = true,
        hidden = true
}) end, ns)
vim.keymap.set('n', '<leader>fg', function() builtin.git_files() end, ns)
vim.keymap.set('n', '<leader>fc', function() builtin.git_commits() end, ns)
vim.keymap.set('n', '<leader>gr', function() builtin.live_grep() end, ns)
vim.keymap.set("n", "<leader>fd", function() telescope.extensions.dir.find_files() end, ns)
vim.keymap.set("n", "<leader>gg", function() telescope.extensions.dir.live_grep() end, ns)
vim.keymap.set('n', '<leader>me', function() telescope.extensions.monorepo.monorepo() end, ns)
vim.keymap.set('n', '<leader>ma', function() monorepo.add_project() end, ns)
vim.keymap.set('n', '<leader>md', function() monorepo.remove_project() end, ns)
