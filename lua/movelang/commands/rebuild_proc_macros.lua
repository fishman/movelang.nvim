local M = {}

---@param err string | nil
local function handler(err, _, _)
  if err then
    vim.notify('Error rebuilding proc macros: ' .. err)
    return
  end
end

local rl = require('movelang.move_analyzer')

--- Sends the request to move-analyzer rebuild proc macros
function M.rebuild_macros()
  rl.any_buf_request('move-analyzer/rebuildProcMacros', nil, handler)
end

return M.rebuild_macros
