param([Parameter(Mandatory)][string]$Locale, [Parameter(Mandatory)][string]$SourceWoditorDir, [string]$Project)
$ErrorActionPreference = "Stop"

function Copy-Woditor([string]$Dest) {
    if (-not (Test-Path -LiteralPath $Dest)) {
        New-Item -Path $Dest -ItemType Directory > $null
    }
    Get-ChildItem -LiteralPath $SourceWoditorDir -File | Where-Object {
        $_.Name -like "*.exe" -or
        $_.Name -like "*.dll" -or
        $_.Name -eq "Editor.Lang.SystemString.txt" -or
        $_.Name -eq "Editor.Lang.SystemValue.txt"
    } | Copy-Item -Destination $Dest
    # Do not overwrite Editor.ini.
    if (-not (Test-Path -LiteralPath "$Dest\Editor.ini") -and (Test-Path -LiteralPath "$SourceWoditorDir\Editor.ini")) {
        Copy-Item -LiteralPath "$SourceWoditorDir\Editor.ini" -Destination $Dest
    }
}

$root = Split-Path -Path $PSScriptRoot -Parent
if ($Project -eq "") {
    # By default, update all Woditor.
    $subDirs = Get-ChildItem -LiteralPath $root -Attributes Directory
    foreach ($subDir in $subDirs) {
        # Consider any directory containing an assets directory as a project.
        if (Test-Path -LiteralPath "$subDir\assets") {
            Copy-Woditor "$subDir\$Locale\_woditor"
        }
    }
}
else {
    # For creating a new project.
    Copy-Woditor "$root\$Project\$Locale\_woditor"
}
