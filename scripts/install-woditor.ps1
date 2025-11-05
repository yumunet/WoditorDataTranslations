param([Parameter(Mandatory)][string]$Locale, [Parameter(Mandatory)][string]$SourceWoditorDir, [string]$Project)
$ErrorActionPreference = "Stop"

function Copy-Woditor([string]$Dest) {
    if (-not (Test-Path $Dest)) {
        New-Item -Path $Dest -ItemType Directory > $null
    }
    Copy-Item -Path "$SourceWoditorDir\*" -Destination $Dest -Include "*.exe", "*.dll", "Editor.Lang.SystemString.txt", "Editor.Lang.SystemValue.txt"
    # Do not overwrite Editor.ini.
    if (-not (Test-Path "$Dest\Editor.ini")) {
        Copy-Item "$SourceWoditorDir\Editor.ini" $Dest
    }
}

$root = Split-Path -Path $PSScriptRoot -Parent
if ($Project -eq "") {
    # By default, update all Woditor.
    $subDirs = Get-ChildItem $root -Attributes Directory
    foreach ($subDir in $subDirs) {
        # Consider any directory containing an assets directory as a project.
        if (Test-Path -Path "$subDir\assets") {
            Copy-Woditor "$subDir\$Locale\_woditor"
        }
    }
}
else {
    # For creating a new project.
    Copy-Woditor "$root\$Project\$Locale\_woditor"
}
