[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string]$Destination
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceFile = Join-Path $scriptDir "recentfiles_panel.lua"

if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
  throw "Could not find plugin source file: $sourceFile"
}

function Resolve-TargetFile {
  param(
    [string]$RequestedDestination
  )

  if ($RequestedDestination) {
    $expandedDestination = [Environment]::ExpandEnvironmentVariables($RequestedDestination)

    if (Test-Path -LiteralPath $expandedDestination -PathType Container) {
      return Join-Path $expandedDestination "recentfiles_panel.lua"
    }

    if ([IO.Path]::GetExtension($expandedDestination) -ieq ".lua") {
      return $expandedDestination
    }

    return Join-Path $expandedDestination "recentfiles_panel.lua"
  }

  $candidateDirs = @(
    (Join-Path $env:APPDATA "lite-xl\plugins"),
    (Join-Path $HOME ".config\lite-xl\plugins"),
    (Join-Path $HOME ".lite-xl\plugins")
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

  foreach ($candidateDir in $candidateDirs) {
    $configDir = Split-Path -Parent $candidateDir
    if (Test-Path -LiteralPath $configDir -PathType Container) {
      return Join-Path $candidateDir "recentfiles_panel.lua"
    }
  }

  return Join-Path (Join-Path $HOME ".config\lite-xl\plugins") "recentfiles_panel.lua"
}

$targetFile = Resolve-TargetFile -RequestedDestination $Destination
$targetDir = Split-Path -Parent $targetFile

if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
  New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

if ($PSCmdlet.ShouldProcess($targetFile, "Install recentfiles_panel.lua")) {
  Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
  Write-Host "Installed recentfiles_panel.lua to $targetFile"
}
