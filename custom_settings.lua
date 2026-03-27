-- mod-version:3

local common = require "core.common"
local config = require "core.config"
local style = require "core.style"

local ui_font_size = 20 * SCALE
local big_ui_font_size = ui_font_size * (46 / 15)
local recent_edit_badge_hex_codes = { "2059", "2E2C", "2E2B", "003A", "00B7" }
local recent_edit_badge_color = { common.color "#00ff00" }

local function file_exists(path)
  if not path or path == "" then
    return false
  end

  local file = io.open(path, "rb")
  if file then
    file:close()
    return true
  end

  return false
end

local function load_font_if_exists(path, size)
  if not file_exists(path) then
    return nil
  end

  local ok, font = pcall(renderer.font.load, path, size)
  if ok then
    return font
  end

  return nil
end

local function build_font_stack(current_font, size)
  if not current_font then
    return nil
  end

  size = size or current_font:get_size()
  local localappdata = os.getenv("LOCALAPPDATA") or ""
  local windir = os.getenv("WINDIR") or "C:\\Windows"

  local carbon = load_font_if_exists(
    localappdata .. PATHSEP .. "Microsoft" .. PATHSEP .. "Windows" .. PATHSEP .. "Fonts" .. PATHSEP .. "carbonplus-bold-bl.otf",
    size
  )
  local symbol_font = load_font_if_exists(
    windir .. PATHSEP .. "Fonts" .. PATHSEP .. "seguisym.ttf",
    size
  )

  local fonts = {}
  if carbon then
    table.insert(fonts, carbon)
  else
    table.insert(fonts, current_font)
  end
  if symbol_font then
    table.insert(fonts, symbol_font)
  end

  if #fonts == 1 then
    return fonts[1]
  end

  return renderer.font.group(fonts)
end

style.font = build_font_stack(style.font, ui_font_size) or style.font
style.big_font = build_font_stack(style.big_font, big_ui_font_size) or style.big_font

config.plugins.autoreload = config.plugins.autoreload or {}
config.plugins.autoreload.always_show_nagview = false

config.plugins.recentfiles_panel = config.plugins.recentfiles_panel or {}
config.plugins.recentdirs_panel = config.plugins.recentdirs_panel or {}
config.plugins.treeview_recent_badges = config.plugins.treeview_recent_badges or {}
config.plugins.recentfiles_panel.visible = true
config.plugins.recentfiles_panel.max_visible_items = 12
config.plugins.recentfiles_panel.edit_badge_hex_codes = recent_edit_badge_hex_codes
config.plugins.recentfiles_panel.edit_badge_color = recent_edit_badge_color

config.plugins.recentdirs_panel.sort = true
config.plugins.recentdirs_panel.edit_badge_hex_codes = recent_edit_badge_hex_codes
config.plugins.recentdirs_panel.edit_badge_color = recent_edit_badge_color
config.plugins.treeview_recent_badges.edit_badge_hex_codes = recent_edit_badge_hex_codes
config.plugins.treeview_recent_badges.edit_badge_color = recent_edit_badge_color
config.plugins.recentfiles_panel.sort = false

local recentfiles_state = rawget(_G, "__recentfiles_panel_state")
if recentfiles_state and recentfiles_state.view then
  recentfiles_state.view.visible = config.plugins.recentfiles_panel.visible
end

config.plugins.linewrapping.enable_by_default = true
config.plugins.linewrapping.mode = "word"   -- "word" or "letter"
config.plugins.linewrapping.indent = true   -- keeps wrapped lines aligned nicely
config.plugins.linewrapping.guide = true   -- optional; set true if you want a wrap guide line
