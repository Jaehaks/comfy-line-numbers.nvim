-- this runs when the plugin in required
-- this will only run once as the module will be cached
-- clear the cache with the following command
-- `:lua package.loaded['plugin-template'] = nil`

local enabled = false

local DEFAULT_LABELS = {
  "1",
  "2",
  "3",
  "4",
  "5",
  "11",
  "12",
  "13",
  "14",
  "15",
  "21",
  "22",
  "23",
  "24",
  "25",
  "31",
  "32",
  "33",
  "34",
  "35",
  "41",
  "42",
  "43",
  "44",
  "45",
  "51",
  "52",
  "53",
  "54",
  "55",
  "111",
  "112",
  "113",
  "114",
  "115",
  "121",
  "122",
  "123",
  "124",
  "125",
  "131",
  "132",
  "133",
  "134",
  "135",
  "141",
  "142",
  "143",
  "144",
  "145",
  "151",
  "152",
  "153",
  "154",
  "155",
  "211",
  "212",
  "213",
  "214",
  "215",
  "221",
  "222",
  "223",
  "224",
  "225",
  "231",
  "232",
  "233",
  "234",
  "235",
  "241",
  "242",
  "243",
  "244",
  "245",
  "251",
  "252",
  "253",
  "254",
  "255",
}

local M = {
  config = {
    labels = DEFAULT_LABELS,
    up_key = 'k',
    down_key = 'j',
    hidden_file_types = { 'undotree' },
    hidden_buffer_types = { 'terminal', 'nofile' }
  }
}

--- check whether comfy line is applied to the buffer
---@param bufnr integer buffer id
local should_hide_numbers = function(bufnr)
  local filetype = vim.bo[bufnr].filetype
  local buftype = vim.bo[bufnr].buftype
  return vim.tbl_contains(M.config.hidden_file_types, filetype) or
       vim.tbl_contains(M.config.hidden_buffer_types, buftype)
end

--- main function to change line number from statuscolumn option
---@param absnum integer current absolute line number currently being rendered
---@param relnum integer current relative line number currently being rendered
M.comfy_line_get_label = function(absnum, relnum, width)
  if not enabled then
    return absnum
  end

  -- Check if relativenumber is enabled (respects nvim-numbertoggle)
  if not vim.wo.relativenumber then
    return string.format("%" .. width .. "d", absnum)
  end

  if relnum == 0 then
    -- Pad current line number to match width
    return string.format("%" .. width .. "d", absnum)
  elseif relnum > 0 and relnum <= #M.config.labels then
    -- Pad label to consistent width
    return string.format("%" .. width .. "s", M.config.labels[relnum])
  else
    -- Pad absolute number to consistent width
    return string.format("%" .. width .. "d", absnum)
  end
end

--- set comfy line number to win
---@param win integer window id to change statuscolumn
local function set_comfy_status_column(win)
  local bufnr = vim.api.nvim_win_get_buf(win)
  if should_hide_numbers(bufnr) then return end

  -- Calculate and set consistent width based on total lines
  -- Minimum 4 to fit longest custom labels (e.g., "1444")
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local width = math.max(4, #tostring(total_lines))
  vim.wo[win].numberwidth = width

  -- save original status column
  if vim.w[win].origin_statuscolumn == nil then
    vim.w[win].origin_statuscolumn = vim.wo[win].statuscolumn
  end

  -- if wrap line use "", (virtnum > 0)
  -- if not, use comfy_line_get_label
  -- width : Use numberwidth for consistent padding (set in update_status_column)
  local called = string.format('v:lua.require("comfy-line-numbers").comfy_line_get_label(v:lnum, v:relnum, %d)', width)
  local new_line_expr = string.format('%%%%{v:virtnum > 0 ? repeat(" ", %d) : %s}', width, called)
  local old_statuscolumn = vim.w[win].origin_statuscolumn
  vim.wo[win].statuscolumn = old_statuscolumn:gsub('%%l', new_line_expr)
end

--- restore status column depends on original user setting
---@param win integer window id
local function restore_status_column(win)
  if vim.w[win].origin_statuscolumn then
    vim.wo[win].statuscolumn = vim.w[win].origin_statuscolumn
    vim.w[win].origin_statuscolumn = nil
  end
end

--- update statuscolumn for entire windows
local function update_all_status_column(enable)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if enable then
      set_comfy_status_column(win)
    else
      restore_status_column(win)
    end
  end
end

--- enable comfy line numbering
function M.enable_line_numbers()
  if enabled then return end

  for index, label in ipairs(M.config.labels) do
    vim.keymap.set({ 'n', 'v', 'o' }, label .. M.config.up_key, index .. 'k', { noremap = true })
    vim.keymap.set({ 'n', 'v', 'o' }, label .. M.config.down_key, index .. 'j', { noremap = true })
  end

  enabled = true
  update_all_status_column(enabled)
end

--- disable comfy line numbering
function M.disable_line_numbers()
  if not enabled then return end

  for _, label in ipairs(M.config.labels) do
    pcall(vim.keymap.del, { 'n', 'v', 'o' }, label .. M.config.up_key)
    pcall(vim.keymap.del, { 'n', 'v', 'o' }, label .. M.config.down_key)
  end

  enabled = false
  update_all_status_column(enabled)
end

--- create autocmd for update all status column
local function create_auto_commands()
  local group = vim.api.nvim_create_augroup("ComfyLineNumbers", { clear = true })
  vim.api.nvim_create_autocmd({ "WinNew", "BufWinEnter", "BufEnter", "FileType" }, {
    group = group,
    pattern = "*",
    callback = function () update_all_status_column(enabled) end
  })
end

function M.setup(config)
  M.config = vim.tbl_deep_extend("force", M.config, config or {})

  vim.api.nvim_create_user_command(
    'ComfyLineNumbers',
    function(args)
      if args.args == "enable" then
        M.enable_line_numbers()
      elseif args.args == "disable" then
        M.disable_line_numbers()
      elseif args.args == "toggle" then
        if enabled then
          M.disable_line_numbers()
        else
          M.enable_line_numbers()
        end
      else
        vim.notify("Invalid argument.", vim.log.levels.WARN)
      end
    end,
    { nargs = 1 }
  )

  vim.opt.relativenumber = true
  create_auto_commands()
  M.enable_line_numbers()
end

return M
