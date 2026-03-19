[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string]$Destination,
  [ValidateSet("Menu", "Everything", "All", "RecentDirs", "RecentFiles")]
  [string]$Plugin = "Menu"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-PluginSelection {
  param(
    [string]$RequestedPlugin
  )

  if ($RequestedPlugin -and $RequestedPlugin -ne "Menu") {
    return $RequestedPlugin
  }

  $choices = @(
    (New-Object System.Management.Automation.Host.ChoiceDescription "&Everything", "Install both plugins."),
    (New-Object System.Management.Automation.Host.ChoiceDescription "Recent &Directories", "Install recentdirs_panel.lua only."),
    (New-Object System.Management.Automation.Host.ChoiceDescription "Recent &Files", "Install recentfiles_panel.lua only."),
    (New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Exit without installing.")
  )

  $selection = $Host.UI.PromptForChoice(
    "Plugin Selection",
    "Choose which Lite XL plugin(s) to install.",
    $choices,
    0
  )

  switch ($selection) {
    0 { return "Everything" }
    1 { return "RecentDirs" }
    2 { return "RecentFiles" }
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
