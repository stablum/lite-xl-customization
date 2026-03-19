# Lite XL Customization

This repository contains two single-file Lite XL plugins:

- `recentdirs_panel.lua` adds a Recent Directories panel above the recent files panel. Clicking a directory switches the current Lite XL project so the treeview opens that directory.
- `recentfiles_panel.lua` adds a Recent Files panel to the treeview area and lets you reopen recently accessed files.

Both plugins depend on Lite XL's built-in `treeview` and `recentfiles` plugins.

## Installation

Run the installer from this repository:

```powershell
.\install.ps1
```

The installer now shows a selection menu so you can install:

- everything
- `recentdirs_panel.lua` only
- `recentfiles_panel.lua` only

For non-interactive use, you can choose explicitly:

```powershell
.\install.ps1 -Plugin Everything
.\install.ps1 -Plugin RecentDirs
.\install.ps1 -Plugin RecentFiles
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
config.plugins.recentdirs_panel = {
  visible = true,
  max_visible_items = 8,
  max_tracked_items = 100,
}

config.plugins.recentfiles_panel = {
  visible = true,
  max_visible_items = 10,
}
```

## License

This project is licensed under the GNU General Public License v3.0. See `LICENSE` or `COPYING`.
