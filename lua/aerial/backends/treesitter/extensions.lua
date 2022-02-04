-- This file is used by the markdown backend as well.
-- We pcall(require) so it doesn't error when nvim-treesitter isn't installed.
local _, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
local _, utils = pcall(require, "nvim-treesitter.utils")
local M = {}

local default_methods = {
  get_parent = function(stack, match, node)
    for i = #stack, 1, -1 do
      local last_node = stack[i].node
      if ts_utils.is_parent(last_node, node) then
        return stack[i].item, last_node, i
      else
        table.remove(stack, i)
      end
    end
    return nil, nil, 0
  end,
  postprocess = function(bufnr, item, match) end,
  postprocess_symbols = function(bufnr, items) end,
}

setmetatable(M, {
  __index = function()
    return default_methods
  end,
})

local function get_line_len(bufnr, lnum)
  return vim.api.nvim_strwidth(vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1])
end

local function set_end_range(bufnr, items, last_line)
  if not items then
    return
  end
  if not last_line then
    last_line = vim.api.nvim_buf_line_count(bufnr)
  end
  local prev = nil
  for _, item in ipairs(items) do
    if prev then
      prev.end_lnum = item.lnum - 1
      prev.end_col = get_line_len(bufnr, prev.end_lnum)
      set_end_range(bufnr, prev.children, prev.end_lnum)
    end
    prev = item
  end
  prev.end_lnum = last_line
  prev.end_col = get_line_len(bufnr, last_line)
  set_end_range(bufnr, prev.children, last_line)
end

M.markdown = {
  get_parent = function(stack, match, node)
    local level_node = (utils.get_at_path(match, "level") or {}).node
    -- Parse the level out of e.g. atx_h1_marker
    local level = tonumber(string.sub(level_node:type(), 6, 6)) - 1
    for i = #stack, 1, -1 do
      if stack[i].item.level < level or stack[i].node == node then
        return stack[i].item, stack[i].node, level
      else
        table.remove(stack, i)
      end
    end
    return nil, nil, level
  end,
  postprocess = function(bufnr, item, match)
    -- Strip leading whitespace
    item.name = string.gsub(item.name, "^%s*", "")
    return true
  end,
  postprocess_symbols = function(bufnr, items)
    set_end_range(bufnr, items)
  end,
}

M.rust = {
  postprocess = function(bufnr, item, match)
    if item.kind == "Class" then
      local trait_node = (utils.get_at_path(match, "trait") or {}).node
      local type = (utils.get_at_path(match, "rust_type") or {}).node
      local name = ts_utils.get_node_text(type, bufnr)[1] or "<parse error>"
      if trait_node then
        local trait = ts_utils.get_node_text(trait_node, bufnr)[1] or "<parse error>"
        name = string.format("%s > %s", name, trait)
      end
      item.name = name
    end
  end,
}

M.ruby = {
  postprocess = function(bufnr, item, match)
    local method = (utils.get_at_path(match, "method") or {}).node
    if method then
      local fn = ts_utils.get_node_text(method, bufnr)[1] or "<parse error>"
      if fn == "it" or fn == "describe" then
        item.name = fn .. " " .. item.name
      end
    end
  end,
}

M.lua = {
  postprocess = function(bufnr, item, match)
    local method = (utils.get_at_path(match, "method") or {}).node
    if method then
      local fn = ts_utils.get_node_text(method, bufnr)[1] or "<parse error>"
      if fn == "it" or fn == "describe" then
        item.name = fn .. " " .. string.sub(item.name, 2, string.len(item.name) - 1)
      end
    end
  end,
}

M.javascript = {
  postprocess = function(bufnr, item, match)
    local method = (utils.get_at_path(match, "method") or {}).node
    local modifier = (utils.get_at_path(match, "modifier") or {}).node
    local string = (utils.get_at_path(match, "string") or {}).node
    if method and string then
      local fn = ts_utils.get_node_text(method, bufnr)[1] or "<parse error>"
      if modifier then
        fn = fn .. "." .. (ts_utils.get_node_text(modifier, bufnr)[1] or "<parse error>")
      end
      local str = ts_utils.get_node_text(string, bufnr)[1] or "<parse error>"
      item.name = fn .. " " .. str
    end
  end,
}

local function c_postprocess(bufnr, item, match)
  local root = (utils.get_at_path(match, "root") or {}).node
  if root then
    while
      root
      and not vim.tbl_contains(
        { "identifier", "field_identifier", "qualified_identifier" },
        root:type()
      )
    do
      -- Search the declarator downwards until you hit the identifier
      root = root:field("declarator")[1]
    end
    item.name = ts_utils.get_node_text(root, bufnr)[1] or "<parse error>"
  end
end

M.c = {
  postprocess = c_postprocess,
}
M.cpp = {
  postprocess = c_postprocess,
}

M.rst = {
  postprocess_symbols = function(bufnr, items)
    set_end_range(bufnr, items)
  end,
}

for _, lang in pairs(M) do
  setmetatable(lang, { __index = default_methods })
end

return M
