param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Locale)
$ErrorActionPreference = "Stop"

function Join-Texts([string]$Src, [string]$Dest) {
    Remove-Item -Path "$Dest\MapData\*" -Recurse -ErrorAction SilentlyContinue
    Copy-Item -Path "$Src\BasicData\Game.txt" -Destination "$Dest\BasicData\Game.dat.Auto.txt"
    foreach ($group in @("BasicData", "MapData")) {
        $directories = Get-ChildItem -Path "$Src\$group" -Attributes Directory
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
            $files = Get-ChildItem -Path $dir | Where-Object { $_.Name -match "^$prefix\d+.txt$" } | Sort-Object
            foreach ($file in $files) {
                $content += $delimiter + "`r`n" + [IO.File]::ReadAllText($file)
            }
            [IO.File]::WriteAllText("$Dest\$group\$destFileName", $content)
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
        exit 1
    }
}

Join-Texts $textsDir $txtDataDir

Start-Process "$woditorDir\Editor.exe" "-txtinput" -Wait

. scripts\.util.ps1
Copy-Assets $assetsDir $dataDir
Copy-Others $othersDir $dataDir
