param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Locale)
$ErrorActionPreference = "Stop"

function Split-Texts([string]$Src, [string]$Dest) {
    foreach ($group in @("BasicData", "MapData")) {
        $files = Get-ChildItem -Path "$Src\$group\*" -Include *.Auto.txt
        foreach ($file in $files) {
            $basePath = "$Dest\$group\" + ($file.Name -replace "\..+", "")

            if (($group -eq "BasicData") -and ($file.Name -eq "Game.dat.Auto.txt")) {
                Copy-Item -Path $file -Destination "$basePath.txt"
                continue
            }

            if (-not (Test-Path -Path $basePath)) {
                New-Item -Path $basePath -ItemType Directory > $null
            }

            $content = [IO.File]::ReadAllText($file)
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
                [IO.File]::WriteAllText("$basePath\Map.txt", $parts[0])
                
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
                [IO.File]::WriteAllText("$basePath\$fileName", $sections[$i])
            }

            # Remove files for deleted items.
            $destFiles = Get-ChildItem -Path "$basePath" | Where-Object { $_.Name -match "^$prefix\d+.txt$" } | Sort-Object
            $items = $sections.Count - 1
            if ($destFiles.Count -gt $items) {
                foreach ($destFile in $destFiles[$items..($destFiles.Count - 1)]) {
                    Remove-Item -Path $destFile
                }
            }
        }
    }

    # Remove files for deleted maps.
    $destMapDirs = Get-ChildItem -Path "$Dest\MapData" -Directory
    foreach ($mapDir in $destMapDirs) {
        if (-not (Test-Path -Path "$Src\MapData\$($mapDir.Name).mps.Auto.txt")) {
            Remove-Item -Path $mapDir -Recurse
        }
    }
}

$root = Split-Path -Path $PSScriptRoot -Parent
$assetsDir = "$root\$Project\assets"
$langDir = "$root\$Project\$Locale"
$woditorDir = "$langDir\_woditor"
$woditorDataDir = "$woditorDir\Data"
$woditorTextDir = "$woditorDir\Data_AutoTXT"
$textsDir = "$langDir\texts"
$othersDir = "$langDir\others"

# Clear previously exported map text files, since files from deleted maps may remain.
Remove-Item -Path "$woditorTextDir\MapData\*" -Recurse -ErrorAction SilentlyContinue
Start-Process -FilePath "$woditorDir\Editor.exe" -ArgumentList "-txtoutput" -Wait

Split-Texts $woditorTextDir $textsDir

. "$PSScriptRoot\.util.ps1"
Copy-Assets $woditorDataDir $assetsDir
Copy-Others $woditorDataDir $othersDir
# If empty, remove the others directory.
if ((Get-ChildItem -Path $othersDir -Recurse -File).Count -eq 0) {
    Remove-Item -Path $othersDir
}
