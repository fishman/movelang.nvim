local ui = require('movelang.ui')

local M = {}

---@return lsp_position_params
local function get_params()
  return vim.lsp.util.make_position_params()
end

---@type integer | nil
local latest_buf_id = nil

---@class movelang.RAMacroExpansionResult
---@field name string
---@field expansion string

-- parse the lines from result to get a list of the desirable output
-- Example:
-- // Recursive expansion of the eprintln macro
-- // ============================================

-- {
--   $crate::io::_eprint(std::fmt::Arguments::new_v1(&[], &[std::fmt::ArgumentV1::new(&(err),std::fmt::Display::fmt),]));
-- }
---@param result movelang.RAMacroExpansionResult
---@return string[]
local function parse_lines(result)
  local ret = {}

  local name = result.name
  local text = '// Recursive expansion of the ' .. name .. ' macro'
  table.insert(ret, '// ' .. string.rep('=', string.len(text) - 3))
  table.insert(ret, text)
  table.insert(ret, '// ' .. string.rep('=', string.len(text) - 3))
  table.insert(ret, '')

  local expansion = result.expansion
  for string in string.gmatch(expansion, '([^\n]+)') do
    table.insert(ret, string)
  end

  return ret
end

---@param result? movelang.RAMacroExpansionResult
local function handler(_, result)
  -- echo a message when result is nil (meaning no macro under cursor) and
  -- exit
  if result == nil then
    vim.notify('No macro under cursor!', vim.log.levels.INFO)
    return
  end

  -- check if a buffer with the latest id is already open, if it is then
  -- delete it and continue
  ui.delete_buf(latest_buf_id)

  -- create a new buffer
  latest_buf_id = vim.api.nvim_create_buf(false, true) -- not listed and scratch

  -- split the window to create a new buffer and set it to our window
  ui.split(true, latest_buf_id)

  -- set filetype to rust for syntax highlighting
  vim.bo[latest_buf_id].filetype = 'rust'
  -- write the expansion content to the buffer
  vim.api.nvim_buf_set_lines(latest_buf_id, 0, 0, false, parse_lines(result))

  -- make the new buffer smaller
  ui.resize(true, '-25')
end

local rl = require('movelang.move_analyzer')

--- Sends the request to move-analyzer to expand the macro under the cursor
function M.expand_macro()
  rl.buf_request(0, 'move-analyzer/expandMacro', get_params(), handler)
end

return M.expand_macro
