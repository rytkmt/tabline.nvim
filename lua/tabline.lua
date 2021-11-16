local M = {}

local term = require("tabline.term")

M.options = {
  no_name = "[No Name]",
  component_left = "",
  component_right = "",
  section_left = "",
  section_right = "",
}
M.total_tab_length = 6

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
  local line = ""
  line = line .. self:separator() .. self:hl() .. "%" .. self.tabnr .. "@TablineSwitchTab@" .. " " .. self.name .. "%T"
  return line
end

function Tab:separator()
  local hl = ""
  if self.current and self.first then
    hl = "%#tabline_current_to_none#" .. self.options.section_right
  elseif self.first then
    hl = "%#tabline_inactive_to_none#" .. self.options.section_right
  elseif self.aftercurrent then
    hl = "%#tabline_inactive_to_current#" .. self.options.section_right
  elseif self.current then
    hl = "%#tabline_current_to_inactive#" .. self.options.section_right
  else
    hl = "%#tabline_current_to_inactive#" .. self.options.component_right
  end
  return hl
end

function Tab:hl()
  if self.current then
    return "%#tabline_current_buffer#"
  else
    return "%#tabline_inactive_buffer#"
  end
end

function Tab:len()
  local margin = 1
  return vim.fn.strchars(" " .. self.name) + margin
end

function M.format_tabs(tabs, max_length)
  if max_length == nil then
    max_length = math.floor(vim.o.columns / 3)
  end
  local line = ""
  local total_length = 0
  local current
  for i, tab in pairs(tabs) do
    if tab.current then
      current = i
    end
  end
  local current_tab = tabs[current]
  if current_tab == nil then
    local t = Tab:new({ tabnr = vim.fn.tabpagenr() })
    t.current = true
    t.last = true
    total_length = t:len()
    line = t:render()
  else
    line = line .. current_tab:render()
    total_length = current_tab:len()
    local i = 0
    local before, after
    while true do
      i = i + 1
      before = tabs[current - i]
      after = tabs[current + i]
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
      if before ~= nil then
        line = "%#tabline_inactive_to_none#" .. M.options.section_right .. "%#tabline_inactive_buffer#" .. "..." .. line
      end
      if after ~= nil and i == 1 then
        line = line .. "%#tabline_inactive_to_current#" .. M.options.section_right .. "%#tabline_inactive_buffer#" .. "..."
      elseif after ~= nil then
        line = line .. "%#tabline_current_to_inactive#" .. M.options.component_right .. "%#tabline_inactive_buffer#" .. "..."
      end
    end
  end
  M.total_tab_length = total_length
  if M.options.always_show_tabs then
    line = "%=%#TabLineFill#%999X" .. line
  elseif #tabs == 1 and tabs[1].name ~= "1 " then
    line = "%=%#TabLineFill#%999X" .. line
  elseif #tabs > 1 then
    line = "%=%#TabLineFill#%999X" .. line
  else
    line = "%=%#TabLineFill#%999X"
    M.total_tab_length = 0
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
  self.modified_icon = self.modified and " " or ""
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
  else
    self.icon = ""
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
  local margin = 2
  return vim.fn.strchars(" " .. " " .. " " .. self.name .. " " .. self.modified_icon .. " ") + margin
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

function Buffer:render()
  local line = self:hl()
    .. "%"
    .. self.bufnr
    .. "@TablineSwitchBuffer@"
    .. " "
    .. self.icon
    .. " "
    .. self.name
    .. " "
    .. self.modified_icon
  if M.options.show_bufnr then
    line = line .. "[" .. self.bufnr .. "] "
  end
  line = line .. "%T" .. self:separator()
  return line
end

function Buffer:separator()
  local hl = ""
  if self.current and self.last then
    hl = "%#tabline_current_to_none#" .. self.options.section_left
  elseif self.last then
    hl = "%#tabline_inactive_to_none#" .. self.options.section_left
  elseif self.beforecurrent then
    hl = "%#tabline_inactive_to_current#" .. self.options.section_left
  elseif self.current then
    hl = "%#tabline_current_to_inactive#" .. self.options.section_left
  else
    hl = "%#tabline_current_to_inactive#" .. self.options.component_left
  end
  return hl
end

function Buffer:window_count()
  local nwins = vim.fn.bufwinnr(self.bufnr)
  return nwins > 1 and "(" .. nwins .. ") " or ""
end

function M.format_buffers(buffers, max_length)
  if max_length == nil then
    max_length = math.max(vim.o.columns * 2 / 3, vim.o.columns - M.total_tab_length)
  else
    max_length = math.min(math.floor(vim.o.columns * max_length / 100), vim.o.columns - M.total_tab_length)
  end

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
        line = "%#tabline_inactive_buffer#..." .. "%#tabline_inactive_to_current#" .. M.options.section_left .. line
      elseif before ~= nil then
        line = "%#tabline_inactive_buffer#..." .. M.options.component_left .. line
      end
      if after ~= nil then
        line = line .. "..." .. "%#tabline_inactive_to_none#" .. M.options.section_left .. "%#tabline_none#"
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
  line = M.format_buffers(buffers, M.options.max_bufferline_percent)
  return line
end

function Buffer:hl()
  if self.current and self.modified then
    return "%#tabline_current_buffer_italic#"
  elseif self.current then
    return "%#tabline_current_buffer#"
  elseif self.modified then
    return "%#tabline_inactive_buffer_bold_italic#"
  else
    return "%#tabline_inactive_buffer_bold#"
  end
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

  local status, _ = pcall(require, "lualine.config")
  if status then
    local lc = require("lualine.config")
    local cs, ss
    if lc.config then
      cs = lc.config.options.component_separators
      ss = lc.config.options.section_separators
      M.options.component_left = cs[1]
      M.options.component_right = cs[2]
      M.options.section_left = ss[1]
      M.options.section_right = ss[2]
    elseif lc.get_config then
      cs = lc.get_config().options.component_separators
      ss = lc.get_config().options.section_separators
      M.options.component_left = cs.left
      M.options.component_right = cs.right
      M.options.section_left = ss.left
      M.options.section_right = ss.right
    else
      error("Unable to load separators from lualine")
    end
  end

  if opts.options.component_separators ~= nil then
    M.options.component_left = opts.options.component_separators[1]
    M.options.component_right = opts.options.component_separators[2]
  end

  if opts.options.section_separators ~= nil then
    M.options.section_left = opts.options.section_separators[1]
    M.options.section_right = opts.options.section_separators[2]
  end

  if opts.options.max_bufferline_percent then
    if opts.options.max_bufferline_percent <= 100 and opts.options.max_bufferline_percent >= 0 then
      M.options.max_bufferline_percent = opts.options.max_bufferline_percent
    end
  end

  if opts.options.always_show_tabs or opts.options.show_tabs_always then
    M.options.show_tabs_always = opts.options.show_tabs_always or opts.options.always_show_tabs
  else
    M.options.show_tabs_always = vim.g.tabline_show_tabs_always
  end

  if opts.options.show_bufnr then
    M.options.show_bufnr = opts.options.show_bufnr
  else
    M.options.show_bufnr = vim.g.tabline_show_bufnr
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

    command! -count TablineBufferPrevious         :lua require'tabline'.buffer_previous()

    function! TablineSwitchBuffer(bufnr, mouseclicks, mousebutton, modifiers)
      execute ":b " . a:bufnr
    endfunction

    function! TablineSwitchTab(tabnr, mouseclicks, mousebutton, modifiers)
      execute ":tab " . a:tabnr
    endfunction
  ]])

  function _G.tabline_buffers_tabs()
    local tabs = M.tabline_tabs(M.options)
    return M.tabline_buffers(M.options) .. tabs
  end

  if opts.enable then
    vim.o.tabline = "%!v:lua.tabline_buffers_tabs()"
    vim.o.showtabline = 2
  end
end

return M
