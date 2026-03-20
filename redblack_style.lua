-- mod-version:3

local style = require "core.style"
local common = require "core.common"
local config = require "core.config"

style.background = { common.color "#000000" }
style.background2 = { common.color "#000000" }
style.background3 = { common.color "#000000" }
style.line_highlight = { common.color "#0b0b40" }
style.selection = { common.color "#400a0a" }
style.caret = { common.color "#ff0000" }
style.line_number = { common.color "#773300" }
style.line_number2 = { common.color "#ff0000" }
style.caret_width = 4

config.plugins.recentdirs_panel = common.merge(config.plugins.recentdirs_panel or {}, {
  path_prefix_color = { common.color "#553333" },
  path_suffix_color = { common.color "#662222" },
  hover_path_prefix_color = { common.color "#773300" },
  hover_path_suffix_color = { common.color "#ff0000" },
})

config.plugins.recentfiles_panel = common.merge(config.plugins.recentfiles_panel or {}, {
  path_prefix_color = { common.color "#553333" },
  path_suffix_color = { common.color "#662222" },
  hover_path_prefix_color = { common.color "#773300" },
  hover_path_suffix_color = { common.color "#ff0000" },
  extension_color = { common.color "#0000ff" },
  hover_extension_color = { common.color "#aaaaff" },
})
