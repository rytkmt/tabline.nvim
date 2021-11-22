local M = {}

local term = require("tabline.term")

M.options = {
  no_name = "[No Name]",
  separate_thin = "│",
  separate_thick = "┃",
}
M.total_tab_length = 0

-- Use luatab as reference:
-- https://github.com/alvarosevilla95/luatab.nvim

function M.highlight(name, foreground, background, gui)
  local command = { "highlight", name }
  if foreground and foreground ~= "none" then
    table.insert(command, "guifg=" .. foreground)
  end
  if background and background ~= "none" then
    table.insert(command, "guibg=" .. background)
  end
  if gui and gui ~= "none" then
    table.insert(command, "gui=" .. gui)
  end
  vim.cmd(table.concat(command, " "))
end

function M.create_component_highlight_group(color, highlight_tag)
  if color.bg and color.fg then
    local highlight_group_name = table.concat({ "tabline", highlight_tag }, "_")
    M.highlight(highlight_group_name, color.fg, color.bg, color.gui)
    return highlight_group_name
  end
end

function M.extract_highlight_colors(color_group, scope)
  if vim.fn.hlexists(color_group) == 0 then
    return nil
  end
  local color = vim.api.nvim_get_hl_by_name(color_group, true)
  if color.background ~= nil then
    color.bg = string.format("#%06x", color.background)
    color.background = nil
  end
  if color.foreground ~= nil then
    color.fg = string.format("#%06x", color.foreground)
    color.foreground = nil
  end
  if scope then
    return color[scope]
  end
  return color
end

local Tab = {}

function Tab:new(tab)
  assert(tab.tabnr, "Cannot create Tab without tabnr")
  local newObj = { tabnr = tab.tabnr, options = tab.options }
  if newObj.options == nil then
    newObj.options = M.options
  end
  self.__index = self -- 4.
  newObj = setmetatable(newObj, self)
  newObj:get_props()
  return newObj
end

function M._new_tab_data(tabnr, data)
  if data == nil then
    data = vim.fn.json_decode(vim.g.tabline_tab_data)
  end
  if tabnr == nil then
    tabnr = vim.fn.tabpagenr()
  end
  if data[tabnr] == nil then
    data[tabnr] = { name = tabnr .. "" }
  end
  vim.g.tabline_tab_data = vim.fn.json_encode(data)
end

function Tab:get_props()
  local data
  data = vim.fn.json_decode(vim.g.tabline_tab_data)
  if data[self.tabnr] == nil then
    self.name = self.tabnr
    M._new_tab_data(self.tabnr)
  end
  data = vim.fn.json_decode(vim.g.tabline_tab_data)
  self.name = data[self.tabnr].name .. " "
  return self
end

function Tab:render()
  return self:hl() .. " " .. self.name
end

function Tab:hl()
  if self.current then
    return "%#tabline_current_tab#"
  else
    return "%#tabline_inactive_tab#"
  end
end

function Tab:len()
  local margin = 1
  return vim.fn.strchars(" " .. self.name) + margin
end

function M.format_tabs(tabs)
  local max_count = 5
  local line = ""
  local total_count = 1
  local current
  for i, tab in pairs(tabs) do
    if tab.current then
      current = i
    end
  end
  local current_tab = tabs[current]
  local before_over = false
  local after_over = false

  if current_tab == nil then
    local t = Tab:new({ tabnr = vim.fn.tabpagenr() })
    t.current = true
    t.last = true
    line = t:render()
  else
    line = line .. current_tab:render()
    local i = 0
    local before, after

    for i = 1, 5 do
      before = tabs[current - i]
      after = tabs[current + i]

      if before then
        if total_count < max_count then
          line = before:render() .. line
          total_count = total_count + 1
        else
          before_over = true
        end
      end

      if after then
        if total_count < max_count then
          line = line .. after:render()
          total_count = total_count + 1
        else
          after_over = true
        end
      end
    end
  end

  -- 余裕を持って5足す
  M.total_tab_length = (total_count * 3) + 5

  if before_over then
    line = "%#tabline_inactive_tab#..." .. line
    M.total_tab_length = M.total_tab_length + 3
  end
  if after_over then
    line = line .. "%#tabline_inactive_tab#..."
    M.total_tab_length = M.total_tab_length + 3
  end


  return line
end

local Buffer = {}

function Buffer:new(buffer)
  assert(buffer.bufnr, "Cannot create Buffer without bufnr")
  local newObj = { bufnr = buffer.bufnr, options = buffer.options }
  if newObj.options == nil then
    newObj.options = M.options
  end
  self.__index = self -- 4.
  newObj = setmetatable(newObj, self)
  newObj:get_props()
  return newObj
end

function Buffer:get_props()
  self.file = vim.fn.bufname(self.bufnr)
  self.filepath = vim.fn.expand("#" .. self.bufnr .. ":p:~")
  self.buftype = vim.fn.getbufvar(self.bufnr, "&buftype")
  self.filetype = vim.fn.getbufvar(self.bufnr, "&filetype")
  self.modified = vim.fn.getbufvar(self.bufnr, "&modified") == 1
  local dev, devhl
  local status, _ = pcall(require, "nvim-web-devicons")
  if not status then
    dev, devhl = "", ""
  elseif self.filetype == "TelescopePrompt" then
    dev, devhl = require("nvim-web-devicons").get_icon("telescope")
  elseif self.filetype == "fugitive" then
    dev, devhl = require("nvim-web-devicons").get_icon("git")
  elseif self.filetype == "vimwiki" then
    dev, devhl = require("nvim-web-devicons").get_icon("markdown")
  elseif self.buftype == "terminal" then
    dev, devhl = require("nvim-web-devicons").get_icon("zsh")
  elseif vim.fn.isdirectory(self.file) == 1 then
    dev, devhl = "", nil
  else
    dev, devhl = require("nvim-web-devicons").get_icon(self.file, vim.fn.expand("#" .. self.bufnr .. ":e"))
  end
  if dev and M.options.show_devicons then
    self.icon = dev
    self.icon_hl = devhl
  else
    self.icon = ""
    self.icon_hl = ""
  end
  self.name = self:name()
  return self
end

function split(s, delimiter)
  local result = {}
  for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
    table.insert(result, match)
  end
  return result
end

function Buffer:len()
  -- スペース、アイコン、スペース、名称、スペース
  local length = 3 + vim.fn.strchars(self.name) + 1
  if self.current then
    length = length + 2
  end
  return length
end

function Buffer:name()
  if self.buftype == "help" then
    return "help:" .. vim.fn.fnamemodify(self.file, ":t:r")
  elseif self.buftype == "quickfix" then
    return "quickfix"
  elseif self.filetype == "TelescopePrompt" then
    return "Telescope"
  elseif self.filetype == "packer" then
    return "Packer"
  elseif self.buftype == "terminal" then
    local mtch = string.match(split(self.file, " ")[1], "term:.*:(%a+)")
    return mtch ~= nil and mtch or vim.fn.fnamemodify(vim.env.SHELL, ":t")
  elseif vim.fn.isdirectory(self.file) == 1 then
    return vim.fn.fnamemodify(self.file, ":p:.")
  elseif self.file == "" then
    return "[No Name]"
  end

  return vim.fn.fnamemodify(self.file, ":p:t")
end

function Buffer:hl()
  if self.current and self.modified then
    return "%#tabline_current_modified_buffer#"
  elseif self.current then
    return "%#tabline_current_buffer#"
  elseif self.modified then
    return "%#tabline_inactive_modified_buffer#"
  else
    return "%#tabline_inactive_buffer#"
  end
end

function Buffer:render()
  local line = self:hl() .. " "

  if self.icon ~= "" then
    line = line .. self.icon .. " "
  end

  line = line .. self.name .. " "

  if self.current then
    line = "%#tabline_current_buffer# %#tabline_current_accent#▍" .. line
  end
  return line
end

function Buffer:window_count()
  local nwins = vim.fn.bufwinnr(self.bufnr)
  return nwins > 1 and "(" .. nwins .. ") " or ""
end

function M.format_buffers(buffers)
  -- ... の分も加算
  local max_length = vim.o.columns - M.total_tab_length - ((3 + 1) * 2)

  local line = ""
  local total_length = 0
  local complete = false
  local current
  for i, buffer in pairs(buffers) do
    if buffer.current then
      current = i
    end
  end
  local current_buffer = buffers[current]
  if current_buffer == nil then
    local b = Buffer:new({ bufnr = vim.fn.bufnr() })
    b.current = true
    b.last = true
    line = b:render()
  else
    line = line .. current_buffer:render()
    total_length = current_buffer:len()
    local i = 0
    local before, after
    while true do
      i = i + 1
      before = buffers[current - i]
      after = buffers[current + i]
      if before == nil and after == nil then
        break
      end
      if before then
        total_length = total_length + before:len()
      end
      if after then
        total_length = total_length + after:len()
      end
      if total_length > max_length then
        break
      end
      if before then
        line = before:render() .. line
      end
      if after then
        line = line .. after:render()
      end
    end
    if total_length > max_length then
      if before ~= nil and i == 1 then
        -- 起こる？
        line = "%#tabline_inactive_accent#@@@" .. line
      elseif before ~= nil then
        line = "%#tabline_inactive_accent#..." .. line
      end
      if after ~= nil then
        line = line .. "%#tabline_inactive_accent#...%#tabline_none#"
      end
    end
  end
  return line
end

function M._current_tab(tab)
  local data = vim.fn.json_decode(vim.g.tabline_tab_data)
  if tab == nil then
    return data[vim.fn.tabpagenr()]
  else
    data[vim.fn.tabpagenr()] = tab
    vim.g.tabline_tab_data = vim.fn.json_encode(data)
  end
end

local function contains(list, x)
  for i, v in pairs(list) do
    if v == x then
      return true
    end
  end
  return false
end

function M.tabline_buffers(opt)
  opt = M.options

  M.highlight_groups()

  M.initialize_tab_data(opt)
  local buffers = {}
  M.buffers = buffers
  local current_tab = M._current_tab()
  for b = 1, vim.fn.bufnr("$") do
    if vim.fn.buflisted(b) ~= 0 and vim.fn.getbufvar(b, "&buftype") ~= "quickfix" then
      local buffer = Buffer:new({ bufnr = b, options = opt })
      if vim.fn.bufwinid(b) ~= -1 then
        buffers[#buffers + 1] = buffer
      end
    end
  end

  local line = ""
  local current = 0
  for i, buffer in pairs(buffers) do
    if i == 1 then
      buffer.first = true
    end
    if i == #buffers and not M.options.show_last_separator then
      buffer.last = true
    end
    if buffer.bufnr == vim.fn.bufnr() then
      buffer.current = true
      current = i
    end
  end
  for i, buffer in pairs(buffers) do
    if i == current - 1 then
      buffer.beforecurrent = true
    end
    if i == current + 1 then
      buffer.aftercurrent = true
    end
  end
  line = M.format_buffers(buffers)
  return line
end


function M.initialize_tab_data(opt)
  local tabs = {}
  for t = 1, vim.fn.tabpagenr("$") do
    tabs[#tabs + 1] = Tab:new({ tabnr = t, options = opt })
  end
  local old_data = vim.fn.json_decode(vim.g.tabline_tab_data)
  local data = {}
  for t = 1, vim.fn.tabpagenr("$") do
    data[t] = old_data[t]
  end
  vim.g.tabline_tab_data = vim.fn.json_encode(data)
  return tabs
end

function M.tabline_tabs(opt)
  opt = M.options

  M.highlight_groups()
  local tabs = M.initialize_tab_data(opt)

  local line = ""
  local current = 0
  for i, tab in pairs(tabs) do
    if i == 1 then
      tab.first = true
    end
    if i == #tabs and not M.options.show_last_separator then
      tab.last = true
    end
    if tab.tabnr == vim.fn.tabpagenr() then
      tab.current = true
      current = i
    end
  end
  for i, tab in pairs(tabs) do
    if i == current - 1 then
      tab.beforecurrent = true
    end
    if i == current + 1 then
      tab.aftercurrent = true
    end
  end
  line = M.format_tabs(tabs)
  return line
end

function M.highlight_groups()
  local current_fg = M.extract_highlight_colors("tabline_current_buffer", "fg")
  local current_bg = M.extract_highlight_colors("tabline_current_buffer", "bg")
  local inactive_fg = M.extract_highlight_colors("tabline_inactive_buffer", "fg")
  local inactive_bg = M.extract_highlight_colors("tabline_inactive_buffer", "bg")
  -- local modified_accent = "#"

  M.create_component_highlight_group({ bg = inactive_bg, fg = inactive_bg }, "none")

  M.create_component_highlight_group({ bg = inactive_bg, fg = inactive_fg, gui = "bold" }, "inactive_buffer_bold")
  M.create_component_highlight_group({ bg = inactive_bg, fg = inactive_fg, gui = "italic" }, "inactive_buffer_italic")
  M.create_component_highlight_group({ bg = inactive_bg, fg = inactive_fg, gui = "bold,italic" }, "inactive_buffer_bold_italic")

  M.create_component_highlight_group({ bg = current_bg, fg = current_fg, gui = "bold" }, "current_buffer_bold")
  M.create_component_highlight_group({ bg = current_bg, fg = current_fg, gui = "italic" }, "current_buffer_italic")
  M.create_component_highlight_group({ bg = current_bg, fg = current_fg, gui = "bold,italic" }, "current_buffer_bold_italic")

  M.create_component_highlight_group({ bg = inactive_bg, fg = current_bg }, "current_to_inactive")
  M.create_component_highlight_group({ bg = current_bg, fg = inactive_bg }, "inactive_to_current")

  M.create_component_highlight_group({ bg = inactive_bg, fg = inactive_bg }, "inactive_to_none")
  M.create_component_highlight_group({ bg = inactive_bg, fg = inactive_bg }, "none_to_inactive")

  M.create_component_highlight_group({ bg = inactive_bg, fg = current_bg }, "current_to_none")
  M.create_component_highlight_group({ bg = current_bg, fg = inactive_bg }, "none_to_current")
end

function M.setup(opts)
  vim.cmd([[
    let g:tabline_tab_data = get(g:, "tabline_tab_data", '{}')
    let g:tabline_show_devicons = get(g:, "tabline_show_devicons", v:true)
    let g:tabline_show_bufnr = get(g:, "tabline_show_bufnr", v:false)
    let g:tabline_show_filename_only = get(g:, "tabline_show_filename_only", v:false)
    let g:tabline_show_last_separator = get(g:, "tabline_show_last_separator", v:false)
    let g:tabline_show_tabs_always = get(g:, "tabline_show_tabs_always", v:false)
  ]])

  if opts == nil then
    opts = { enable = true }
  end
  if opts.enable == nil then
    opts.enable = true
  end
  if opts.options == nil then
    opts.options = {}
  end

  if opts.options.show_devicons then
    M.options.show_devicons = opts.options.show_devicons
  else
    M.options.show_devicons = vim.g.tabline_show_devicons
  end

  if opts.options.show_last_separator then
    M.options.show_last_separator = opts.options.show_last_separator
  else
    M.options.show_last_separator = vim.g.tabline_show_last_separator
  end

  vim.cmd([[

    hi default link TablineCurrent         TabLineSel
    hi default link TablineActive          PmenuSel
    hi default link TablineHidden          TabLine
    hi default link TablineFill            TabLineFill

    hi default link tabline_current_buffer  lualine_a_normal
    hi default link tabline_inactive_buffer lualine_a_inactive

    hi tabline_current_buffer guibg=#333333 guifg=#FFFFFF
    hi tabline_current_modified_buffer guibg=#333333 guifg=#d48585
    hi tabline_inactive_buffer guibg=#000000 guifg=#666666
    hi tabline_inactive_modified_buffer guibg=#000000 guifg=#9b6161
    hi tabline_current_accent guibg=#333333 guifg=#5FABE9
    hi tabline_inactive_accent guibg=#000000 guifg=#5FABE9
    hi tabline_current_tab guibg=#ddbb88 guifg=#202020
    hi tabline_inactive_tab guibg=#202020 guifg=#ddbb88

    command! -count TablineBufferPrevious         :lua require'tabline'.buffer_previous()

    function! TablineSwitchBuffer(bufnr, mouseclicks, mousebutton, modifiers)
      execute ":b " . a:bufnr
    endfunction
  ]])

  function _G.tabline_buffers_tabs()
    local tabs = M.tabline_tabs(M.options)
    local buffers = M.tabline_buffers(M.options)
    return tabs .. buffers
  end

  if opts.enable then
    vim.o.tabline = "%!v:lua.tabline_buffers_tabs()"
    vim.o.showtabline = 2
  end
end

return M
