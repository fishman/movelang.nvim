vim.env.LAZY_STDPATH = '.repro'
load(vim.fn.system('curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua'))()

require('lazy.minit').repro {
  spec = {
    {
      'fishman/movelang',
      version = '^5',
      init = function()
        -- Configure movelang here
        vim.g.movelang = {}
      end,
      lazy = false,
    },
  },
}
