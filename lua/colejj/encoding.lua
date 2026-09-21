-- Java-*.properties sind in diesem Stack ISO-8859-1 (Java-Spec / Doom).
-- Als UTF-8 gelesen werden ö/ß ungültig → U+FFFD; Speichern schreibt ï¿½ (EF BF BD).
-- Die Schriftart ändert keine Dateibytes.

local M = {}

local PROPERTIES = { "*.properties" }
local default_fencs = vim.o.fileencodings

function M.setup()
  vim.api.nvim_create_autocmd("BufReadPre", {
    group = vim.api.nvim_create_augroup("colejj-encoding-pre", { clear = true }),
    pattern = PROPERTIES,
    callback = function()
      vim.opt.fileencodings = "latin1"
    end,
  })

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("colejj-encoding", { clear = true }),
    pattern = PROPERTIES,
    callback = function(ev)
      vim.opt.fileencodings = default_fencs
      vim.bo[ev.buf].fileencoding = "latin1"
    end,
  })
end

return M
