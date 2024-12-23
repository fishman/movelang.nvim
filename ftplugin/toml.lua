local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')
if fname ~= 'Move.toml' then
  return
end

local config = require('movelang.config.internal')
local ra = require('movelang.move_analyzer')
if config.tools.reload_workspace_from_cargo_toml then
  local group = vim.api.nvim_create_augroup('MovelangMoveReloadWorkspace', { clear = false })
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_clear_autocmds {
    buffer = bufnr,
    group = group,
  }
  vim.api.nvim_create_autocmd('BufWritePost', {
    buffer = vim.api.nvim_get_current_buf(),
    group = group,
    callback = function()
      if #ra.get_active_movelang_clients(nil) > 0 then
        vim.cmd.RustLsp { 'reloadWorkspace', mods = { silent = true } }
      end
    end,
  })
end
