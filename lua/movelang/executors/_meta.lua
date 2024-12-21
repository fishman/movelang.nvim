error('Cannot import a meta module')

---@class movelang.TestExecutor: movelang.Executor
---@field execute_command fun(cmd:string, args:string[], cwd:string|nil, opts?: movelang.ExecutorOpts)

---@class movelang.TestExecutor.Opts: movelang.ExecutorOpts
---@field runnable? movelang.RARunnable
