param([Parameter(Mandatory)][string]$Locale, [Parameter(Mandatory)][string]$SourceWoditorDir, [string]$Project)
$ErrorActionPreference = "Stop"

function Copy-Woditor([string]$ProjectName) {
    $dest = "$ProjectName\$Locale\_woditor"
    if (-not (Test-Path $dest)) {
        New-Item -Path $dest -ItemType Directory > $null
    }
    Copy-Item -Path "$SourceWoditorDir\*" -Destination $dest -Include "*.exe", "*.dll", "Editor.Lang.SystemString.txt", "Editor.Lang.SystemValue.txt"
    # Do not overwrite Editor.ini.
    if (-not (Test-Path "$dest\Editor.ini")) {
        Copy-Item "$SourceWoditorDir\Editor.ini" $dest
    }
}

Set-Location (Split-Path -Path $PSScriptRoot -Parent)
if ($Project -eq "") {
    # By default, update all Woditor.
    $directories = Get-ChildItem -Attributes Directory
    foreach ($dir in $directories) {
        # Consider the directory containing the assets directory as a project.
        if (Test-Path -Path "$dir\assets") {
            Copy-Woditor $dir
        }
    }
}
else {
    # For creating a new project.
    Copy-Woditor $Project
}
