-- nvim-java: multi_select toggelt per Enter ein "*" und übernimmt erst bei Esc.
-- Enter bestätigt, Tab markiert mehrere (Telescope-Standard).

local M = {}

local function finish_once(callback)
  local done = false
  return function(result)
    if done then
      return
    end
    done = true
    vim.schedule(function()
      callback(result)
    end)
  end
end

local function chosen_values(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local picker = action_state.get_current_picker(prompt_bufnr)
  local multi = picker:get_multi_selection()
  local chosen = {}
  if multi and #multi > 0 then
    for _, entry in ipairs(multi) do
      chosen[#chosen + 1] = entry.value
    end
  else
    local current = action_state.get_selected_entry()
    if current then
      chosen[1] = current.value
    end
  end
  return chosen
end

function M.multi_select(prompt, values, format_item)
  local wait = require("async.waits.wait")
  return wait(function(callback)
    local finish = finish_once(callback)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local themes = require("telescope.themes")

    pickers
      .new(themes.get_dropdown({
        prompt_title = prompt .. "  ·  Enter übernehmen, Tab mehrere",
        previewer = false,
      }), {
        finder = finders.new_table({
          results = values,
          entry_maker = function(item)
            local text = format_item and format_item(item) or tostring(item)
            return {
              value = item,
              display = text,
              ordinal = text,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
          -- finish() vor close(): sonst ruft actions.close zuerst den
          -- Esc-Handler auf und die Auswahl geht verloren.
          local function confirm()
            local chosen = chosen_values(prompt_bufnr)
            finish(#chosen > 0 and chosen or nil)
            actions.close(prompt_bufnr)
          end
          actions.select_default:replace(confirm)
          map({ "i", "n" }, "<CR>", confirm)
          actions.close:enhance({
            post = function()
              finish(nil)
            end,
          })
          return true
        end,
      })
      :find()
  end)
end

function M.patch_nvim_java()
  local ok, ui = pcall(require, "java.ui.utils")
  if not ok then
    return
  end
  ui.multi_select = M.multi_select
end

return M
