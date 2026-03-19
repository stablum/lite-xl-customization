-- mod-version:3

local config = require "core.config"

config.plugins.autoreload = config.plugins.autoreload or {}
config.plugins.autoreload.always_show_nagview = false

config.plugins.recentfiles_panel = config.plugins.recentfiles_panel or {}
config.plugins.recentfiles_panel.visible = true
config.plugins.recentfiles_panel.max_visible_items = 12

local recentfiles_state = rawget(_G, "__recentfiles_panel_state")
if recentfiles_state and recentfiles_state.view then
  recentfiles_state.view.visible = config.plugins.recentfiles_panel.visible
end
