param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Locale)
$ErrorActionPreference = "Stop"

function Split-Texts([string]$Src, [string]$Dest) {
    foreach ($group in @("BasicData", "MapData")) {
        $files = Get-ChildItem -LiteralPath "$Src\$group" -Filter "*.Auto.txt"
        foreach ($file in $files) {
            $basePath = "$Dest\$group\" + ($file.Name -replace "\..+", "")

            if (($group -eq "BasicData") -and ($file.Name -eq "Game.dat.Auto.txt")) {
                Copy-Item -LiteralPath $file -Destination "$basePath.txt"
                continue
            }

            if (-not (Test-Path -LiteralPath $basePath)) {
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
            $destFiles = Get-ChildItem -LiteralPath $basePath | Where-Object { $_.Name -match "^$prefix\d+.txt$" } | Sort-Object
            $items = $sections.Count - 1
            if ($destFiles.Count -gt $items) {
                foreach ($destFile in $destFiles[$items..($destFiles.Count - 1)]) {
                    Remove-Item -LiteralPath $destFile
                }
            }
        }
    }

    # Remove files for deleted maps.
    $destMapDirs = Get-ChildItem -LiteralPath "$Dest\MapData" -Directory
    foreach ($mapDir in $destMapDirs) {
        if (-not (Test-Path -LiteralPath "$Src\MapData\$($mapDir.Name).mps.Auto.txt")) {
            Remove-Item -LiteralPath $mapDir -Recurse
        }
    }
}

$root = Split-Path -Path $PSScriptRoot -Parent
$baseAssetsDir = "$root\$Project\assets"
$langDir = "$root\$Project\$Locale"
$woditorDir = "$langDir\_woditor"
$woditorDataDir = "$woditorDir\Data"
$woditorTextDir = "$woditorDir\Data_AutoTXT"
$overrideAssetsDir = "$langDir\assets"
$textsDir = "$langDir\texts"
$othersDir = "$langDir\others"

# Clear previously exported map text files, since files from deleted maps may remain.
Get-ChildItem -LiteralPath "$woditorTextDir\MapData" | Remove-Item -Recurse

Start-Process -FilePath "$woditorDir\Editor.exe" -ArgumentList "-txtoutput" -Wait

Split-Texts $woditorTextDir $textsDir

. "$PSScriptRoot\.util.ps1"
if ($Locale -eq "ja-JP") {
    # For the original, update the assets directly.
    Copy-Assets $woditorDataDir $baseAssetsDir

    # To track empty directories with Git, add a .gitkeep file inside them.
    $assetDirs = Get-ChildItem -LiteralPath $baseAssetsDir -Recurse -Directory
    foreach ($dir in $assetDirs) {
        if ((Get-ChildItem -LiteralPath $dir -Recurse).Count -eq 0) {
            New-Item -Path "$dir\.gitkeep" > $null
        }
    }
}
else {
    # For translations, copy asset files that differ from the original into project-specific assets.
    
    $baseAssetFiles = Get-ChildItem -LiteralPath $baseAssetsDir -Recurse -File -Exclude MapTree.dat, MapTreeOpenStatus.dat
    $currentAssetFiles = Get-ChildItem -LiteralPath $woditorDataDir -Recurse -File -Exclude (@("*.mps", "*.dat", "*.project") + $OtherFiles)
    # To prevent an error, replace null with an empty array when there are no files.
    $baseAssetFiles ??= @()
    $currentAssetFiles ??= @()
    $diffFiles = Compare-Object -ReferenceObject $baseAssetFiles -DifferenceObject $currentAssetFiles -PassThru -Property Name, Length
    foreach ($file in $diffFiles) {
        if ($file.FullName.StartsWith($woditorDataDir)) {
            $relativePath = $file.FullName.Substring($woditorDataDir.Length + 1)
            $assetDestFile = "$overrideAssetsDir\$relativePath"
            if (Test-Path -LiteralPath $assetDestFile) {
                # If the same file is already copied, skip it.
                if ((Get-ItemProperty -LiteralPath $assetDestFile).LastWriteTime -eq $file.LastWriteTime) {
                    continue
                }
            }
            $assetDestDir = Split-Path -Path $assetDestFile -Parent
            if (-not (Test-Path -LiteralPath $assetDestDir)) {
                New-Item -Path $assetDestDir -ItemType Directory > $null
            }
            Copy-Item -LiteralPath $file -Destination $assetDestFile
        }
        else {
            # Warn about missing files.
            $relativePath = $file.FullName.Substring($baseAssetsDir.Length + 1)
            $assetFile = "$woditorDataDir\$relativePath"
            if (-not (Test-Path -LiteralPath $assetFile)) {
                Write-Warning "Found a missing asset file: ""$relativePath"""
            }
        }
    }
    # Remove override asset files that were deleted from the Data directory.
    $overrideAssetFiles = Get-ChildItem -LiteralPath $overrideAssetsDir -Recurse -File
    foreach ($file in $overrideAssetFiles) {
        $relativePath = $file.FullName.Substring($overrideAssetsDir.Length + 1)
        if (-not (Test-Path -LiteralPath "$woditorDataDir\$relativePath")) {
            Remove-Item -LiteralPath $file
        }
    }
}
Copy-Others $woditorDataDir $othersDir
# If empty, remove the others directory.
if ((Get-ChildItem -LiteralPath $othersDir -Recurse -File).Count -eq 0) {
    Remove-Item -LiteralPath $othersDir -Recurse
}
