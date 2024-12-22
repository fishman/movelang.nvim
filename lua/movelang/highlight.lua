local M = {}

-- Map LSP symbol kinds to highlight groups
---@type table<integer,string>
local symbol_highlights = {
  [1] = '@lsp.type.file', -- File
  [2] = '@lsp.type.module', -- Module
  [3] = '@lsp.type.namespace', -- Namespace
  [4] = '@lsp.type.package', -- Package
  [5] = '@lsp.type.class', -- Class
  [6] = '@lsp.type.method', -- Method
  [7] = '@lsp.type.property', -- Property
  [8] = '@lsp.type.field', -- Field
  [9] = '@lsp.type.constructor', -- Constructor
  [10] = '@lsp.type.enum', -- Enum
  [11] = '@lsp.type.interface', -- Interface
  [12] = '@lsp.type.function', -- Function
  [13] = '@lsp.type.variable', -- Variable
  [14] = '@lsp.type.constant', -- Constant
  [15] = '@string', -- String
  [16] = '@number', -- Number
  [17] = '@boolean', -- Boolean
  [18] = '@lsp.type.array', -- Array
  [19] = '@lsp.type.object', -- Object
  [20] = '@lsp.type.key', -- Key
  [21] = '@lsp.type.null', -- Null
  [22] = '@lsp.type.enumMember', -- EnumMember
  [23] = '@lsp.type.struct', -- Struct
  [24] = '@lsp.type.event', -- Event
  [25] = '@operator', -- Operator
  [26] = '@lsp.type.typeParameter', -- TypeParameter
}

-- Define fallback highlights if LSP groups aren't available
local function setup_highlights()
  local highlights = {
    ['@lsp.type.file'] = { link = 'Include' },
    ['@lsp.type.module'] = { link = 'Include' },
    ['@lsp.type.namespace'] = { link = 'Include' },
    ['@lsp.type.package'] = { link = 'Include' },
    ['@lsp.type.class'] = { link = 'Type' },
    ['@lsp.type.method'] = { link = 'Function' },
    ['@lsp.type.property'] = { link = 'Identifier' },
    ['@lsp.type.field'] = { link = 'Identifier' },
    ['@lsp.type.constructor'] = { link = 'Special' },
    ['@lsp.type.enum'] = { link = 'Type' },
    ['@lsp.type.interface'] = { link = 'Type' },
    ['@lsp.type.function'] = { link = 'Function' },
    ['@lsp.type.variable'] = { link = 'Identifier' },
    ['@lsp.type.constant'] = { link = 'Constant' },
    ['@string'] = { link = 'String' },
    ['@number'] = { link = 'Number' },
    ['@boolean'] = { link = 'Boolean' },
    ['@lsp.type.array'] = { link = 'Type' },
    ['@lsp.type.object'] = { link = 'Type' },
    ['@lsp.type.key'] = { link = 'Identifier' },
    ['@lsp.type.null'] = { link = 'Special' },
    ['@lsp.type.enumMember'] = { link = 'Constant' },
    ['@lsp.type.struct'] = { link = 'Structure' },
    ['@lsp.type.event'] = { link = 'Special' },
    ['@operator'] = { link = 'Operator' },
    ['@lsp.type.typeParameter'] = { link = 'TypeDef' },
  }

  -- Only set highlight if it doesn't already exist
  for group, settings in pairs(highlights) do
    if vim.fn.hlexists(group) == 0 then
      vim.api.nvim_set_hl(0, group, settings)
    end
  end
end

-- Apply highlights based on document symbols
local function apply_symbol_highlights(bufnr, symbols)
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)

  local ns_id = vim.api.nvim_create_namespace('MoveSymbolHighlight')

  local function process_symbol(symbol)
    local highlight_group = symbol_highlights[symbol.kind]
    if highlight_group then
      local range = symbol.range
      local start_line = range.start.line
      local start_char = range.start.character
      local end_line = range['end'].line
      local end_char = range['end'].character

      vim.api.nvim_buf_add_highlight(bufnr, ns_id, highlight_group, start_line, start_char, end_char)
    end

    if symbol.children then
      for _, child in ipairs(symbol.children) do
        process_symbol(child)
      end
    end
  end

  for _, symbol in ipairs(symbols) do
    process_symbol(symbol)
  end
end

-- Request and apply document symbols
local function update_highlights(bufnr)
  local params = { textDocument = vim.lsp.util.make_text_document_params() }

  vim.lsp.buf_request(bufnr, 'textDocument/documentSymbol', params, function(err, result, _, _)
    if err or not result then
      return
    end
    apply_symbol_highlights(bufnr, result)
  end)
end

function M.setup()
  setup_highlights()

  -- Set up autocommands to update highlights
  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.server_capabilities.documentSymbolProvider then
        -- Update highlights when buffer is loaded or changed
        local group = vim.api.nvim_create_augroup('MoveSymbolHighlight', { clear = true })
        vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'TextChanged', 'InsertLeave' }, {
          group = group,
          buffer = args.buf,
          callback = function()
            update_highlights(args.buf)
          end,
        })

        -- Initial highlight
        update_highlights(args.buf)
      end
    end,
  })
end

return M
