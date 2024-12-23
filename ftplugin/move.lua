---@type movelang.Config
local config = require('movelang.config.internal')
local compat = require('movelang.compat')

local function setup_move_parser()
  local parser_config = require('nvim-treesitter.parsers').get_parser_configs()

  -- Only register if not already registered
  if not parser_config.move then
    parser_config['move'] = {
      install_info = {
        url = 'https://github.com/fishman/tree-sitter-move',
        files = { 'src/parser.c' },
        branch = 'main',
      },
      filetype = 'move',
      maintainers = { '@fishman' },
    }
  end
end

if not vim.g.loaded_movelang then
  setup_move_parser()

  require('movelang.config.check').check_for_lspconfig_conflict(vim.schedule_wrap(function(warn)
    vim.notify_once(warn, vim.log.levels.WARN)
  end))
  vim.lsp.commands['move-analyzer.runSingle'] = function(command)
    local runnables = require('movelang.runnables')
    local cached_commands = require('movelang.cached_commands')
    ---@type movelang.RARunnable[]
    local ra_runnables = command.arguments
    local runnable = ra_runnables[1]
    local cargo_args = runnable.args.cargoArgs
    if #cargo_args > 0 and vim.startswith(cargo_args[1], 'test') then
      cached_commands.set_last_testable(1, ra_runnables)
    end
    cached_commands.set_last_runnable(1, ra_runnables)
    runnables.run_command(1, ra_runnables)
  end

  vim.lsp.commands['move-analyzer.gotoLocation'] = function(command, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if client then
      compat.show_document(command.arguments[1], client.offset_encoding)
    end
  end

  vim.lsp.commands['move-analyzer.showReferences'] = function(_)
    vim.lsp.buf.implementation()
  end

  vim.lsp.commands['move-analyzer.debugSingle'] = function(command)
    local overrides = require('movelang.overrides')
    local args = command.arguments[1].args
    overrides.sanitize_command_for_debugging(args.cargoArgs)
    local cached_commands = require('movelang.cached_commands')
    cached_commands.set_last_debuggable(args)
    local rt_dap = require('movelang.dap')
    ---@diagnostic disable-next-line: invisible
    rt_dap.start(args)
  end

  local commands = require('movelang.commands')
end

vim.g.loaded_movelang = true

local auto_attach = config.server.auto_attach
if type(auto_attach) == 'function' then
  local bufnr = vim.api.nvim_get_current_buf()
  auto_attach = auto_attach(bufnr)
end

if auto_attach then
  require('movelang.lsp').start()
end
