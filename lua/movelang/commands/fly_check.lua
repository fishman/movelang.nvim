local M = {}

local rl = require('movelang.move_analyzer')

---@alias movelang.flyCheckCommand 'run' | 'clear' | 'cancel'

---@param cmd movelang.flyCheckCommand
function M.fly_check(cmd)
  local params = cmd == 'run' and vim.lsp.util.make_text_document_params() or nil
  rl.notify('move-analyzer/' .. cmd .. 'Flycheck', params)
end

return M.fly_check
