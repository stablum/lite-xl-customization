-- mod-version:3

local config = require "core.config"

config.plugins.autoreload = config.plugins.autoreload or {}
config.plugins.autoreload.always_show_nagview = false

config.plugins.recentfiles_panel = config.plugins.recentfiles_panel or {}
config.plugins.recentdirs_panel = config.plugins.recentdirs_panel or {}
config.plugins.recentfiles_panel.visible = true
config.plugins.recentfiles_panel.max_visible_items = 12

config.plugins.recentdirs_panel.sort = true
config.plugins.recentfiles_panel.sort = false

local recentfiles_state = rawget(_G, "__recentfiles_panel_state")
if recentfiles_state and recentfiles_state.view then
  recentfiles_state.view.visible = config.plugins.recentfiles_panel.visible
end
