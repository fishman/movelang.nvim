local types = require('movelang.types.internal')
-- local move = require('movelang.move')
local config = require('movelang.config')
local executors = require('movelang.executors')
local os = require('movelang.os')
local server_config = require('movelang.config.server')

local MovelangConfig

---@class movelang.internal.RAInitializedStatus : movelang.RAInitializedStatus
---@field health movelang.lsp_server_health_status
---@field quiescent boolean inactive?
---@field message string | nil
---
---@param dap_adapter movelang.dap.executable.Config | movelang.dap.server.Config | movelang.disable
---@return boolean
local function should_enable_dap_config_value(dap_adapter)
  local adapter = types.evaluate(dap_adapter)
  if adapter == false then
    return false
  end
  return vim.fn.executable('sui') == 1
end

---@param adapter movelang.dap.server.Config | movelang.dap.executable.Config
local function is_codelldb_adapter(adapter)
  return adapter.type == 'server'
end

---@param adapter movelang.dap.server.Config | movelang.dap.executable.Config
local function is_lldb_adapter(adapter)
  return adapter.type == 'executable'
end

---@param type string
---@return movelang.dap.client.Config
local function load_dap_configuration(type)
  -- default
  ---@type movelang.dap.client.Config
  local dap_config = {
    name = 'Move debug client',
    type = type,
    request = 'launch',
    stopOnEntry = false,
  }
  if type == 'lldb' then
    ---@diagnostic disable-next-line: inject-field
    dap_config.runInTerminal = true
  end
  ---@diagnostic disable-next-line: different-requires
  local dap = require('dap')
  -- Load configurations from a `launch.json`.
  -- It is necessary to check for changes in the `dap.configurations` table, as
  -- `load_launchjs` does not return anything, it loads directly into `dap.configurations`.
  local pre_launch = vim.deepcopy(dap.configurations) or {}
  require('dap.ext.vscode').load_launchjs(nil, { lldb = { 'rust' }, codelldb = { 'rust' } })
  for name, configuration_entries in pairs(dap.configurations) do
    if pre_launch[name] == nil or not vim.deep_equal(pre_launch[name], configuration_entries) then
      -- `configurations` are tables of `configuration` entries
      -- use the first `configuration` that matches
      for _, entry in pairs(configuration_entries) do
        ---@cast entry movelang.dap.client.Config
        if entry.type == type then
          dap_config = entry
          break
        end
      end
    end
  end
  return dap_config
end

---@return movelang.Executor
local function get_test_executor()
  if package.loaded['movelang.neotest'] ~= nil then
    -- neotest has been set up with movelang as an adapter
    return executors.neotest
  end
  return executors.termopen
end

---@class movelang.Config
local MovelangDefaultConfig = {
  ---@class movelang.tools.Config
  tools = {

    --- how to execute terminal commands
    --- options right now: termopen / quickfix / toggleterm / vimux
    ---@type movelang.Executor
    executor = executors.termopen,

    ---@type movelang.Executor
    test_executor = get_test_executor(),

    --- callback to execute once move-analyzer is done initializing the workspace
    --- The callback receives one parameter indicating the `health` of the server: "ok" | "warning" | "error"
    ---@type fun(health:movelang.RAInitializedStatus, client_id:integer) | nil
    on_initialized = nil,

    --- automatically call MoveReloadWorkspace when writing to a Move.toml file.
    ---@type boolean
    reload_workspace_from_move_toml = true,

    --- options same as lsp hover
    ---@see vim.lsp.util.open_floating_preview
    ---@class movelang.hover-actions.Config
    hover_actions = {

      --- whether to replace Neovim's built-in `vim.lsp.buf.hover`.
      ---@type boolean
      replace_builtin_hover = true,
    },

    code_actions = {
      --- text appended to a group action
      ---@type string
      group_icon = ' ▶',

      --- whether to fall back to `vim.ui.select` if there are no grouped code actions
      ---@type boolean
      ui_select_fallback = false,
    },

    --- options same as lsp hover
    ---@see vim.lsp.util.open_floating_preview
    ---@see vim.api.nvim_open_win
    ---@type table Options applied to floating windows.
    float_win_config = {
      --- whether the window gets automatically focused
      --- default: false
      ---@type boolean
      auto_focus = false,

      --- whether splits opened from floating preview are vertical
      --- default: false
      ---@type 'horizontal' | 'vertical'
      open_split = 'horizontal',
    },

    ---@type fun(url:string):nil
    open_url = function(url)
      require('movelang.os').open_url(url)
    end,
  },

  --- all the opts to send to the LSP client
  --- these override the defaults set by rust-tools.nvim
  ---@class movelang.lsp.ClientConfig: vim.lsp.ClientConfig
  server = {
    ---@type lsp.ClientCapabilities
    capabilities = server_config.create_client_capabilities(),
    ---@type boolean | fun(bufnr: integer):boolean Whether to automatically attach the LSP client.
    ---Defaults to `true` if the `move-analyzer` executable is found.
    auto_attach = function(bufnr)
      if #vim.bo[bufnr].buftype > 0 then
        return false
      end
      local path = vim.api.nvim_buf_get_name(bufnr)
      if not os.is_valid_file_path(path) then
        return false
      end
      local cmd = types.evaluate(MovelangConfig.server.cmd)
      ---@cast cmd string[]
      local rs_bin = cmd[1]
      return vim.fn.executable(rs_bin) == 1
    end,
    ---@type string[] | fun():string[]
    cmd = function()
      return { 'move-analyzer', '--log-file', MovelangConfig.server.logfile }
    end,

    ---@type string | fun(filename: string, default: fun(filename: string):string|nil):string|nil
    root_dir = cargo.get_root_dir,

    --- standalone file support
    --- setting it to false may improve startup time
    ---@type boolean
    standalone = true,

    ---@type string The path to the move-analyzer log file.
    logfile = vim.fn.tempname() .. '-move-analyzer.log',

    ---@type table | (fun(project_root:string|nil, default_settings: table|nil):table) -- The move-analyzer settings or a function that creates them.
    settings = function(project_root, default_settings)
      return server_config.load_move_analyzer_settings(project_root, { default_settings = default_settings })
    end,

    --- @type table
    default_settings = {
      --- options to send to move-analyzer
      --- See: https://move-analyzer.github.io/manual.html#configuration
      --- @type table
      ['move-analyzer'] = {},
    },
    ---@type boolean Whether to search (upward from the buffer) for move-analyzer settings in .vscode/settings json.
    load_vscode_settings = true,
    ---@type movelang.server.status_notify_level
    status_notify_level = 'error',
  },

  --- debugging stuff
  --- @class movelang.dap.Config
  dap = {
    --- @type boolean Whether to autoload nvim-dap configurations when move-analyzer has attached?
    autoload_configurations = true,
    --- @type movelang.dap.executable.Config | movelang.dap.server.Config | movelang.disable | fun():(movelang.dap.executable.Config | movelang.dap.server.Config | movelang.disable)
    adapter = function()
      --- @type movelang.dap.executable.Config | movelang.dap.server.Config | movelang.disable
      local result = false
      local has_mason, mason_registry = pcall(require, 'mason-registry')
      if has_mason and mason_registry.is_installed('codelldb') then
        local codelldb_package = mason_registry.get_package('codelldb')
        local mason_codelldb_path = vim.fs.joinpath(codelldb_package:get_install_path(), 'extension')
        local codelldb_path = vim.fs.joinpath(mason_codelldb_path, 'adapter', 'codelldb')
        local liblldb_path = vim.fs.joinpath(mason_codelldb_path, 'lldb', 'lib', 'liblldb')
        local shell = require('movelang.shell')
        if shell.is_windows() then
          codelldb_path = codelldb_path .. '.exe'
          liblldb_path = vim.fs.joinpath(mason_codelldb_path, 'lldb', 'bin', 'liblldb.dll')
        else
          liblldb_path = liblldb_path .. (shell.is_macos() and '.dylib' or '.so')
        end
        result = config.get_codelldb_adapter(codelldb_path, liblldb_path)
      elseif vim.fn.executable('codelldb') == 1 then
        ---@cast result movelang.dap.server.Config
        result = {
          type = 'server',
          host = '127.0.0.1',
          port = '${port}',
          executable = {
            command = 'codelldb',
            args = { '--port', '${port}' },
          },
        }
      else
        local has_lldb_dap = vim.fn.executable('lldb-dap') == 1
        local has_lldb_vscode = vim.fn.executable('lldb-vscode') == 1
        if not has_lldb_dap and not has_lldb_vscode then
          return result
        end
        local command = has_lldb_dap and 'lldb-dap' or 'lldb-vscode'
        ---@cast result movelang.dap.executable.Config
        result = {
          type = 'executable',
          command = command,
          name = 'lldb',
        }
      end
      return result
    end,
    --- Accommodate dynamically-linked targets by passing library paths to lldb.
    ---@type boolean | fun():boolean
    add_dynamic_library_paths = function()
      return should_enable_dap_config_value(MovelangConfig.dap.adapter)
    end,
    --- Auto-generate a source map for the standard library.
    ---@type boolean | fun():boolean
    auto_generate_source_map = function()
      return should_enable_dap_config_value(MovelangConfig.dap.adapter)
    end,
    --- Get Move types via initCommands (rustlib/etc/lldb_commands).
    ---@type boolean | fun():boolean
    load_rust_types = function()
      if not should_enable_dap_config_value(MovelangConfig.dap.adapter) then
        return false
      end
      local adapter = types.evaluate(MovelangConfig.dap.adapter)
      ---@cast adapter movelang.dap.executable.Config | movelang.dap.server.Config | movelang.disable
      return adapter ~= false and is_lldb_adapter(adapter)
    end,
    --- @type movelang.dap.client.Config | movelang.disable | fun():(movelang.dap.client.Config | movelang.disable)
    configuration = function()
      local ok, _ = pcall(require, 'dap')
      if not ok then
        return false
      end
      local adapter = types.evaluate(MovelangConfig.dap.adapter)
      ---@cast adapter movelang.dap.executable.Config | movelang.dap.server.Config | movelang.disable
      if adapter == false then
        return false
      end
      ---@cast adapter movelang.dap.executable.Config | movelang.dap.server.Config
      local type = is_codelldb_adapter(adapter) and 'codelldb' or 'lldb'
      return load_dap_configuration(type)
    end,
  },
  -- debug info
  was_g_movelang_sourced = vim.g.movelang ~= nil,
}
local movelang = vim.g.movelang or {}
local opts = type(movelang) == 'function' and movelang() or movelang

---@type movelang.Config
MovelangConfig = vim.tbl_deep_extend('force', {}, MovelangDefaultConfig, opts)

-- Override user dap.adapter config in a backward compatible way
if opts.dap and opts.dap.adapter then
  local user_adapter = opts.dap.adapter
  local default_adapter = types.evaluate(MovelangConfig.dap.adapter)
  if
    type(user_adapter) == 'table'
    and type(default_adapter) == 'table'
    and user_adapter.type == default_adapter.type
  then
    ---@diagnostic disable-next-line: inject-field
    MovelangConfig.dap.adapter = vim.tbl_deep_extend('force', default_adapter, user_adapter)
  elseif user_adapter ~= nil then
    ---@diagnostic disable-next-line: inject-field
    MovelangConfig.dap.adapter = user_adapter
  end
end

local check = require('movelang.config.check')
local ok, err = check.validate(MovelangConfig)
if not ok then
  vim.notify('movelang: ' .. err, vim.log.levels.ERROR)
end

return MovelangConfig
