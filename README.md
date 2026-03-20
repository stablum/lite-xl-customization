# Lite XL Customization

This repository contains four single-file Lite XL plugins:

- `custom_settings.lua` applies your preferred plugin configuration overrides, such as `autoreload` and `recentfiles_panel` settings.
- `redblack_style.lua` applies your black-and-red style preferences as an optional visual theme plugin.
- `recentdirs_panel.lua` adds a Recent Directories panel above the recent files panel. Clicking a directory switches the current Lite XL project so the treeview opens that directory.
- `recentfiles_panel.lua` adds a Recent Files panel to the treeview area and lets you reopen recently accessed files.

The panel plugins depend on Lite XL's built-in `treeview` and `recentfiles` plugins.

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
}
```

`sort` controls whether the panel shows entries alphabetically or keeps the original recent-item order.

For `recentfiles_panel`, `extension_color` and `hover_extension_color` apply to the full extension token, including the leading `.`.

`custom_settings.lua` currently applies:

```lua
config.plugins.autoreload = {
  always_show_nagview = false,
}

config.plugins.recentfiles_panel = {
  visible = true,
  max_visible_items = 12,
}
```

## License

This project is licensed under the GNU General Public License v3.0. See `LICENSE` or `COPYING`.
