[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string]$Destination
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceFiles = @(
  "recentdirs_panel.lua",
  "recentfiles_panel.lua"
) | ForEach-Object { Join-Path $scriptDir $_ }

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
