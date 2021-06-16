local data = require 'aerial.data'
local util = require 'aerial.util'
local config = require 'aerial.config'
local M = {}

-- Update the aerial buffer from cached symbols
M.update_aerial_buffer = function(bufnr)
  local aer_bufnr = util.get_aerial_buffer(bufnr)
  if aer_bufnr == -1 then
    return
  end
  local items = data.items_by_buf[bufnr]
  if items == nil then
    return
  end
  local max_len = 1

  -- Replace SymbolKind with abbreviations
  for _,item in ipairs(items) do
    item.text = string.gsub(item.text, item.kind, config.get_kind_abbr(item.kind), 1)
  end

  -- Calculate window width
  for _,item in ipairs(items) do
    local len = string.len(item.text)
    if len > max_len then
      max_len = len
    end
  end
  local width = math.min(config.get_max_width(), math.max(config.get_min_width(), max_len))
  util.set_width(aer_bufnr, width)

  -- Insert lines into buffer
  local lines = {}
  for _,item in ipairs(items) do
    table.insert(lines, util.rpad(item.text, width))
  end
  vim.api.nvim_buf_set_option(aer_bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(aer_bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(aer_bufnr, 'modifiable', false)
end

-- Update the highlighted lines in the aerial buffer
M.update_highlights = function(bufnr)
  local positions = data.positions_by_buf[bufnr]
  if positions == nil then
    return
  end
  local winids = {}
  local win_count = 0
  for k in pairs(positions) do
    local winnr = vim.fn.win_id2win(k)
    if winnr ~= 0 and vim.fn.winbufnr(k) == bufnr then
      win_count = win_count + 1
      table.insert(winids, k)
    end
  end
  local sortWinId = function(a, b)
    return vim.fn.win_id2win(a) < vim.fn.win_id2win(b)
  end
  table.sort(winids, sortWinId)
  local ns = vim.api.nvim_create_namespace('aerial')
  local aer_bufnr = util.get_aerial_buffer(bufnr)
  if aer_bufnr == -1 then
    return
  end
  vim.api.nvim_buf_clear_namespace(aer_bufnr, ns, 0, -1)
  local hl_width = math.floor(util.get_width(aer_bufnr) / win_count)
  local hl_mode = config.get_highlight_mode()

  if hl_mode == 'last' then
    local row = data.last_position_by_buf[bufnr]
    vim.api.nvim_buf_add_highlight(
      aer_bufnr,
      ns,
      config.get_highlight_group(),
      row - 1,
      0,
      -1)
    return
  end

  local start_hl = 0
  local end_hl = hl_width
  if hl_mode == 'full_width' then
    end_hl = -1
  end
  for i,winid in ipairs(winids) do
    -- To fix rounding errors when #windows doesn't divide evenly into the
    -- width, make sure the last highlight goes to the end
    if i == #winids then
      end_hl = -1
    end
    vim.api.nvim_buf_add_highlight(
      aer_bufnr,
      ns,
      config.get_highlight_group(),
      positions[winid] - 1,
      start_hl,
      end_hl)
    if hl_mode ~= 'full_width' then
      start_hl = end_hl
      end_hl = end_hl + hl_width
    end
  end
end

return M
