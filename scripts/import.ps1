param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Locale)
$ErrorActionPreference = "Stop"

function Join-Texts([string]$Src, [string]$Dest) {
    Get-ChildItem -LiteralPath "$Dest\MapData" -File | Remove-Item
    Copy-Item -LiteralPath "$Src\BasicData\Game.txt" -Destination "$Dest\BasicData\Game.dat.Auto.txt"
    foreach ($group in @("BasicData", "MapData")) {
        $directories = Get-ChildItem -LiteralPath "$Src\$group" -Directory
        foreach ($dir in $directories) {
            $content = ""
            $destFileName = $dir.Name
            $prefix = ""
            $delimiter = $null
            if ($group -eq "BasicData") {
                if ($dir.Name -eq "CommonEvent") {
                    $delimiter = "--------------------------"
                    $destFileName += ".dat"
                }
                elseif ($dir.Name -eq "TileSetData") {
                    $delimiter = "---"
                    $destFileName += ".dat"
                }
                else {
                    $delimiter = "----"
                }
                $destFileName += ".Auto.txt"
            }
            elseif ($group -eq "MapData") {
                $content += [IO.File]::ReadAllText("$dir\Map.txt") + "----------`r`n"

                $prefix = "Event_"
                $delimiter = "-----"
                $destFileName += ".mps.Auto.txt"
            }

            $content += [IO.File]::ReadAllText("$dir\${prefix}Header.txt")
            $files = Get-ChildItem -LiteralPath $dir | Where-Object { $_.Name -match "^$prefix\d+.txt$" } | Sort-Object
            foreach ($file in $files) {
                $content += $delimiter + "`r`n" + [IO.File]::ReadAllText($file)
            }
            [IO.File]::WriteAllText("$Dest\$group\$destFileName", $content)
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

# Confirm
if (Test-Path -LiteralPath $woditorDataDir) {
    $typeName = "System.Management.Automation.Host.ChoiceDescription"
    $choice = $host.ui.PromptForChoice("Confirm", "Your current WOLF RPG Editor data will be overwritten.`nAre you sure you want to import?", @((New-Object $typeName "&No", "No"), (New-Object $typeName "&Yes", "Yes")), 0)
    if ($choice -eq 0) {
        exit 1
    }
}

Join-Texts $textsDir $woditorTextDir

Start-Process -FilePath "$woditorDir\Editor.exe" -ArgumentList "-txtinput" -Wait

. "$PSScriptRoot\.util.ps1"
if ($Locale -eq "ja-JP") {
    Copy-Assets $baseAssetsDir $woditorDataDir
}
else {
    Copy-Assets $baseAssetsDir $woditorDataDir
    if (Test-Path -LiteralPath $overrideAssetsDir) {
        robocopy $overrideAssetsDir $woditorDataDir /s > $null
    }
}
Copy-Others $othersDir $woditorDataDir

Write-Host "If WOLF RPG Editor is running, please restart it." -ForegroundColor Yellow
