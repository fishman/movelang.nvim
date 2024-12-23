local M = {}

local rl = require('movelang.move_analyzer')
local compat = require('movelang.compat')

local function get_params()
  return vim.lsp.util.make_position_params(0, nil)
end

local function handler(_, result, ctx)
  if result == nil or vim.tbl_isempty(result) then
    vim.api.nvim_out_write("Can't find parent module\n")
    return
  end

  local location = result

  if vim.islist(result) then
    location = result[1]
  end

  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if client then
    compat.show_document(location, client.offset_encoding)
  end
end

--- Sends the request to move-analyzer to get the parent modules location and open it
function M.parent_module()
  rl.buf_request(0, 'experimental/parentModule', get_params(), handler)
end

return M.parent_module
