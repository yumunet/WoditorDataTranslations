param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Locale)
$ErrorActionPreference = "Stop"

$root = Split-Path -Path $PSScriptRoot -Parent
$langDir = "$root\$Project\$Locale"
$woditorDataDir = "$langDir\_woditor\Data"
$outputDir = "$root\releases"

& "$root\scripts\import.ps1" $Project $Locale || $(exit 1)
Remove-Item -Path "$woditorDataDir\BasicData\AutoBackup*" -Recurse -ErrorAction SilentlyContinue

if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory > $null
}
Compress-Archive -Path $woditorDataDir, "$langDir\*.*" -DestinationPath "$outputDir\${Project}_${Locale}.zip" -Force
