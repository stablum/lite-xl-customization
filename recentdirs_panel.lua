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

config.plugins.recentdirs_panel = common.merge({
  visible = true,
  max_visible_items = 8,
  max_tracked_items = 100,
}, config.plugins.recentdirs_panel)

local state = rawget(_G, "__recentdirs_panel_state")
if not state then
  state = {
    dirs = {},
    initialized = false,
    open_doc_wrapped = false,
    command_perform_wrapped = false,
    commands_added = false,
    view = nil,
    node = nil,
  }
  rawset(_G, "__recentdirs_panel_state", state)
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

local function dirname(path)
  if not path then
    return nil
  end

  return common.dirname(path)
end

local function trim_dirs()
  local max_dirs = config.plugins.recentdirs_panel.max_tracked_items or 100
  while #state.dirs > max_dirs do
    table.remove(state.dirs, #state.dirs)
  end
end

local function track_file(path)
  local encoded_path = common.home_encode(path)
  local dir = dirname(encoded_path)
  if not dir then
    return
  end

  insert_unique(state.dirs, dir)
  trim_dirs()
end

local function open_directory(path)
  local abs_path = common.home_expand(path)
  if type(system) == "table" and type(system.absolute_path) == "function" then
    abs_path = system.absolute_path(abs_path)
  end

  if type(system) == "table" and type(system.get_file_info) == "function" then
    local info = system.get_file_info(abs_path)
    if not info or info.type ~= "dir" then
      return false
    end
  end

  if abs_path == core.project_dir then
    return true
  end

  if type(core.open_folder_project) ~= "function" then
    return false
  end

  if type(core.confirm_close_docs) == "function" then
    core.confirm_close_docs(core.docs, function(dirpath)
      core.open_folder_project(dirpath)
    end, abs_path)
    return true
  end

  core.open_folder_project(abs_path)
  return true
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

local function get_treeview_content_leaf()
  local node = TreeView.node
  if node and node.type == "vsplit" and node.a then
    return get_bottom_leaf(node.a) or node.a
  end
  return node
end

local function set_panel_height(view, value)
  view.target_size = math.max(0, value)
  view.size.y = view.target_size
end

local function get_parent_split_for_view(view)
  local node = get_view_node(view)
  if not node then
    return nil, nil
  end

  local parent = node:get_parent_node(core.root_view.root_node)
  return node, parent
end

local function get_anchor_node_and_dir()
  local recent_files_state = rawget(_G, "__recentfiles_panel_state")
  if recent_files_state and recent_files_state.view then
    local node = get_view_node(recent_files_state.view)
    if node then
      return node, "up"
    end
  end

  local content_leaf = get_treeview_content_leaf()
  if content_leaf then
    return content_leaf, "down"
  end

  return TreeView.node, "down"
end

if not state.initialized then
  for _, path in ipairs(recent_files_module) do
    local dir = dirname(path)
    if dir then
      insert_unique(state.dirs, dir)
    end
  end
  trim_dirs()
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
        track_file(doc.abs_filename)
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
      state.dirs = {}
    end
    return result
  end
  state.command_perform_wrapped = true
end

local RecentDirsPanel = View:extend()

function RecentDirsPanel:new()
  RecentDirsPanel.super.new(self)
  self.context = "application"
  self.scrollable = true
  self.visible = config.plugins.recentdirs_panel.visible
  self.init_size = true
  self.target_size = 0
  self.hovered_index = nil
end

function RecentDirsPanel:get_name()
  return nil
end

function RecentDirsPanel:get_line_height()
  return style.font:get_height() + style.padding.y
end

function RecentDirsPanel:get_header_height()
  return self:get_line_height()
end

function RecentDirsPanel:get_visible_lines()
  return math.max(1, config.plugins.recentdirs_panel.max_visible_items or 8)
end

function RecentDirsPanel:get_scrollable_size()
  return self:get_header_height()
    + self:get_line_height() * math.max(1, #state.dirs)
    + style.padding.y
end

function RecentDirsPanel:set_target_size(axis, value)
  if axis == "y" then
    local node, parent = get_parent_split_for_view(self)
    if not node or not parent or parent.type ~= "vsplit" or parent.a ~= node then
      set_panel_height(self, value)
      return true
    end

    if core.root_view.dragged_divider ~= parent then
      set_panel_height(self, value)
      return true
    end

    local sibling_view = parent.b and parent.b.active_view
    if not sibling_view then
      set_panel_height(self, value)
      return true
    end

    local total_height = math.max(0, parent.size.y)
    local new_top = common.clamp(value, 0, total_height)
    local new_bottom

    if new_top < 1 then
      new_bottom = total_height
    else
      new_bottom = math.max(0, total_height - style.divider_size - new_top)
      if new_bottom < 1 then
        new_top = total_height
        new_bottom = 0
      end
    end

    set_panel_height(self, new_top)
    if type(sibling_view.set_target_size) == "function" then
      sibling_view:set_target_size("y", new_bottom)
    elseif type(sibling_view) == "table" and sibling_view.size then
      sibling_view.size.y = new_bottom
    end
    return true
  end
end

function RecentDirsPanel:toggle_visible()
  self.visible = not self.visible
  if self.visible and self.target_size <= 0 then
    self.target_size = self:get_header_height()
      + self:get_line_height() * self:get_visible_lines()
      + style.padding.y
  end
  core.redraw = true
end

function RecentDirsPanel:update()
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

  RecentDirsPanel.super.update(self)
end

function RecentDirsPanel:each_item()
  local ox, oy = self:get_content_offset()
  local line_h = self:get_line_height()
  local header_h = self:get_header_height()
  local count = math.max(1, #state.dirs)
  local x = ox + style.padding.x
  local w = self.size.x - 2 * style.padding.x
  local index = 0

  return function()
    index = index + 1
    if index > count then
      return
    end

    local y = oy + header_h + line_h * (index - 1)
    local text = state.dirs[index] or "(no recent directories yet)"
    return index, text, x, y, w, line_h
  end
end

function RecentDirsPanel:get_item_at(px, py)
  for index, text, x, y, w, h in self:each_item() do
    if px >= x and px <= x + w and py >= y and py <= y + h then
      return index, text, x, y, w, h
    end
  end
end

function RecentDirsPanel:draw()
  if not self.visible then
    return
  end

  self:draw_background(style.background2)

  local ox, oy = self:get_content_offset()
  local line_h = self:get_line_height()
  local header_text = "Recent Directories"
  if #state.dirs > 0 then
    header_text = header_text .. " (" .. tostring(#state.dirs) .. ")"
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

      local color = state.dirs[index] and style.text or style.dim
      renderer.draw_text(style.font, text, x, y + math.floor(style.padding.y / 2), color)
    end
  end

  self:draw_scrollbar()
end

function RecentDirsPanel:on_mouse_left()
  RecentDirsPanel.super.on_mouse_left(self)
  self.hovered_index = nil
end

function RecentDirsPanel:on_mouse_moved(px, py, dx, dy)
  if RecentDirsPanel.super.on_mouse_moved(self, px, py, dx, dy) then
    return true
  end

  local index = self:get_item_at(px, py)
  self.hovered_index = index
  return index ~= nil
end

function RecentDirsPanel:on_mouse_pressed(button, px, py, clicks)
  if not self.visible then
    return false
  end

  local caught = RecentDirsPanel.super.on_mouse_pressed(self, button, px, py, clicks)
  if caught then
    return caught
  end

  local index = self:get_item_at(px, py)
  if not index or not state.dirs[index] then
    return false
  end

  return open_directory(state.dirs[index])
end

if not state.commands_added then
  command.add(nil, {
    ["recentdirs-panel:toggle"] = function()
      if state.view then
        state.view:toggle_visible()
      end
    end,
    ["recentdirs-panel:clear"] = function()
      state.dirs = {}
    end,
  })

  state.commands_added = true
end

if state.view and core.root_view.root_node:get_node_for_view(state.view) then
  state.view.visible = config.plugins.recentdirs_panel.visible
  return state
end

state.view = RecentDirsPanel()
do
  local anchor_node, split_dir = get_anchor_node_and_dir()
  state.node = anchor_node:split(split_dir, state.view, { y = true }, { y = true })
end

return state
