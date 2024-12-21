local config = require('movelang.config.internal')
local overrides = require('movelang.overrides')

local M = {}

---@return { textDocument: lsp_text_document, position: nil }
local function get_params()
  return {
    textDocument = vim.lsp.util.make_text_document_params(0),
    position = nil, -- get em all
  }
end

---@class movelang.RARunnable
---@field args movelang.RARunnableArgs
---@field label string
---@field location? movelang.RARunnableLocation

---@class movelang.RARunnableLocation
---@field targetRange lsp.Range
---@field targetSelectionRange lsp.Range

---@class movelang.RARunnableArgs
---@field workspaceRoot string
---@field cargoArgs string[]
---@field cargoExtraArgs? string[]
---@field executableArgs string[]

---@param option string
---@return string
local function prettify_test_option(option)
  for _, prefix in pairs { 'test-mod ', 'test ', 'cargo test -p ' } do
    if vim.startswith(option, prefix) then
      return option:sub(prefix:len() + 1, option:len()):gsub('%-%-all%-targets', '(all targets)') or option
    end
  end
  return option:gsub('%-%-all%-targets', '(all targets)') or option
end

---@param result movelang.RARunnable[]
---@param executableArgsOverride? string[]
---@param opts movelang.runnables.Opts
---@return string[]
local function get_options(result, executableArgsOverride, opts)
  local option_strings = {}

  for _, runnable in ipairs(result) do
    local str = runnable.label
      .. (
        executableArgsOverride and #executableArgsOverride > 0 and ' -- ' .. table.concat(executableArgsOverride, ' ')
        or ''
      )
    if opts.tests_only then
      str = prettify_test_option(str)
    end
    table.insert(option_strings, str)
  end

  return option_strings
end

---@alias movelang.CargoCmd 'cargo'

---@param runnable movelang.RARunnable
---@return string executable
---@return string[] args
---@return string | nil dir
function M.get_command(runnable)
  local args = runnable.args

  local dir = args.workspaceRoot

  local ret = vim.list_extend({}, args.cargoArgs or {})
  ret = vim.list_extend(ret, args.cargoExtraArgs or {})
  table.insert(ret, '--')
  ret = vim.list_extend(ret, args.executableArgs or {})

  return 'sui', ret, dir
end

---@param choice integer
---@param runnables movelang.RARunnable[]
---@return movelang.CargoCmd command build command
---@return string[] args
---@return string|nil dir
local function getCommand(choice, runnables)
  return M.get_command(runnables[choice])
end

---@param choice integer
---@param runnables movelang.RARunnable[]
function M.run_command(choice, runnables)
  -- do nothing if choice is too high or too low
  if not choice or choice < 1 or choice > #runnables then
    return
  end

  local opts = config.tools

  local command, args, cwd = getCommand(choice, runnables)
  if not cwd then
    return
  end

  opts.executor.execute_command(command, args, cwd)
end

---@param runnable movelang.RARunnable
---@return boolean
local function is_testable(runnable)
  ---@cast runnable movelang.RARunnable
  local cargoArgs = runnable.args and runnable.args.cargoArgs or {}
  return #cargoArgs > 0 and vim.startswith(cargoArgs[1], 'test')
end

---@param executableArgsOverride? string[]
---@param runnables movelang.RARunnable[]
---@return movelang.RARunnable[]
function M.apply_exec_args_override(executableArgsOverride, runnables)
  if type(executableArgsOverride) == 'table' and #executableArgsOverride > 0 then
    local unique_runnables = {}
    for _, runnable in pairs(runnables) do
      runnable.args.executableArgs = executableArgsOverride
      unique_runnables[vim.inspect(runnable)] = runnable
    end
    runnables = vim.tbl_values(unique_runnables)
  end
  return runnables
end

---@param executableArgsOverride? string[]
---@param opts movelang.runnables.Opts
---@return fun(_, result: movelang.RARunnable[])
local function mk_handler(executableArgsOverride, opts)
  ---@param runnables movelang.RARunnable[]
  return function(_, runnables)
    if runnables == nil then
      return
    end
    runnables = M.apply_exec_args_override(executableArgsOverride, runnables)
    if opts.tests_only then
      runnables = vim.tbl_filter(is_testable, runnables)
    end

    -- get the choice from the user
    local options = get_options(runnables, executableArgsOverride, opts)
    vim.ui.select(options, { prompt = 'Runnables', kind = 'rust-tools/runnables' }, function(_, choice)
      ---@cast choice integer
      M.run_command(choice, runnables)

      local cached_commands = require('movelang.cached_commands')
      if opts.tests_only then
        cached_commands.set_last_testable(choice, runnables)
      else
        cached_commands.set_last_runnable(choice, runnables)
      end
    end)
  end
end

---@param position lsp.Position
---@param targetRange lsp.Range
local function is_within_range(position, targetRange)
  return targetRange.start.line <= position.line and targetRange['end'].line >= position.line
end

---@param runnables movelang.RARunnable
---@return integer | nil choice
function M.get_runnable_at_cursor_position(runnables)
  ---@type lsp.Position
  local position = vim.lsp.util.make_position_params().position
  ---@type integer|nil, integer|nil
  local choice, fallback
  for idx, runnable in ipairs(runnables) do
    if runnable.location then
      local range = runnable.location.targetRange
      if is_within_range(position, range) then
        if vim.startswith(runnable.label, 'test-mod') then
          fallback = idx
        else
          choice = idx
          break
        end
      end
    end
  end
  return choice or fallback
end

local function mk_cursor_position_handler(executableArgsOverride)
  ---@param runnables movelang.RARunnable[]
  return function(_, runnables)
    if runnables == nil then
      return
    end
    runnables = M.apply_exec_args_override(executableArgsOverride, runnables)
    local choice = M.get_runnable_at_cursor_position(runnables)
    if not choice then
      vim.notify('No runnable targets found for the current position.', vim.log.levels.ERROR)
      return
    end
    M.run_command(choice, runnables)
    local cached_commands = require('movelang.cached_commands')
    if is_testable(runnables[choice]) then
      cached_commands.set_last_testable(choice, runnables)
    end
    cached_commands.set_last_runnable(choice, runnables)
  end
end

---@class movelang.runnables.Opts
---@field tests_only? boolean

---Sends the request to move-analyzer to get the runnables and handles them
---@param executableArgsOverride? string[]
---@param opts? movelang.runnables.Opts
function M.runnables(executableArgsOverride, opts)
  ---@type movelang.runnables.Opts
  opts = vim.tbl_deep_extend('force', { tests_only = false }, opts or {})
  vim.lsp.buf_request(0, 'experimental/runnables', get_params(), mk_handler(executableArgsOverride, opts))
end

function M.run(executableArgsOverride)
  vim.lsp.buf_request(0, 'experimental/runnables', get_params(), mk_cursor_position_handler(executableArgsOverride))
end

return M
