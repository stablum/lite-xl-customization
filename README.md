# Lite XL Customization

This repository contains five single-file Lite XL plugins:

- `custom_settings.lua` applies your preferred plugin configuration overrides, such as `autoreload` and `recentfiles_panel` settings.
- `redblack_style.lua` applies your black-and-red style preferences as an optional visual theme plugin.
- `recentdirs_panel.lua` adds a Recent Directories panel above the recent files panel. Clicking a directory reveals it in the treeview without closing your current files.
- `recentfiles_panel.lua` adds a Recent Files panel to the treeview area and lets you reopen recently accessed files.
- `treeview_recent_badges.lua` appends configurable recent-edit badges to matching file and directory entries in the treeview.

`recentfiles_panel.lua` and `recentdirs_panel.lua` depend on Lite XL's built-in `treeview` and `recentfiles` plugins. `treeview_recent_badges.lua` depends on Lite XL's built-in `treeview` plugin.

## Installation

Run the installer from this repository:

```powershell
.\install.ps1
```

The installer now shows a selection menu so you can install:

- `custom_settings.lua` only
- `redblack_style.lua` only
- `recentdirs_panel.lua` only
- `recentfiles_panel.lua` only
- `treeview_recent_badges.lua` only
- all plugins

When you run `.\install.ps1` in a console, the installer uses an interactive menu:

- `Up` and `Down` move the selection
- `Enter` installs the selected option
- `Esc` cancels

The default highlighted option is `Recent Directories`, not `All`.

For non-interactive use, you can choose explicitly:

```powershell
.\install.ps1 -Plugin All
.\install.ps1 -Plugin RecentDirs
.\install.ps1 -Plugin RecentFiles
.\install.ps1 -Plugin TreeviewBadges
.\install.ps1 -Plugin Style
.\install.ps1 -Plugin Settings
```

It copies the selected plugin file or files into the first matching Lite XL plugins directory from this list:

1. `%APPDATA%\lite-xl\plugins`
2. `%USERPROFILE%\.config\lite-xl\plugins`
3. `%USERPROFILE%\.lite-xl\plugins`

If none of those parent config directories exist, it falls back to:

```text
%USERPROFILE%\.config\lite-xl\plugins
```

You can override the destination:

```powershell
.\install.ps1 -Destination C:\path\to\lite-xl\plugins
```

## Commands

The plugins register these commands:

- `recentdirs-panel:toggle`
- `recentdirs-panel:clear`
- `recentfiles-panel:toggle`
- `recentfiles-panel:clear`

## Configuration

Example Lite XL user config:

```lua
local common = require "core.common"

config.plugins.recentdirs_panel = {
  visible = true,
  max_visible_items = 8,
  max_tracked_items = 100,
  sort = true,
  path_prefix_color = { common.color "#553333" },
  path_suffix_color = { common.color "#ff0000" },
  hover_path_prefix_color = { common.color "#aa6666" },
  hover_path_suffix_color = { common.color "#ff6666" },
  tooltip_text_color = { common.color "#ff0000" },
  tooltip_background_color = { common.color "#000000" },
  tooltip_border_color = { common.color "#773300" },
}

config.plugins.recentfiles_panel = {
  visible = true,
  max_visible_items = 10,
  sort = false,
  path_prefix_color = { common.color "#553333" },
  path_suffix_color = { common.color "#ff0000" },
  extension_color = { common.color "#ff6666" },
  hover_path_prefix_color = { common.color "#aa6666" },
  hover_path_suffix_color = { common.color "#ff6666" },
  hover_extension_color = { common.color "#ffffff" },
  tooltip_text_color = { common.color "#ff0000" },
  tooltip_background_color = { common.color "#000000" },
  tooltip_border_color = { common.color "#773300" },
}

config.plugins.treeview_recent_badges = {
  edit_badge_hex_codes = { "2059", "2E2C", "2E2B", "003A", "00B7" },
  edit_badge_color = { common.color "#00ff00" },
}
```

`sort` controls whether the panel shows entries alphabetically or keeps the original recent-item order.

For `recentfiles_panel`, `extension_color` and `hover_extension_color` apply to the full extension token, including the leading `.`.

Hovering a recent item shows a tooltip with the full uncompressed parent path. In `recentfiles_panel` the filename is omitted because it is already visible, and in `recentdirs_panel` the deepest directory name is omitted for the same reason.

`custom_settings.lua` currently applies:

```lua
local common = require "core.common"

local ui_font_size = 20 * SCALE

style.font = renderer.font.group({
  renderer.font.load(os.getenv("LOCALAPPDATA") .. "\\Microsoft\\Windows\\Fonts\\carbonplus-bold-bl.otf", ui_font_size),
  renderer.font.load((os.getenv("WINDIR") or "C:\\Windows") .. "\\Fonts\\seguisym.ttf", ui_font_size),
})

config.plugins.autoreload = {
  always_show_nagview = false,
}

config.plugins.recentfiles_panel = {
  visible = true,
  max_visible_items = 12,
  edit_badge_hex_codes = { "2059", "2E2C", "2E2B", "003A", "00B7" },
  edit_badge_color = { common.color "#00ff00" },
  tooltip_text_color = { common.color "#ff0000" },
  tooltip_background_color = { common.color "#000000" },
  tooltip_border_color = { common.color "#773300" },
}

config.plugins.recentdirs_panel = {
  sort = true,
  edit_badge_hex_codes = { "2059", "2E2C", "2E2B", "003A", "00B7" },
  edit_badge_color = { common.color "#00ff00" },
  tooltip_text_color = { common.color "#ff0000" },
  tooltip_background_color = { common.color "#000000" },
  tooltip_border_color = { common.color "#773300" },
}

config.plugins.treeview_recent_badges = {
  edit_badge_hex_codes = { "2059", "2E2C", "2E2B", "003A", "00B7" },
  edit_badge_color = { common.color "#00ff00" },
}
```

`edit_badge_hex_codes` maps the first five most recently edited entries to appended Unicode badges. In `recentdirs_panel`, recency is derived from the most recently edited file in each directory. In `treeview_recent_badges`, matching treeview file and directory rows get the same badges.

## License

This project is licensed under the GNU General Public License v3.0. See `LICENSE` or `COPYING`.
