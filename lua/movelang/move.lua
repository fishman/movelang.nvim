local move = {}

---@param file_name string
---@return string | nil root_dir
function move.get_root_dir(file_name)
  local path = vim.fs.dirname(file_name)
  if not path then
    return nil
  end

  ---@diagnostic disable-next-line: missing-fields
  local move_toml = vim.fs.find({ 'Move.toml' }, {
    upward = true,
    path = path,
  })[1]

  return move_toml and vim.fs.dirname(move_toml) or nil
end

return move
