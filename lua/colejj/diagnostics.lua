-- Diagnosen: sichtbar machen und `ge` zuverlässig öffnen (Neovim 0.12 Pull-Diagnostics).

local M = {}

local float_opts = {
  border = "rounded",
  source = true,
  header = "Diagnosen",
  prefix = "",
  focusable = false,
  severity_sort = true,
}

local function jump(count, severity)
  vim.diagnostic.jump({
    count = count,
    severity = severity,
    float = vim.tbl_extend("force", float_opts, { scope = "cursor" }),
    wrap = true,
  })
end

local function refresh_pull(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, lsp_diag = pcall(require, "vim.lsp.diagnostic")
  if not ok or type(lsp_diag._refresh) ~= "function" then
    return
  end
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method("textDocument/diagnostic") then
      lsp_diag._refresh(bufnr, client.id)
    end
  end
end

local function telescope_diagnostics(opts)
  local ok, builtin = pcall(require, "telescope.builtin")
  if not ok then
    vim.notify("Telescope ist nicht geladen", vim.log.levels.WARN)
    return
  end
  builtin.diagnostics(opts)
end

function M.open()
  if #vim.diagnostic.get(0) == 0 then
    refresh_pull()
  end
  telescope_diagnostics({
    bufnr = 0,
    prompt_title = "Diagnosen",
  })
end

function M.setup()
  vim.diagnostic.config({
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    virtual_text = {
      spacing = 2,
      prefix = "●",
      source = "if_many",
    },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = "E",
        [vim.diagnostic.severity.WARN] = "W",
        [vim.diagnostic.severity.HINT] = "H",
        [vim.diagnostic.severity.INFO] = "I",
      },
    },
    float = float_opts,
    jump = {
      float = true,
      wrap = true,
    },
  })

  vim.keymap.set("n", "ge", M.open, { desc = "Diagnosen dieser Datei" })
  vim.keymap.set("n", "]e", function()
    jump(1, vim.diagnostic.severity.ERROR)
  end, { desc = "Nächster Fehler" })
  vim.keymap.set("n", "[e", function()
    jump(-1, vim.diagnostic.severity.ERROR)
  end, { desc = "Vorheriger Fehler" })
  vim.keymap.set("n", "]w", function()
    jump(1, vim.diagnostic.severity.WARN)
  end, { desc = "Nächste Warnung" })
  vim.keymap.set("n", "[w", function()
    jump(-1, vim.diagnostic.severity.WARN)
  end, { desc = "Vorherige Warnung" })
  vim.keymap.set("n", "<leader>ce", function()
    jump(1, vim.diagnostic.severity.ERROR)
  end, { desc = "Nächster Fehler" })
  vim.keymap.set("n", "<leader>cw", function()
    jump(1, vim.diagnostic.severity.WARN)
  end, { desc = "Nächste Warnung" })
  vim.keymap.set("n", "<leader>cx", function()
    vim.diagnostic.setloclist({ open = true })
  end, { desc = "Diagnosen dieser Datei" })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("colejj-diagnostics-pull", { clear = true }),
    callback = function(event)
      -- 0.12: Pull startet sonst erst bei didChange — frisch geöffnete Dateien bleiben leer.
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(event.buf) then
          refresh_pull(event.buf)
        end
      end, 100)
    end,
  })
end

return M
