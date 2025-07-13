param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Locale)
$ErrorActionPreference = "Stop"

Set-Location (Split-Path -Path $PSScriptRoot -Parent)
$langDir = "$Project\$Locale"
$dataDir = "$langDir\_woditor\Data"
$outputDir = "releases"

.\scripts\import.ps1 $Project $Locale || $(exit 1)
Remove-Item -Path "$dataDir\BasicData\AutoBackup*" -Recurse -ErrorAction SilentlyContinue

if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory > $null
}
Compress-Archive -Path $dataDir, "$langDir\*.*" -DestinationPath "$outputDir\${Project}_${Locale}.zip" -Force
