local trans = require('movelang.neotest.trans')

---@type movelang.TestExecutor
---@diagnostic disable-next-line: missing-fields
local M = {}

---@param opts movelang.TestExecutor.Opts
M.execute_command = function(_, _, _, opts)
  ---@type movelang.TestExecutor.Opts
  opts = vim.tbl_deep_extend('force', { bufnr = 0 }, opts or {})
  if type(opts.runnable) ~= 'table' then
    vim.notify('movelang neotest executor called without a runnable. This is a bug!', vim.log.levels.ERROR)
  end
  local file = vim.api.nvim_buf_get_name(opts.bufnr)
  local pos_id = trans.get_position_id(file, opts.runnable)
  ---@diagnostic disable-next-line: undefined-field
  require('neotest').run.run(pos_id)
end

return M
