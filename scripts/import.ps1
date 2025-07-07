param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Locale)
$ErrorActionPreference = "Stop"

function Join-Texts([string]$Src, [string]$Dest) {
    Remove-Item -Path "$Dest\MapData\*" -Recurse -ErrorAction SilentlyContinue
    Copy-Item -Path "$Src\BasicData\Game.txt" -Destination "$Dest\BasicData\Game.dat.Auto.txt"
    foreach ($group in @("BasicData", "MapData")) {
        $folders = Get-ChildItem -Path "$Src\$group" -Attributes Directory
        foreach ($folder in $folders) {
            $content = ""
            $destFileName = $folder.Name
            $prefix = ""
            $delimiter = $null
            if ($group -eq "BasicData") {
                if ($folder.Name -eq "CommonEvent") {
                    $delimiter = "--------------------------"
                    $destFileName += ".dat"
                }
                elseif ($folder.Name -eq "TileSetData") {
                    $delimiter = "---"
                    $destFileName += ".dat"
                }
                else {
                    $delimiter = "----"
                }
                $destFileName += ".Auto.txt"
            }
            elseif ($group -eq "MapData") {
                $content += (Get-Content -Path "$folder\Map.txt" -Raw) + "----------`r`n"

                $prefix = "Event_"
                $delimiter = "-----"
                $destFileName += ".mps.Auto.txt"
            }

            $content += Get-Content -Path "$folder\${prefix}Header.txt" -Raw
            $files = Get-ChildItem -Path $folder | Where-Object { $_.Name -match "^$prefix\d+.txt$" } | Sort-Object
            foreach ($file in $files) {
                $content += $delimiter + "`r`n" + (Get-Content -Path $file -Raw)
            }
            New-Item -Path "$Dest\$group\$destFileName" -Value $content -Force > $null
        }
    }
}

Set-Location (Split-Path -Path $PSScriptRoot -Parent)
$assetsDir = "$Project\assets"
$langDir = "$Project\$Locale"
$woditorDir = "$langDir\_woditor"
$dataDir = "$woditorDir\Data"
$txtDataDir = "$woditorDir\Data_AutoTXT"
$textsDir = "$langDir\texts"
$othersDir = "$langDir\others"

# Confirm
if (Test-Path -Path $dataDir) {
    $typeName = "System.Management.Automation.Host.ChoiceDescription"
    $choice = $host.ui.PromptForChoice("Confirm", "Are you sure you want to import?", @((New-Object $typeName "&No", "No"), (New-Object $typeName "&Yes", "Yes")), 0)
    if ($choice -eq 0) {
        exit
    }
}

Join-Texts $textsDir $txtDataDir

Start-Process "$woditorDir\Editor.exe" "-txtinput" -Wait

. scripts\.util.ps1
Copy-Assets $assetsDir $dataDir
Copy-Others $othersDir $dataDir
