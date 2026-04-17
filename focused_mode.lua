-- mod-version:3

local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"

local ok_treeview, treeview = pcall(require, "plugins.treeview")

config.plugins.focused_mode = common.merge({
  enabled = false,
}, config.plugins.focused_mode)

local state = rawget(_G, "__focused_mode_state")
if not state then
  state = {
    active = false,
    ui_patch_applied = false,
    previous_treeview_visible = nil,
    previous_statusbar_visible = nil,
  }
  rawset(_G, "__focused_mode_state", state)
end

local function update_layout()
  if core.root_view and core.root_view.root_node then
    core.root_view.root_node:update_layout()
  end
  core.redraw = true
end

local function apply_focused_mode(enabled)
  enabled = not not enabled
  config.plugins.focused_mode.enabled = enabled

  if enabled then
    if not state.active then
      if ok_treeview and treeview then
        state.previous_treeview_visible = treeview.visible
      end
      if core.status_view then
        state.previous_statusbar_visible = core.status_view.visible
      end
    end

    if ok_treeview and treeview then
      treeview.visible = false
    end
    if core.status_view then
      core.status_view.visible = false
    end
    state.active = true
  else
    if ok_treeview and treeview and state.previous_treeview_visible ~= nil then
      treeview.visible = state.previous_treeview_visible
    end
    if core.status_view and state.previous_statusbar_visible ~= nil then
      core.status_view.visible = state.previous_statusbar_visible
    end

    state.previous_treeview_visible = nil
    state.previous_statusbar_visible = nil
    state.active = false
  end

  update_layout()
end

if not state.ui_patch_applied then
  state.ui_patch_applied = true

  core.add_thread(function()
    coroutine.yield()

    local DocView = require "core.docview"
    local Node = require "core.node"

    state.original_get_gutter_width = state.original_get_gutter_width or DocView.get_gutter_width
    state.original_draw_line_gutter = state.original_draw_line_gutter or DocView.draw_line_gutter
    state.original_should_show_tabs = state.original_should_show_tabs or Node.should_show_tabs

    function DocView:get_gutter_width(...)
      if config.plugins.focused_mode.enabled then
        return style.padding.x, 0
      end
      return state.original_get_gutter_width(self, ...)
    end

    function DocView:draw_line_gutter(line, x, y, width, ...)
      if config.plugins.focused_mode.enabled then
        return self:get_line_height()
      end
      return state.original_draw_line_gutter(self, line, x, y, width, ...)
    end

    function Node:should_show_tabs(...)
      if config.plugins.focused_mode.enabled then
        return false
      end
      return state.original_should_show_tabs(self, ...)
    end

    if config.plugins.focused_mode.enabled then
      apply_focused_mode(true)
    end
  end)
end

command.add(nil, {
  ["focused-mode:toggle"] = function()
    apply_focused_mode(not config.plugins.focused_mode.enabled)
  end,

  ["focused-mode:enable"] = function()
    apply_focused_mode(true)
  end,

  ["focused-mode:disable"] = function()
    apply_focused_mode(false)
  end,
})

keymap.add {
  ["alt+z"] = "focused-mode:toggle",
}
