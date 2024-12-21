---@mod movelang.commands

local config = require('movelang.config.internal')

---@class movelang.Commands
local M = {}

local move_lsp_cmd_name = 'MoveLsp'

---@class movelang.command_tbl
---@field impl fun(args: string[], opts: vim.api.keyset.user_command) The command implementation
---@field complete? fun(subcmd_arg_lead: string): string[] Command completions callback, taking the lead of the subcommand's arguments
---@field bang? boolean Whether this command supports a bang!

---@type movelang.command_tbl[]
local movelsp_command_tbl = {
  codeAction = {
    impl = function(_)
      require('movelang.commands.code_action_group')()
    end,
  },
  debuggables = {
    ---@param args string[]
    ---@param opts vim.api.keyset.user_command
    impl = function(args, opts)
      if opts.bang then
        require('movelang.cached_commands').execute_last_debuggable(args)
      else
        require('movelang.commands.debuggables').debuggables(args)
      end
    end,
    bang = true,
  },
  debug = {
    ---@param args string[]
    ---@param opts vim.api.keyset.user_command
    impl = function(args, opts)
      if opts.bang then
        require('movelang.cached_commands').execute_last_debuggable(args)
      else
        require('movelang.commands.debuggables').debug(args)
      end
    end,
    bang = true,
  },
  expandMacro = {
    impl = function(_)
      require('movelang.commands.expand_macro')()
    end,
  },
  explainError = {
    impl = function(args)
      local subcmd = args[1] or 'cycle'
      if subcmd == 'cycle' then
        require('movelang.commands.diagnostic').explain_error()
      elseif subcmd == 'current' then
        require('movelang.commands.diagnostic').explain_error_current_line()
      else
        vim.notify(
          'explainError: unknown subcommand: ' .. subcmd .. " expected 'cycle' or 'current'",
          vim.log.levels.ERROR
        )
      end
    end,
    complete = function()
      return { 'cycle', 'current' }
    end,
  },
  renderDiagnostic = {
    impl = function(args)
      local subcmd = args[1] or 'cycle'
      if subcmd == 'cycle' then
        require('movelang.commands.diagnostic').render_diagnostic()
      elseif subcmd == 'current' then
        require('movelang.commands.diagnostic').render_diagnostic_current_line()
      else
        vim.notify(
          'renderDiagnostic: unknown subcommand: ' .. subcmd .. " expected 'cycle' or 'current'",
          vim.log.levels.ERROR
        )
      end
    end,
    complete = function()
      return { 'cycle', 'current' }
    end,
  },
  rebuildProcMacros = {
    impl = function()
      require('movelang.commands.rebuild_proc_macros')()
    end,
  },
  externalDocs = {
    impl = function(_)
      require('movelang.commands.external_docs')()
    end,
  },
  hover = {
    impl = function(args)
      if #args == 0 then
        vim.notify("hover: called without 'actions' or 'range'", vim.log.levels.ERROR)
        return
      end
      local subcmd = args[1]
      if subcmd == 'actions' then
        require('movelang.hover_actions').hover_actions()
      elseif subcmd == 'range' then
        require('movelang.commands.hover_range')()
      else
        vim.notify('hover: unknown subcommand: ' .. subcmd .. " expected 'actions' or 'range'", vim.log.levels.ERROR)
      end
    end,
    complete = function()
      return { 'actions', 'range' }
    end,
  },
  runnables = {
    ---@param opts vim.api.keyset.user_command
    impl = function(args, opts)
      if opts.bang then
        require('movelang.cached_commands').execute_last_runnable(args)
      else
        require('movelang.runnables').runnables(args)
      end
    end,
    bang = true,
  },
  run = {
    ---@param opts vim.api.keyset.user_command
    impl = function(args, opts)
      if opts.bang then
        require('movelang.cached_commands').execute_last_runnable(args)
      else
        require('movelang.runnables').run(args)
      end
    end,
    bang = true,
  },
  testables = {
    ---@param opts vim.api.keyset.user_command
    impl = function(args, opts)
      if opts.bang then
        require('movelang.cached_commands').execute_last_testable()
      else
        require('movelang.runnables').runnables(args, { tests_only = true })
      end
    end,
    bang = true,
  },
  joinLines = {
    impl = function(_, opts)
      ---@cast opts vim.api.keyset.user_command
      local visual_mode = opts.range and opts.range ~= 0 or false
      require('movelang.commands.join_lines')(visual_mode)
    end,
  },
  moveItem = {
    impl = function(args)
      if #args == 0 then
        vim.notify("moveItem: called without 'up' or 'down'", vim.log.levels.ERROR)
        return
      end
      if args[1] == 'down' then
        require('movelang.commands.move_item')()
      elseif args[1] == 'up' then
        require('movelang.commands.move_item')(true)
      else
        vim.notify(
          'moveItem: unexpected argument: ' .. vim.inspect(args) .. " expected 'up' or 'down'",
          vim.log.levels.ERROR
        )
      end
    end,
    complete = function()
      return { 'up', 'down' }
    end,
  },
  openCargo = {
    impl = function(_)
      require('movelang.commands.open_move_toml')()
    end,
  },
  openDocs = {
    impl = function(_)
      require('movelang.commands.external_docs')()
    end,
  },
  parentModule = {
    impl = function(_)
      require('movelang.commands.parent_module')()
    end,
  },
  ssr = {
    impl = function(args, opts)
      ---@cast opts vim.api.keyset.user_command
      local visual_mode = opts.range and opts.range > 0 or false
      local query = args and #args > 0 and table.concat(args, ' ') or nil
      require('movelang.commands.ssr')(query, visual_mode)
    end,
  },
  reloadWorkspace = {
    impl = function()
      require('movelang.commands.workspace_refresh')()
    end,
  },
  workspaceSymbol = {
    ---@param opts vim.api.keyset.user_command
    impl = function(args, opts)
      local c = require('movelang.commands.workspace_symbol')
      ---@type WorkspaceSymbolSearchScope
      local searchScope = opts.bang and c.WorkspaceSymbolSearchScope.workspaceAndDependencies
        or c.WorkspaceSymbolSearchScope.workspace
      c.workspace_symbol(searchScope, args)
    end,
    complete = function(subcmd_arg_lead)
      local c = require('movelang.commands.workspace_symbol')
      return vim.tbl_filter(function(arg)
        return arg:find(subcmd_arg_lead) ~= nil
      end, vim.tbl_values(c.WorkspaceSymbolSearchKind))
      --
    end,
    bang = true,
  },
  syntaxTree = {
    impl = function()
      require('movelang.commands.syntax_tree')()
    end,
  },
  flyCheck = {
    impl = function(args)
      local cmd = args[1] or 'run'
      require('movelang.commands.fly_check')(cmd)
    end,
    complete = function(subcmd_arg_lead)
      return vim.tbl_filter(function(arg)
        return arg:find(subcmd_arg_lead) ~= nil
      end, { 'run', 'clear', 'cancel' })
    end,
  },
  view = {
    impl = function(args)
      if not args or #args == 0 then
        vim.notify("Expected argument: 'mir' or 'hir'", vim.log.levels.ERROR)
        return
      end
      local level
      local arg = args[1]:lower()
      if arg == 'mir' then
        level = 'Mir'
      elseif arg == 'hir' then
        level = 'Hir'
      else
        vim.notify('Unexpected argument: ' .. arg .. " Expected: 'mir' or 'hir'", vim.log.levels.ERROR)
        return
      end
      require('movelang.commands.view_ir')(level)
    end,
    complete = function(subcmd_arg_lead)
      return vim.tbl_filter(function(arg)
        return arg:find(subcmd_arg_lead) ~= nil
      end, { 'mir', 'hir' })
    end,
  },
  logFile = {
    impl = function()
      vim.cmd.e(config.server.logfile)
    end,
  },
}

---@param command_tbl movelang.command_tbl
---@param opts table
---@see vim.api.nvim_create_user_command
local function run_command(command_tbl, cmd_name, opts)
  local fargs = opts.fargs
  local cmd = fargs[1]
  local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
  local command = command_tbl[cmd]
  if type(command) ~= 'table' or type(command.impl) ~= 'function' then
    vim.notify(cmd_name .. ': Unknown subcommand: ' .. cmd, vim.log.levels.ERROR)
    return
  end
  command.impl(args, opts)
end

---@param opts table
---@see vim.api.nvim_create_user_command
local function move_lsp(opts)
  run_command(movelsp_command_tbl, move_lsp_cmd_name, opts)
end

---@generic K, V
---@param predicate fun(V):boolean
---@param tbl table<K, V>
---@return K[]
local function tbl_keys_by_value_filter(predicate, tbl)
  local ret = {}
  for k, v in pairs(tbl) do
    if predicate(v) then
      ret[k] = v
    end
  end
  return vim.tbl_keys(ret)
end

---Create the `:MoveLsp` command
function M.create_move_lsp_command()
  vim.api.nvim_create_user_command(move_lsp_cmd_name, move_lsp, {
    nargs = '+',
    range = true,
    bang = true,
    desc = 'Interacts with the move-analyzer LSP client',
    complete = function(arg_lead, cmdline, _)
      local commands = cmdline:match("^['<,'>]*" .. move_lsp_cmd_name .. '!') ~= nil
          -- bang!
          and tbl_keys_by_value_filter(function(command)
            return command.bang == true
          end, movelsp_command_tbl)
        or vim.tbl_keys(movelsp_command_tbl)
      local subcmd, subcmd_arg_lead = cmdline:match("^['<,'>]*" .. move_lsp_cmd_name .. '[!]*%s(%S+)%s(.*)$')
      if subcmd and subcmd_arg_lead and movelsp_command_tbl[subcmd] and movelsp_command_tbl[subcmd].complete then
        return movelsp_command_tbl[subcmd].complete(subcmd_arg_lead)
      end
      if cmdline:match("^['<,'>]*" .. move_lsp_cmd_name .. '[!]*%s+%w*$') then
        return vim.tbl_filter(function(command)
          return command:find(arg_lead) ~= nil
        end, commands)
      end
    end,
  })
end

--- Delete the `:MoveLsp` command
function M.delete_move_lsp_command()
  if vim.cmd[move_lsp_cmd_name] then
    pcall(vim.api.nvim_del_user_command, move_lsp_cmd_name)
  end
end

return M
