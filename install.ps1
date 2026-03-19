[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string]$Destination,
  [string]$Plugin = "Menu"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-PluginSelection {
  param(
    [string]$RequestedPlugin
  )

  if ($RequestedPlugin -eq "Everything") {
    $RequestedPlugin = "All"
  }

  if ($RequestedPlugin -and $RequestedPlugin -ne "Menu") {
    if ($RequestedPlugin -notin @("All", "RecentDirs", "RecentFiles")) {
      throw "Invalid plugin selection '$RequestedPlugin'. Use Menu, All, RecentDirs, or RecentFiles."
    }
    return $RequestedPlugin
  }

  $menuItems = @(
    [PSCustomObject]@{
      Key = "RecentDirs"
      Label = "Recent Directories"
      Description = "Install recentdirs_panel.lua only."
    },
    [PSCustomObject]@{
      Key = "RecentFiles"
      Label = "Recent Files"
      Description = "Install recentfiles_panel.lua only."
    },
    [PSCustomObject]@{
      Key = "All"
      Label = "All"
      Description = "Install both plugins."
    },
    [PSCustomObject]@{
      Key = $null
      Label = "Cancel"
      Description = "Exit without installing."
    }
  )

  try {
    if (-not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
      Write-Host "Choose which Lite XL plugin(s) to install."
      Write-Host "Use Up/Down to move, Enter to confirm, or Escape to cancel."
      Write-Host ""

      $menuTop = [Console]::CursorTop
      $selectedIndex = 0

      foreach ($item in $menuItems) {
        Write-Host ""
      }

      while ($true) {
        $lineWidth = [Math]::Max(20, [Console]::BufferWidth - 1)
        [Console]::SetCursorPosition(0, $menuTop)

        for ($i = 0; $i -lt $menuItems.Count; $i++) {
          $prefix = if ($i -eq $selectedIndex) { ">" } else { " " }
          $line = "{0} {1} - {2}" -f $prefix, $menuItems[$i].Label, $menuItems[$i].Description
          if ($line.Length -gt $lineWidth) {
            $line = $line.Substring(0, $lineWidth)
          } else {
            $line = $line.PadRight($lineWidth)
          }
          Write-Host $line
        }

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
          "UpArrow" {
            $selectedIndex = ($selectedIndex - 1 + $menuItems.Count) % $menuItems.Count
          }
          "DownArrow" {
            $selectedIndex = ($selectedIndex + 1) % $menuItems.Count
          }
          "Enter" {
            Write-Host ""
            return $menuItems[$selectedIndex].Key
          }
          "Escape" {
            Write-Host ""
            return $null
          }
        }
      }
    }
  } catch {
    # Fall back to PromptForChoice when the host cannot read raw Console keys.
  }

  $choices = @(
    (New-Object System.Management.Automation.Host.ChoiceDescription "Recent &Directories", "Install recentdirs_panel.lua only."),
    (New-Object System.Management.Automation.Host.ChoiceDescription "Recent &Files", "Install recentfiles_panel.lua only."),
    (New-Object System.Management.Automation.Host.ChoiceDescription "&All", "Install both plugins."),
    (New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Exit without installing.")
  )

  $selection = $Host.UI.PromptForChoice(
    "Plugin Selection",
    "Choose which Lite XL plugin(s) to install.",
    $choices,
    0
  )

  switch ($selection) {
    0 { return "RecentDirs" }
    1 { return "RecentFiles" }
    2 { return "All" }
    default { return $null }
  }
}

function Resolve-SourceFiles {
  param(
    [string]$PluginSelection
  )

  switch ($PluginSelection) {
    "RecentDirs" {
      return @("recentdirs_panel.lua")
    }
    "RecentFiles" {
      return @("recentfiles_panel.lua")
    }
    "All" {
      return @(
        "recentdirs_panel.lua",
        "recentfiles_panel.lua"
      )
    }
    default {
      return @(
        "recentdirs_panel.lua",
        "recentfiles_panel.lua"
      )
    }
  }
}

$selectedPlugin = Resolve-PluginSelection -RequestedPlugin $Plugin
if (-not $selectedPlugin) {
  Write-Host "Installation canceled."
  return
}

$sourceFiles = Resolve-SourceFiles -PluginSelection $selectedPlugin |
  ForEach-Object { Join-Path $scriptDir $_ }

foreach ($sourceFile in $sourceFiles) {
  if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
    throw "Could not find plugin source file: $sourceFile"
  }
}

function Resolve-TargetDirectory {
  param(
    [string]$RequestedDestination
  )

  if ($RequestedDestination) {
    $expandedDestination = [Environment]::ExpandEnvironmentVariables($RequestedDestination)

    if ([IO.Path]::GetExtension($expandedDestination) -ieq ".lua") {
      return Split-Path -Parent $expandedDestination
    }

    return $expandedDestination
  }

  $candidateDirs = @(
    (Join-Path $env:APPDATA "lite-xl\plugins"),
    (Join-Path $HOME ".config\lite-xl\plugins"),
    (Join-Path $HOME ".lite-xl\plugins")
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

  foreach ($candidateDir in $candidateDirs) {
    $configDir = Split-Path -Parent $candidateDir
    if (Test-Path -LiteralPath $configDir -PathType Container) {
      return $candidateDir
    }
  }

  return Join-Path $HOME ".config\lite-xl\plugins"
}

$targetDir = Resolve-TargetDirectory -RequestedDestination $Destination

if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
  New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

foreach ($sourceFile in $sourceFiles) {
  $targetFile = Join-Path $targetDir (Split-Path -Leaf $sourceFile)
  if ($PSCmdlet.ShouldProcess($targetFile, "Install $(Split-Path -Leaf $sourceFile)")) {
    Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
    Write-Host "Installed $(Split-Path -Leaf $sourceFile) to $targetFile"
  }
}
