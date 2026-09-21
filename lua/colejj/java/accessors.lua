-- nvim-java kennt java.action.generateAccessorsPrompt noch nicht.
-- Getter/Setter laufen deshalb über denselben JDT.LS-Pfad wie in vscode-java.

local M = {}

local KIND = {
  getter = 0,
  setter = 1,
  both = 2,
}

local function accessor_context(command, params)
  local arg = command and command.arguments and command.arguments[1]
  if type(arg) == "table" and arg.textDocument then
    return arg
  end
  local context = vim.deepcopy(params and params.params or {})
  if type(arg) == "table" and arg.kind ~= nil then
    context.kind = arg.kind
  end
  return context
end

local function kind_label(kind)
  if kind == KIND.getter then
    return "Getter"
  end
  if kind == KIND.setter then
    return "Setter"
  end
  return "Getter/Setter"
end

local function accessor_label(accessor)
  local kinds = {}
  if accessor.generateGetter then
    kinds[#kinds + 1] = "getter"
  end
  if accessor.generateSetter then
    kinds[#kinds + 1] = "setter"
  end
  local prefix = accessor.isStatic and "static " or ""
  return string.format("%s: %s (%s%s)", accessor.fieldName, accessor.typeName, prefix, table.concat(kinds, ", "))
end

function M.generate(action, command, params)
  local ui = require("java.ui.utils")
  local notify = require("java-core.utils.notify")
  local context = accessor_context(command, params)
  local accessors = action.jdtls:request("java/resolveUnimplementedAccessors", context)
  if not accessors or #accessors < 1 then
    notify.warn("Keine Getter/Setter zu generieren.")
    return
  end

  local selected = ui.multi_select(
    "Felder für " .. kind_label(context.kind) .. "  ·  Enter übernehmen, Tab mehrere",
    accessors,
    accessor_label
  )
  if not selected or #selected < 1 then
    return
  end

  local edit = action.jdtls:request("java/generateAccessors", {
    context = context,
    accessors = selected,
  })
  if not edit then
    return
  end
  local encoding = (action.client and action.client.offset_encoding) or "utf-8"
  vim.lsp.util.apply_workspace_edit(edit, encoding)
end

function M.patch_nvim_java()
  local ok_action, Action = pcall(require, "java-refactor.action")
  local ok_handlers, handlers = pcall(require, "java-refactor.client-command-handlers")
  local ok_cmd, ClientCommand = pcall(require, "java-refactor.client-command")
  if not (ok_action and ok_handlers and ok_cmd) then
    return
  end

  function Action:generate_accessors(command, params)
    M.generate(self, command, params)
  end

  local handler = function(command, params)
    require("async.runner")(function()
      require("java-refactor.utils.instance-factory").get_action():generate_accessors(command, params)
    end)
      .catch(require("java-refactor.utils.error_handler")("Failed to generate accessors"))
      .run()
  end

  handlers[ClientCommand.GENERATE_ACCESSORS_PROMPT] = handler
  vim.lsp.commands[ClientCommand.GENERATE_ACCESSORS_PROMPT] = handler
end

return M
