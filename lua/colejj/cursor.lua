-- Zwei Cursor-Varianten:
--   schmal  = Insert als Balken (Standard)
--   block   = immer Block, Normal grau / Insert weiß

local M = {}

M.block = false

local function shapes()
  if M.block then
    return {
      "n-sm:block-Cursor",
      "c:block-Cursor",
      "i-ci-ve:block-iCursor",
      "v:block-vCursor",
      "r-cr-o:block-Cursor",
      "t:block-TermCursor",
      "a:blinkon0",
    }
  end
  -- Neovim-Default ist ver25; in GUI/HiDPI wirkt das oft wie ein Haarstrich.
  return {
    "n-sm:block-Cursor",
    "c:block-Cursor",
    "i-ci-ve:ver35",
    "v:block-vCursor",
    "r-cr-o:hor20",
    "t:block-TermCursor",
    "a:blinkon0",
  }
end

function M.apply()
  vim.opt.guicursor = shapes()
end

function M.toggle()
  M.block = not M.block
  M.apply()
  vim.notify(M.block and "Cursor: Block (Farbe wechselt)" or "Cursor: Insert schmal", vim.log.levels.INFO, {
    title = "Cursor",
  })
end

function M.setup()
  M.apply()
  vim.keymap.set("n", "<leader>C", M.toggle, { desc = "Cursor-Stil umschalten" })
end

return M
