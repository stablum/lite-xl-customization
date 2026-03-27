-- mod-version:3

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local command = require "core.command"
local Doc = require "core.doc"
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
  sort = false,
  edit_badge_hex_codes = { "2D58", "2E2C", "2E2B", "A4FD", "1F784" },
  edit_badge_color = { common.color "#00ff00" },
}, config.plugins.recentdirs_panel)

local state = rawget(_G, "__recentdirs_panel_state")
if not state then
  state = {
    dirs = {},
    initialized = false,
    managed_treeview_dir = nil,
    open_doc_wrapped = false,
    doc_save_wrapped = false,
    command_perform_wrapped = false,
    commands_added = false,
    view = nil,
    node = nil,
  }
  rawset(_G, "__recentdirs_panel_state", state)
end

local activity_state = rawget(_G, "__recent_panels_activity_state")
if not activity_state then
  activity_state = {
    edit_counter = 0,
    file_edit_order = {},
    dir_edit_order = {},
    doc_text_change_wrapped = false,
  }
  rawset(_G, "__recent_panels_activity_state", activity_state)
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

local function mark_recent_edit(path)
  if not path or path == "" then
    return
  end

  local encoded_path = common.home_encode(path)
  activity_state.edit_counter = activity_state.edit_counter + 1
  activity_state.file_edit_order[encoded_path] = activity_state.edit_counter

  local dir = dirname(encoded_path)
  if dir then
    activity_state.dir_edit_order[dir] = activity_state.edit_counter
  end
end

local function get_sorted_copy(items)
  local sorted = {}
  for i, item in ipairs(items) do
    sorted[i] = item
  end

  table.sort(sorted, function(a, b)
    local a_lower = a:lower()
    local b_lower = b:lower()
    if a_lower == b_lower then
      return a < b
    end
    return a_lower < b_lower
  end)

  return sorted
end

local function get_display_dirs()
  if config.plugins.recentdirs_panel.sort then
    return get_sorted_copy(state.dirs)
  end
  return state.dirs
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

local function remove_managed_treeview_dir()
  local managed_path = state.managed_treeview_dir
  if not managed_path or managed_path == core.project_dir then
    state.managed_treeview_dir = nil
    return
  end

  if type(core.remove_project_directory) == "function"
    and type(core.project_dir_by_name) == "function"
    and core.project_dir_by_name(managed_path)
  then
    core.remove_project_directory(managed_path)
  end

  state.managed_treeview_dir = nil
end

local function focus_treeview_directory(abs_path)
  TreeView.visible = true

  for item, _, y in TreeView:each_item() do
    if item.depth == 0 and item.abs_filename == abs_path then
      item.expanded = true
      TreeView:set_selection(item, y)
      core.redraw = true
      return true
    end
  end

  return false
end

local function open_directory(path)
  local abs_path = common.home_expand(path)
  if type(system) == "table" and type(system.absolute_path) == "function" then
    abs_path = system.absolute_path(abs_path)
  end
  abs_path = common.normalize_volume(abs_path) or abs_path

  if type(system) == "table" and type(system.get_file_info) == "function" then
    local info = system.get_file_info(abs_path)
    if not info or info.type ~= "dir" then
      return false
    end
  end

  if state.managed_treeview_dir and state.managed_treeview_dir ~= abs_path then
    remove_managed_treeview_dir()
  end

  if abs_path == core.project_dir then
    return focus_treeview_directory(abs_path)
  end

  local existing_dir = type(core.project_dir_by_name) == "function"
    and core.project_dir_by_name(abs_path)
    or nil

  if not existing_dir then
    if type(core.add_project_directory) ~= "function" then
      return false
    end

    core.add_project_directory(abs_path)
    state.managed_treeview_dir = abs_path
  elseif state.managed_treeview_dir == abs_path then
    state.managed_treeview_dir = abs_path
  end

  return focus_treeview_directory(abs_path)
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

local function split_path(path)
  local prefix, suffix = path:match("^(.*[/\\])([^/\\]+)$")
  if prefix and suffix then
    return prefix, suffix
  end
  return "", path
end

local function utf8_next_char_index(text, index)
  local byte = text:byte(index)
  if not byte then
    return nil
  end

  if byte < 0x80 then
    return index + 1
  end
  if byte >= 0xC2 and byte <= 0xDF then
    return index + 2
  end
  if byte >= 0xE0 and byte <= 0xEF then
    return index + 3
  end
  if byte >= 0xF0 and byte <= 0xF4 then
    return index + 4
  end

  return index + 1
end

local function utf8_char_starts(text)
  local starts = {}
  local index = 1

  while index <= #text do
    table.insert(starts, index)
    index = utf8_next_char_index(text, index)
  end

  return starts
end

local function truncate_left(font, text, max_width)
  if not text or text == "" or max_width <= 0 then
    return ""
  end

  if font:get_width(text) <= max_width then
    return text
  end

  local ellipsis = "..."
  if font:get_width(ellipsis) > max_width then
    return ""
  end

  local starts = utf8_char_starts(text)
  for i = #starts, 1, -1 do
    local candidate = ellipsis .. text:sub(starts[i])
    if font:get_width(candidate) <= max_width then
      return candidate
    end
  end

  return ellipsis
end

local function split_prefix_components(prefix)
  local separator = prefix:find("\\", 1, true) and "\\" or "/"
  local root = ""
  local rest = prefix

  if rest:match("^%a:[/\\]") then
    root = rest:sub(1, 3)
    rest = rest:sub(4)
  elseif rest:match("^~[/\\]") then
    root = rest:sub(1, 2)
    rest = rest:sub(3)
  elseif rest:match("^[/\\][/\\]") then
    root = separator .. separator
    rest = rest:sub(3)
  elseif rest:match("^[/\\]") then
    root = separator
    rest = rest:sub(2)
  end

  rest = rest:gsub("[/\\]+$", "")

  local components = {}
  for part in rest:gmatch("[^/\\]+") do
    table.insert(components, part)
  end

  return root, components, separator
end

local function join_prefix(root, components, separator)
  if #components == 0 then
    return root
  end

  local text = root
  for _, component in ipairs(components) do
    text = text .. component .. separator
  end
  return text
end

local function abbreviate_component(component)
  if component == "" then
    return component
  end

  local next_index = utf8_next_char_index(component, 1)
  if not next_index or next_index > #component then
    return component
  end

  return component:sub(1, next_index - 1)
end

local function compact_prefix(prefix, max_width)
  if prefix == "" or max_width <= 0 then
    return ""
  end

  if style.font:get_width(prefix) <= max_width then
    return prefix
  end

  local root, components, separator = split_prefix_components(prefix)
  if #components == 0 then
    return truncate_left(style.font, prefix, max_width)
  end

  local abbreviated = {}
  for i, component in ipairs(components) do
    abbreviated[i] = component
  end

  for i = 1, #components do
    abbreviated[i] = abbreviate_component(components[i])
    local candidate = join_prefix(root, abbreviated, separator)
    if style.font:get_width(candidate) <= max_width then
      return candidate
    end
  end

  for collapsed = 1, #components do
    local remaining = {}
    for i = collapsed + 1, #components do
      table.insert(remaining, components[i])
    end

    local candidate = root .. "..." .. separator .. join_prefix("", remaining, separator)
    if style.font:get_width(candidate) <= max_width then
      return candidate
    end
  end

  for collapsed = 1, #components do
    local remaining = {}
    for i = collapsed + 1, #components do
      table.insert(remaining, components[i])
    end

    local candidate = "..." .. separator .. join_prefix("", remaining, separator)
    if style.font:get_width(candidate) <= max_width then
      return candidate
    end
  end

  return truncate_left(style.font, prefix, max_width)
end

local function codepoint_to_utf8(codepoint)
  if not codepoint or codepoint < 0 or codepoint > 0x10FFFF then
    return nil
  end

  if codepoint >= 0xD800 and codepoint <= 0xDFFF then
    return nil
  end

  if codepoint <= 0x7F then
    return string.char(codepoint)
  end
  if codepoint <= 0x7FF then
    local b1 = 0xC0 + math.floor(codepoint / 0x40)
    local b2 = 0x80 + (codepoint % 0x40)
    return string.char(b1, b2)
  end
  if codepoint <= 0xFFFF then
    local b1 = 0xE0 + math.floor(codepoint / 0x1000)
    local b2 = 0x80 + (math.floor(codepoint / 0x40) % 0x40)
    local b3 = 0x80 + (codepoint % 0x40)
    return string.char(b1, b2, b3)
  end

  local b1 = 0xF0 + math.floor(codepoint / 0x40000)
  local b2 = 0x80 + (math.floor(codepoint / 0x1000) % 0x40)
  local b3 = 0x80 + (math.floor(codepoint / 0x40) % 0x40)
  local b4 = 0x80 + (codepoint % 0x40)
  return string.char(b1, b2, b3, b4)
end

local function hex_code_to_utf8(hex_code)
  if type(hex_code) == "number" then
    return codepoint_to_utf8(hex_code)
  end
  if type(hex_code) ~= "string" then
    return nil
  end

  local normalized = hex_code:match("^%s*(.-)%s*$")
  normalized = normalized:gsub("^U%+", "")
  local codepoint = tonumber(normalized, 16)
  return codepoint_to_utf8(codepoint)
end

local function get_edit_badge_glyphs(panel_config)
  local glyphs = {}
  local hex_codes = panel_config.edit_badge_hex_codes or {}

  for index = 1, 5 do
    glyphs[index] = hex_code_to_utf8(hex_codes[index]) or ""
  end

  return glyphs
end

local function get_edit_rank_lookup(paths, order_lookup)
  local ranked_paths = {}

  for _, path in ipairs(paths) do
    local order = order_lookup[path]
    if order then
      table.insert(ranked_paths, {
        path = path,
        order = order,
      })
    end
  end

  table.sort(ranked_paths, function(a, b)
    if a.order == b.order then
      return a.path < b.path
    end
    return a.order > b.order
  end)

  local rank_lookup = {}
  for index = 1, math.min(#ranked_paths, 5) do
    rank_lookup[ranked_paths[index].path] = index
  end

  return rank_lookup
end

local function get_badge_text(path, rank_lookup, glyphs)
  local rank = rank_lookup[path]
  if not rank then
    return ""
  end

  return glyphs[rank] or ""
end

local function get_path_colors(is_hovered)
  local panel_config = config.plugins.recentdirs_panel
  if is_hovered then
    return panel_config.hover_path_prefix_color
        or panel_config.path_prefix_color
        or style.text,
      panel_config.hover_path_suffix_color
        or panel_config.path_suffix_color
        or style.accent
  end

  return panel_config.path_prefix_color or style.dim,
    panel_config.path_suffix_color or style.text
end

local function draw_path_text(path, x, y, width, is_hovered, badge_text, badge_color)
  local prefix, suffix = split_path(path)
  local prefix_color, suffix_color = get_path_colors(is_hovered)
  local text_y = y + math.floor(style.padding.y / 2)
  local badge_width = 0
  local badge_spacing = 0

  if badge_text and badge_text ~= "" then
    badge_width = style.font:get_width(badge_text)
    if badge_width > 0 and badge_width < width then
      badge_spacing = style.padding.x
    end
  end

  local path_width = width
  if badge_width > 0 then
    path_width = math.max(0, width - badge_width - badge_spacing)
  end

  local suffix_width = style.font:get_width(suffix)

  if suffix_width >= path_width then
    local clipped_suffix = truncate_left(style.font, suffix, path_width)
    if clipped_suffix ~= "" then
      renderer.draw_text(style.font, clipped_suffix, x, text_y, suffix_color)
    end
  elseif path_width > 0 then
    local prefix_width = math.max(0, path_width - suffix_width)
    local clipped_prefix = compact_prefix(prefix, prefix_width)
    local draw_x = x

    if clipped_prefix ~= "" then
      draw_x = renderer.draw_text(style.font, clipped_prefix, draw_x, text_y, prefix_color)
    end

    renderer.draw_text(style.font, suffix, draw_x, text_y, suffix_color)
  end

  if badge_width > 0 then
    local badge_x = x + width - badge_width
    renderer.draw_text(style.font, badge_text, badge_x, text_y, badge_color or style.text)
  end
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

if not activity_state.doc_text_change_wrapped then
  local previous_doc_on_text_change = Doc.on_text_change
  Doc.on_text_change = function(self, change_type)
    local result = previous_doc_on_text_change(self, change_type)
    if self and self.abs_filename then
      mark_recent_edit(self.abs_filename)
    end
    return result
  end
  activity_state.doc_text_change_wrapped = true
end

if not state.doc_save_wrapped then
  local previous_doc_save = Doc.save
  Doc.save = function(self, filename, abs_filename)
    local previous_abs_filename = self.abs_filename
    local was_new_file = self.new_file
    local result = previous_doc_save(self, filename, abs_filename)

    local saved_abs_filename = self.abs_filename or abs_filename
    if saved_abs_filename and (was_new_file or saved_abs_filename ~= previous_abs_filename) then
      track_file(saved_abs_filename)
      mark_recent_edit(saved_abs_filename)
    end

    return result
  end
  state.doc_save_wrapped = true
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
  local dirs = get_display_dirs()
  local ox, oy = self:get_content_offset()
  local line_h = self:get_line_height()
  local header_h = self:get_header_height()
  local count = math.max(1, #dirs)
  local x = ox + style.padding.x
  local w = self.size.x - 2 * style.padding.x
  local index = 0

  return function()
    index = index + 1
    if index > count then
      return
    end

    local y = oy + header_h + line_h * (index - 1)
    local path = dirs[index]
    local text = path or "(no recent directories yet)"
    return index, text, x, y, w, line_h, path
  end
end

function RecentDirsPanel:get_item_at(px, py)
  local content_top = self.position.y + self:get_header_height()
  if py < content_top then
    return nil
  end

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

  local line_h = self:get_line_height()
  local header_h = self:get_header_height()
  local header_x = self.position.x + style.padding.x
  local header_y = self.position.y
  local header_text = "Recent Directories"
  if #state.dirs > 0 then
    header_text = header_text .. " (" .. tostring(#state.dirs) .. ")"
  end
  local view_top = self.position.y + header_h
  local view_bottom = self.position.y + self.size.y
  local dirs = get_display_dirs()
  local badge_glyphs = get_edit_badge_glyphs(config.plugins.recentdirs_panel)
  local badge_ranks = get_edit_rank_lookup(dirs, activity_state.dir_edit_order)
  local badge_color = config.plugins.recentdirs_panel.edit_badge_color or style.text

  for index, text, x, y, w, h, path in self:each_item() do
    if y + h >= view_top and y < view_bottom then
      if index == self.hovered_index then
        renderer.draw_rect(self.position.x, y, self.size.x, h, style.line_highlight)
      end

      if path then
        draw_path_text(
          path,
          x,
          y,
          w,
          index == self.hovered_index,
          get_badge_text(path, badge_ranks, badge_glyphs),
          badge_color
        )
      else
        renderer.draw_text(style.font, text, x, y + math.floor(style.padding.y / 2), style.dim)
      end
    end
  end

  renderer.draw_rect(self.position.x, self.position.y, self.size.x, header_h, style.background2)

  common.draw_text(
    style.font,
    style.accent,
    header_text,
    "left",
    header_x,
    header_y,
    self.size.x - 2 * style.padding.x,
    line_h
  )

  renderer.draw_rect(
    self.position.x,
    self.position.y + header_h - style.divider_size,
    self.size.x,
    style.divider_size,
    style.divider
  )

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
  local dirs = get_display_dirs()
  if not index or not dirs[index] then
    return false
  end

  return open_directory(dirs[index])
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
