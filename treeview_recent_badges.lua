-- mod-version:3

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local Doc = require "core.doc"

local ok_tree, treeview = pcall(require, "plugins.treeview")
if not ok_tree or not treeview then
  return
end

config.plugins.treeview_recent_badges = common.merge({
  edit_badge_hex_codes = { "2D58", "2E2C", "2E2B", "A4FD", "1F784" },
  edit_badge_color = { common.color "#00ff00" },
}, config.plugins.treeview_recent_badges)

local state = rawget(_G, "__treeview_recent_badges_state")
if not state then
  state = {
    draw_item_text_wrapped = false,
    file_rank_cache_version = nil,
    file_rank_lookup = {},
    dir_rank_cache_version = nil,
    dir_rank_lookup = {},
  }
  rawset(_G, "__treeview_recent_badges_state", state)
end

local activity_state = rawget(_G, "__recent_panels_activity_state")
if not activity_state then
  activity_state = {
    edit_counter = 0,
    file_edit_order = {},
    dir_edit_order = {},
    doc_text_change_wrapped = false,
    doc_save_wrapped = false,
    doc_save_listeners = {},
    core_run_wrapped = false,
    persist_loaded = false,
    seeded_from_recent_files = false,
  }
  rawset(_G, "__recent_panels_activity_state", activity_state)
end
activity_state.doc_text_change_wrapped = activity_state.doc_text_change_wrapped or false
activity_state.doc_save_wrapped = activity_state.doc_save_wrapped or false
activity_state.doc_save_listeners = activity_state.doc_save_listeners or {}
activity_state.core_run_wrapped = activity_state.core_run_wrapped or false
activity_state.persist_loaded = activity_state.persist_loaded or false
activity_state.seeded_from_recent_files = activity_state.seeded_from_recent_files or false

local activity_state_path = USERDIR .. PATHSEP .. "recent_edit_activity.lua"
local recent_files_path = USERDIR .. PATHSEP .. "recent_files.lua"

local function mark_recent_edit(path)
  if not path or path == "" then
    return
  end

  local encoded_path = common.home_encode(path)
  activity_state.edit_counter = activity_state.edit_counter + 1
  activity_state.file_edit_order[encoded_path] = activity_state.edit_counter

  local dir = common.dirname(encoded_path)
  if dir then
    activity_state.dir_edit_order[dir] = activity_state.edit_counter
  end
end

local function save_activity_state()
  local has_file_edits = next(activity_state.file_edit_order) ~= nil
  local has_dir_edits = next(activity_state.dir_edit_order) ~= nil

  if not has_file_edits and not has_dir_edits then
    os.remove(activity_state_path)
    return
  end

  local file = io.open(activity_state_path, "w+")
  if not file then
    return
  end

  file:write("return ", common.serialize({
    edit_counter = activity_state.edit_counter,
    file_edit_order = activity_state.file_edit_order,
    dir_edit_order = activity_state.dir_edit_order,
  }, { pretty = true }))
  file:close()
end

local function load_serialized_table(path, error_label)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  local loader, err = load(content)
  if not loader then
    core.error("%s load failed: %s", error_label, err)
    return nil
  end

  local ok, value = pcall(loader)
  if not ok or type(value) ~= "table" then
    return nil
  end

  return value
end

local function ensure_activity_state_loaded()
  if activity_state.persist_loaded then
    return
  end

  activity_state.persist_loaded = true
  local saved_state = load_serialized_table(activity_state_path, "treeview recent badge activity")
  if not saved_state then
    return
  end

  if type(saved_state.edit_counter) == "number" then
    activity_state.edit_counter = saved_state.edit_counter
  end
  if type(saved_state.file_edit_order) == "table" then
    activity_state.file_edit_order = saved_state.file_edit_order
  end
  if type(saved_state.dir_edit_order) == "table" then
    activity_state.dir_edit_order = saved_state.dir_edit_order
  end
end

local function seed_activity_state_from_recent_files(paths)
  if activity_state.seeded_from_recent_files then
    return
  end

  activity_state.seeded_from_recent_files = true
  if next(activity_state.file_edit_order) ~= nil then
    return
  end

  for index = #paths, 1, -1 do
    mark_recent_edit(common.home_expand(paths[index]))
  end
end

local function ensure_recent_file_seed()
  ensure_activity_state_loaded()
  if activity_state.seeded_from_recent_files or next(activity_state.file_edit_order) ~= nil then
    activity_state.seeded_from_recent_files = true
    return
  end

  local recent_files = load_serialized_table(recent_files_path, "treeview recent badge seed")
  if recent_files then
    seed_activity_state_from_recent_files(recent_files)
  end
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

local function get_edit_badge_glyphs()
  local glyphs = {}
  local hex_codes = config.plugins.treeview_recent_badges.edit_badge_hex_codes or {}

  for index = 1, 5 do
    glyphs[index] = hex_code_to_utf8(hex_codes[index]) or ""
  end

  return glyphs
end

local function add_ranked_path(top_paths, path, order)
  local entry = {
    path = path,
    order = order,
  }

  for index = 1, #top_paths do
    local current = top_paths[index]
    if order > current.order or (order == current.order and path < current.path) then
      table.insert(top_paths, index, entry)
      if #top_paths > 5 then
        table.remove(top_paths)
      end
      return
    end
  end

  if #top_paths < 5 then
    table.insert(top_paths, entry)
  end
end

local function build_rank_lookup(order_map)
  local top_paths = {}

  for path, order in pairs(order_map) do
    add_ranked_path(top_paths, path, order)
  end

  local lookup = {}
  for rank, entry in ipairs(top_paths) do
    lookup[entry.path] = rank
  end

  return lookup
end

local function get_rank_lookup(item_type)
  local version = activity_state.edit_counter

  if item_type == "dir" then
    if state.dir_rank_cache_version ~= version then
      state.dir_rank_lookup = build_rank_lookup(activity_state.dir_edit_order)
      state.dir_rank_cache_version = version
    end
    return state.dir_rank_lookup
  end

  if state.file_rank_cache_version ~= version then
    state.file_rank_lookup = build_rank_lookup(activity_state.file_edit_order)
    state.file_rank_cache_version = version
  end
  return state.file_rank_lookup
end

local function get_badge_text_for_item(item, glyphs)
  if not item or not item.abs_filename then
    return ""
  end

  local encoded_path = common.home_encode(item.abs_filename)
  local rank_lookup = get_rank_lookup(item.type == "dir" and "dir" or "file")
  local rank = rank_lookup[encoded_path]
  if not rank then
    return ""
  end

  return glyphs[rank] or ""
end

ensure_recent_file_seed()

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

if not activity_state.doc_save_wrapped then
  local previous_doc_save = Doc.save
  Doc.save = function(self, filename, abs_filename)
    local previous_abs_filename = self.abs_filename
    local was_new_file = self.new_file
    local result = previous_doc_save(self, filename, abs_filename)

    local saved_abs_filename = self.abs_filename or abs_filename
    if saved_abs_filename and (was_new_file or saved_abs_filename ~= previous_abs_filename) then
      mark_recent_edit(saved_abs_filename)
    end

    for _, listener in pairs(activity_state.doc_save_listeners) do
      listener(self, previous_abs_filename, was_new_file, saved_abs_filename, result)
    end

    return result
  end
  activity_state.doc_save_wrapped = true
end

if not activity_state.core_run_wrapped then
  local previous_core_run = core.run
  core.run = function(...)
    local result = previous_core_run(...)
    save_activity_state()
    return result
  end
  activity_state.core_run_wrapped = true
end

if state.draw_item_text_wrapped then
  return state
end

do
  local previous_draw_item_text = treeview.draw_item_text
  treeview.draw_item_text = function(self, item, active, hovered, x, y, w, h)
    previous_draw_item_text(self, item, active, hovered, x, y, w, h)

    local badge_text = get_badge_text_for_item(item, get_edit_badge_glyphs())
    if badge_text == "" then
      return
    end

    local item_text, item_font = self:get_item_text(item, active, hovered)
    local badge_x = x + item_font:get_width(item_text) + style.padding.x
    local badge_color = config.plugins.treeview_recent_badges.edit_badge_color or style.text
    common.draw_text(style.font, badge_color, badge_text, nil, badge_x, y, 0, h)
  end
end

state.draw_item_text_wrapped = true

return state
