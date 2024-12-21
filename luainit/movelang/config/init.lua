---@mod movelang.config plugin configuration
---
---@brief [[
---
---movelang is a filetype plugin, and does not need
---a `setup` function to work.
---
---To configure movelang, set the variable `vim.g.movelang`,
---which is a `MovelangOpts` table, in your neovim configuration.
---
---Example:
---
--->lua
------@type movelang.Opts
---vim.g.movelang = {
---   ---@type movelang.tools.Opts
---   tools = {
---     -- ...
---   },
---   ---@type movelang.lsp.ClientOpts
---   server = {
---     on_attach = function(client, bufnr)
---       -- Set keybindings, etc. here.
---     end,
---     default_settings = {
---       -- move-analyzer language server configuration
---       ['move-analyzer'] = {
---       },
---     },
---     -- ...
---   },
---   ---@type movelang.dap.Opts
---   dap = {
---     -- ...
---   },
--- }
---<
---
---Notes:
---
--- - `vim.g.movelang` can also be a function that returns a `movelang.Opts` table.
--- - `server.settings`, by default, is a function that looks for a `move-analyzer.json` file
---    in the project root, to load settings from it. It falls back to an empty table.
---
---@brief ]]

local config = {}

---@type movelang.Opts | fun():movelang.Opts | nil
vim.g.movelang = vim.g.movelang

---@class movelang.Opts
---@field tools? movelang.tools.Opts Plugin options
---@field server? movelang.lsp.ClientOpts Language server client options
---@field dap? movelang.dap.Opts Debug adapter options

---@class movelang.tools.Opts
---
---The executor to use for runnables/debuggables
---@field executor? movelang.Executor | movelang.executor_alias
---
---The executor to use for runnables that are tests / testables
---@field test_executor? movelang.Executor | movelang.test_executor_alias
---
---The executor to use for runnables that are crate test suites (--all-targets)
---@field crate_test_executor? movelang.Executor | movelang.test_executor_alias
---
---Function that is invoked when the LSP server has finished initializing
---@field on_initialized? fun(health:movelang.RAInitializedStatus, client_id:integer)
---
---Automatically call `MoveReloadWorkspace` when writing to a Move.toml file
---@field reload_workspace_from_move_toml? boolean
---@field hover_actions? movelang.hover-actions.Opts Options for hover actions
---@field code_actions? movelang.code-action.Opts Options for code actions
---
---Options applied to floating windows.
---See |api-win_config|.
---@field float_win_config? movelang.FloatWinConfig
---
---If set, overrides how to open URLs
---@field open_url? fun(url:string):nil
---
---@class movelang.Executor
---@field execute_command fun(cmd:string, args:string[], cwd:string|nil, opts?: movelang.ExecutorOpts)

---@class movelang.ExecutorOpts
---
---The buffer from which the executor was invoked.
---@field bufnr? integer

---@class movelang.FloatWinConfig
---@field auto_focus? boolean
---@field open_split? 'horizontal' | 'vertical'
---@see vim.lsp.util.open_floating_preview.Opts
---@see vim.api.nvim_open_win

---@alias movelang.executor_alias 'termopen' | 'quickfix' | 'toggleterm' | 'vimux'

---@alias movelang.test_executor_alias movelang.executor_alias | 'background' | 'neotest'

---@class movelang.hover-actions.Opts
---
---Whether to replace Neovim's built-in `vim.lsp.buf.hover` with hover actions.
---Default: `true`
---@field replace_builtin_hover? boolean

---@class movelang.code-action.Opts
---
---Text appended to a group action
---@field group_icon? string
---
---Whether to fall back to `vim.ui.select` if there are no grouped code actions.
---Default: `false`
---@field ui_select_fallback? boolean

---@alias movelang.lsp_server_health_status 'ok' | 'warning' | 'error'

---@class movelang.RAInitializedStatus
---@field health movelang.lsp_server_health_status

---@class movelang.crate-graph.Opts
---
---Backend used for displaying the graph.
---See: https://graphviz.org/docs/outputs/
---Defaults to `"x11"` if unset.
---@field backend? string
---
---Where to store the output. No output if unset.
---Relative path from `cwd`.
---@field output? string
---
---Override the enabled graphviz backends list, used for input validation and autocompletion.
---@field enabled_graphviz_backends? string[]
---
---Override the pipe symbol in the shell command.
---Useful if using a shell that is not supported by this plugin.
---@field pipe? string

---@class movelang.rustc.Opts
---
---The default edition to use if it cannot be auto-detected.
---See https://rustc-dev-guide.rust-lang.org/guides/editions.html.
---Default '2021'.
---@field default_edition? string

---@class movelang.lsp.ClientOpts
---
---Whether to automatically attach the LSP client.
---Defaults to `true` if the `move-analyzer` executable is found.
---@field auto_attach? boolean | fun(bufnr: integer):boolean
---
---Command and arguments for starting move-analyzer
---@field cmd? string[] | fun():string[]
---
---The directory to use for the attached LSP.
---Can be a function, which may return nil if no server should attach.
---The second argument contains the default implementation, which can be used for fallback behavior.
---@field root_dir? string | fun(filename: string, default: fun(filename: string):string|nil):string|nil
---
---Setting passed to move-analyzer.
---Defaults to a function that looks for a `move-analyzer.json` file or returns an empty table.
---See https://move-analyzer.github.io/manual.html#configuration.
---@field settings? table | fun(project_root:string|nil, default_settings: table):table
---
---Standalone file support (enabled by default).
---Disabling it may improve move-analyzer's startup time.
---@field standalone? boolean
---
---The path to the move-analyzer log file.
---@field logfile? string
---
---Whether to search (upward from the buffer) for move-analyzer settings in .vscode/settings json.
---If found, loaded settings will override configured options.
---Default: `true`
---@field load_vscode_settings? boolean
---
---Server status warning level to notify at.
---Default: 'error'
---@field status_notify_level? movelang.server.status_notify_level
---
---@see vim.lsp.ClientConfig

---@alias movelang.server.status_notify_level 'error' | 'warning' | movelang.disable

---@alias movelang.disable false

---@class movelang.dap.Opts
---
---Whether to autoload nvim-dap configurations when move-analyzer has attached?
---Default: `true`
---@field autoload_configurations? boolean
---
---Defaults to creating the `rt_lldb` adapter, which is a |movelang.dap.server.Config|
---if `codelldb` is detected, and a |movelang.dap.executable.Config|` if `lldb` is detected.
---Set to `false` to disable.
---@field adapter? movelang.dap.executable.Config | movelang.dap.server.Config | movelang.disable | fun():(movelang.dap.executable.Config | movelang.dap.server.Config | movelang.disable)
---
---Dap client configuration. Defaults to a function that looks for a `launch.json` file
---or returns a |movelang.dap.executable.Config| that launches the `rt_lldb` adapter.
---Set to `false` to disable.
---@field configuration? movelang.dap.client.Config | movelang.disable | fun():(movelang.dap.client.Config | movelang.disable)
---
---Accommodate dynamically-linked targets by passing library paths to lldb.
---Default: `true`.
---@field add_dynamic_library_paths? boolean | fun():boolean
---
---Whether to auto-generate a source map for the standard library.
---@field auto_generate_source_map? fun():boolean | boolean
---
---Whether to get Move types via initCommands (rustlib/etc/lldb_commands, lldb only).
---Default: `true`.
---@field load_rust_types? fun():boolean | boolean

---@alias movelang.dap.Command string

---@class movelang.dap.executable.Config
---
---The type of debug adapter.
---@field type movelang.dap.adapter.types.executable
---@field command string Default: `"lldb-vscode"`.
---@field args? string Default: unset.
---@field name? string Default: `"lldb"`.

---@class movelang.dap.server.Config
---@field type movelang.dap.adapter.types.server The type of debug adapter.
---@field host? string The host to connect to.
---@field port string The port to connect to.
---@field executable movelang.dap.Executable The executable to run
---@field name? string

---@class movelang.dap.Executable
---@field command string The executable.
---@field args string[] Its arguments.

---@alias movelang.dap.adapter.types.executable "executable"
---@alias movelang.dap.adapter.types.server "server"

---@class movelang.dap.client.Config: dap.Configuration
---@field type string The dap adapter to use
---@field name string
---@field request movelang.dap.config.requests.launch | movelang.dap.config.requests.attach | movelang.dap.config.requests.custom The type of dap session
---@field cwd? string Current working directory
---@field program? string Path to executable for most DAP clients
---@field args? string[] Optional args to DAP client, not valid for all client types
---@field env? movelang.EnvironmentMap Environmental variables
---@field initCommands? string[] Initial commands to run, `lldb` clients only
---
---Essential config values for `probe-rs` client, see https://probe.rs/docs/tools/debugger/
---@field coreConfigs? table

---@alias movelang.EnvironmentMap table<string, string[]>

---@alias movelang.dap.config.requests.launch "launch"
---@alias movelang.dap.config.requests.attach "attach"
---@alias movelang.dap.config.requests.custom "custom"

---For the heroes who want to use it.
---@param codelldb_path string Path to the codelldb executable
---@param liblldb_path string Path to the liblldb dynamic library
---@return movelang.dap.server.Config
function config.get_codelldb_adapter(codelldb_path, liblldb_path)
  return {
    type = 'server',
    port = '${port}',
    host = '127.0.0.1',
    executable = {
      command = codelldb_path,
      args = { '--liblldb', liblldb_path, '--port', '${port}' },
    },
  }
end

return config
