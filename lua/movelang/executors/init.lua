---@mod movelang.executors

local termopen = require('movelang.executors.termopen')
local quickfix = require('movelang.executors.quickfix')
local toggleterm = require('movelang.executors.toggleterm')
local vimux = require('movelang.executors.vimux')
local background = require('movelang.executors.background')
local neotest = require('movelang.executors.neotest')

---@type { [movelang.test_executor_alias]: movelang.Executor }
local M = {}

M.termopen = termopen
M.quickfix = quickfix
M.toggleterm = toggleterm
M.vimux = vimux
M.background = background
M.neotest = neotest

return M
