-- mod-version:3

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local command = require "core.command"
local View = require "core.view"

local ok_tree, TreeView = pcall(require, "plugins.treeview")
if not ok_tree or not TreeView or not TreeView.node then
  return
end

local ok_recent, recent_files_module = pcall(require, "plugins.recentfiles")
if not ok_recent then
  return
end

config.plugins.recentfiles_panel = common.merge({
  visible = true,
  max_visible_items = 10,
}, config.plugins.recentfiles_panel)

local state = rawget(_G, "__recentfiles_panel_state")
if not state then
  state = {
    files = {},
    initialized = false,
    open_doc_wrapped = false,
    command_perform_wrapped = false,
    commands_added = false,
    view = nil,
    node = nil,
  }
  rawset(_G, "__recentfiles_panel_state", state)
end

local function insert_unique(t, v)
  local n = #t
  for i = 1, n do
    if t[i] == v then
      table.remove(t, i)
      break
    end
  end
  table.insert(t, 1, v)
end

local function trim_files()
  local max_files = 100
  if config.plugins.recentfiles and config.plugins.recentfiles.max_recent_files then
    max_files = config.plugins.recentfiles.max_recent_files
  end
  while #state.files > max_files do
    table.remove(state.files, #state.files)
  end
end

local function get_view_node(view)
  if not view then
    return nil
  end

  return core.root_view.root_node:get_node_for_view(view)
end

local function get_bottom_leaf(node)
  local leaf = node
  while leaf and leaf.type ~= "leaf" do
    leaf = leaf.b
  end
  return leaf
end

local function get_anchor_node_and_dir()
  local recent_dirs_state = rawget(_G, "__recentdirs_panel_state")
  if recent_dirs_state and recent_dirs_state.view then
    local recent_dirs_node = get_view_node(recent_dirs_state.view)
    if recent_dirs_node then
      return recent_dirs_node, "down"
    end
  end

  local bottom_leaf = get_bottom_leaf(TreeView.node.b)
  if bottom_leaf then
    return bottom_leaf, "up"
  end

  return TreeView.node, "down"
end

if not state.initialized then
  for i, path in ipairs(recent_files_module) do
    state.files[i] = path
  end
  state.initialized = true
end

if not state.open_doc_wrapped then
  local previous_open_doc = core.open_doc
  core.open_doc = function(filename)
    local doc = previous_open_doc(filename)
    if doc and doc.abs_filename then
      local file = io.open(doc.abs_filename, "r")
      if file then
        file:close()
        insert_unique(state.files, common.home_encode(doc.abs_filename))
        trim_files()
      end
    end
    return doc
  end
  state.open_doc_wrapped = true
end

if not state.command_perform_wrapped then
  local previous_command_perform = command.perform
  command.perform = function(cmd, ...)
    local result = previous_command_perform(cmd, ...)
    if cmd == "core:open-recent-file-clear" then
      state.files = {}
    end
    return result
  end
  state.command_perform_wrapped = true
end

local RecentFilesPanel = View:extend()

function RecentFilesPanel:new()
  RecentFilesPanel.super.new(self)
  self.context = "application"
  self.scrollable = true
  self.visible = config.plugins.recentfiles_panel.visible
  self.init_size = true
  self.target_size = 0
  self.hovered_index = nil
end

function RecentFilesPanel:get_name()
  return nil
end

function RecentFilesPanel:get_line_height()
  return style.font:get_height() + style.padding.y
end

function RecentFilesPanel:get_header_height()
  return self:get_line_height()
end

function RecentFilesPanel:get_visible_lines()
  return math.max(1, config.plugins.recentfiles_panel.max_visible_items or 10)
end

function RecentFilesPanel:get_scrollable_size()
  return self:get_header_height()
    + self:get_line_height() * math.max(1, #state.files)
    + style.padding.y
end

function RecentFilesPanel:set_target_size(axis, value)
  if axis == "y" then
    self.target_size = math.max(0, value)
    return true
  end
end

function RecentFilesPanel:toggle_visible()
  self.visible = not self.visible
  if self.visible and self.target_size <= 0 then
    self.target_size = self:get_header_height()
      + self:get_line_height() * self:get_visible_lines()
      + style.padding.y
  end
  core.redraw = true
end

function RecentFilesPanel:update()
  local dest_size = 0
  if self.visible then
    local default_size = self:get_header_height()
      + self:get_line_height() * self:get_visible_lines()
      + style.padding.y
    if self.target_size <= 0 then
      self.target_size = default_size
    end
    dest_size = self.target_size
  end

  if self.init_size then
    self.size.y = dest_size
    self.init_size = nil
  else
    self:move_towards(self.size, "y", dest_size)
  end

  RecentFilesPanel.super.update(self)
end

function RecentFilesPanel:each_item()
  local ox, oy = self:get_content_offset()
  local line_h = self:get_line_height()
  local header_h = self:get_header_height()
  local count = math.max(1, #state.files)
  local x = ox + style.padding.x
  local w = self.size.x - 2 * style.padding.x
  local index = 0

  return function()
    index = index + 1
    if index > count then
      return
    end

    local y = oy + header_h + line_h * (index - 1)
    local text = state.files[index] or "(no recent files yet)"
    return index, text, x, y, w, line_h
  end
end

function RecentFilesPanel:get_item_at(px, py)
  for index, text, x, y, w, h in self:each_item() do
    if px >= x and px <= x + w and py >= y and py <= y + h then
      return index, text, x, y, w, h
    end
  end
end

function RecentFilesPanel:draw()
  if not self.visible then
    return
  end

  self:draw_background(style.background2)

  local ox, oy = self:get_content_offset()
  local line_h = self:get_line_height()
  local header_text = "Recent Files"
  if #state.files > 0 then
    header_text = header_text .. " (" .. tostring(#state.files) .. ")"
  end

  common.draw_text(
    style.font,
    style.accent,
    header_text,
    "left",
    ox + style.padding.x,
    oy,
    self.size.x - 2 * style.padding.x,
    line_h
  )

  renderer.draw_rect(
    self.position.x,
    oy + self:get_header_height() - style.divider_size,
    self.size.x,
    style.divider_size,
    style.divider
  )

  local view_top = self.position.y
  local view_bottom = self.position.y + self.size.y

  for index, text, x, y, w, h in self:each_item() do
    if y + h >= view_top and y < view_bottom then
      if index == self.hovered_index then
        renderer.draw_rect(self.position.x, y, self.size.x, h, style.line_highlight)
      end

      local color = state.files[index] and style.text or style.dim
      renderer.draw_text(style.font, text, x, y + math.floor(style.padding.y / 2), color)
    end
  end

  self:draw_scrollbar()
end

function RecentFilesPanel:on_mouse_left()
  RecentFilesPanel.super.on_mouse_left(self)
  self.hovered_index = nil
end

function RecentFilesPanel:on_mouse_moved(px, py, dx, dy)
  if RecentFilesPanel.super.on_mouse_moved(self, px, py, dx, dy) then
    return true
  end

  local index = self:get_item_at(px, py)
  self.hovered_index = index
  return index ~= nil
end

function RecentFilesPanel:on_mouse_pressed(button, px, py, clicks)
  if not self.visible then
    return false
  end

  local caught = RecentFilesPanel.super.on_mouse_pressed(self, button, px, py, clicks)
  if caught then
    return caught
  end

  local index = self:get_item_at(px, py)
  if not index or not state.files[index] then
    return false
  end

  local abs_filename = common.home_expand(state.files[index])
  core.root_view:open_doc(core.open_doc(abs_filename))
  return true
end

if not state.commands_added then
  command.add(nil, {
    ["recentfiles-panel:toggle"] = function()
      if state.view then
        state.view:toggle_visible()
      end
    end,
    ["recentfiles-panel:clear"] = function()
      command.perform("core:open-recent-file-clear")
      state.files = {}
    end,
  })

  state.commands_added = true
end

if state.view and core.root_view.root_node:get_node_for_view(state.view) then
  state.view.visible = config.plugins.recentfiles_panel.visible
  return state
end

state.view = RecentFilesPanel()
do
  local anchor_node, split_dir = get_anchor_node_and_dir()
  state.node = anchor_node:split(split_dir, state.view, { y = true }, { y = true })
end

return state
