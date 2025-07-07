param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Locale)
$ErrorActionPreference = "Stop"

function Split-Texts([string]$Src, [string]$Dest) {
    foreach ($group in @("BasicData", "MapData")) {
        $files = Get-ChildItem -Path "$Src\$group\*" -Include *.Auto.txt
        foreach ($file in $files) {
            $pathBase = "$Dest\$group\" + ($file.Name -replace "\..+", "")

            if (($group -eq "BasicData") -and ($file.Name -eq "Game.dat.Auto.txt")) {
                Copy-Item -Path $file -Destination "$pathBase.txt"
                continue
            }

            $content = Get-Content -Path $file -Raw
            $sectionsContent = $content
            $prefix = ""
            $delimiter = $null
            $digits = $null
            if ($group -eq "BasicData") {
                if ($file.Name -eq "CommonEvent.dat.Auto.txt") {
                    $delimiter = "--------------------------"
                    $digits = 3
                }
                elseif ($file.Name -eq "TileSetData.dat.Auto.txt") {
                    $delimiter = "---"
                    $digits = 4
                }
                else {
                    $delimiter = "----"
                    $digits = 2
                }
            }
            elseif ($group -eq "MapData") {
                $parts = $content -split "(?m)^----------`r`n"
                
                # Map itself
                New-Item -Path "$pathBase\Map.txt" -Value $parts[0] -Force > $null
                
                # Map Events
                $sectionsContent = $parts[1]
                $prefix = "Event_"
                $delimiter = "-----"
                $digits = 4
            }

            $sections = $sectionsContent -split "(?m)^$delimiter`r`n"
            for ($i = 0; $i -lt $sections.Count; $i++) {
                $fileName = $Prefix
                if ($i -eq 0) {
                    $fileName += "Header.txt"
                }
                else {
                    $index = "{0:D$Digits}" -f ($i - 1)
                    $fileName += "$index.txt"
                }
                New-Item -Path "$pathBase\$fileName" -Value $sections[$i] -Force > $null
            }

            # Remove files of deleted items.
            $destFiles = Get-ChildItem -Path "$Dest\$group" | Where-Object { $_.Name -match "^$prefix\d+.txt$" } | Sort-Object
            $items = $sections.Count - 1
            if ($destFiles.Count -gt $items) {
                foreach ($destFile in $destFiles[$items..($destFiles.Count - 1)]) {
                    Remove-Item -Path $destFile
                }
            }
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

# Remove all map text files because when the maps are deleted, the files remain.
Remove-Item -Path "$txtDataDir\MapData\*" -Recurse -ErrorAction SilentlyContinue
Start-Process "$woditorDir\Editor.exe" "-txtoutput" -Wait

Split-Texts $txtDataDir $textsDir

. scripts\.util.ps1
Copy-Assets $dataDir $assetsDir
Copy-Others $dataDir $othersDir
# If there are no files in the Others folder, remove the folder.
if ((Get-ChildItem -Path $othersDir -Recurse -File).Count -eq 0) {
    Remove-Item -Path $othersDir -Recurse
}
