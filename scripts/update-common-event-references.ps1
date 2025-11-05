param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Locale)
$ErrorActionPreference = "Stop"

function Import-CommonEventNames([string]$TextsDir) {
    $names = @()
    $files = Get-ChildItem -Path "$TextsDir\BasicData\CommonEvent" | Where-Object { $_.Name -match "^\d+.txt$" } | Sort-Object
    foreach ($file in $files) {
        $content = [IO.File]::ReadAllText($file)
        $names += [Regex]::Match($content, "(?m)^COMMON_NAME=([^\r\n]+)").Groups[1].Value
    }
    return $names
}

function Update-EventCode([string]$FilePath, [string[]]$NewNames, [string[]]$OldNames) {
    $content = [IO.File]::ReadAllText($FilePath)
    
    $eventCodes = [Regex]::Match($content, "\r\nWoditorEvCOMMAND_START\r\n([\s\S]+)\r\nWoditorEvCOMMAND_END\r\n").Groups[1].Value
    $commonEventCommandMatches = [Regex]::Matches($eventCodes, "(?m)^(\[300]\[\d+,\d+]<\d+>\(-?\d+(?:,-?\d+)*\))\(""(.*?)""((?:,"".*?"")*)\)")
    foreach ($match in $commonEventCommandMatches) {
        $head = $match.Groups[1].Value
        $commonEventName = $match.Groups[2].Value
        $otherStringArgs = $match.Groups[3].Value

        $index = $OldNames.IndexOf($commonEventName)
        if ($index -eq -1) {
            Write-Error "Failed to find Common Event: ""$commonEventName"""
        }
        $commonEventName = $NewNames[$index]

        # Replace
        $newEventCode = "$head(""$commonEventName""$otherStringArgs)"
        $content = $content.Replace($match.Groups[0], $newEventCode)
    }

    [IO.File]::WriteAllText($FilePath, $content)
}

$root = Split-Path -Path $PSScriptRoot -Parent
$textsDir = "$root\$Project\$Locale\texts"
$sourceDirName = "reference-update-source"
$sourceDir = "$PSScriptRoot\$sourceDirName"
$sourceTextsDir = "$sourceDir\$Project\$Locale\texts"

if (-not (Test-Path -Path $sourceDir)) {
    Write-Error @"
The project directory before renaming common events is required:
  "$sourceDir"

Run the git command:
  git worktree add "$sourceDir" -b $sourceDirName

Or copy all files to that directory in advance, before renaming common events.
"@
}

$oldNames = Import-CommonEventNames $sourceTextsDir
$newNames = Import-CommonEventNames $textsDir

$files = Get-ChildItem -Path "$textsDir\BasicData\CommonEvent" | Where-Object { $_.Name -match "^\d+.txt$" }
foreach ($file in $files) {
    Update-EventCode $file $newNames $oldNames
}
$files = Get-ChildItem -Path "$textsDir\MapData" -Recurse | Where-Object { $_.Name -match "^Event_\d+.txt$" }
foreach ($file in $files) {
    Update-EventCode $file $newNames $oldNames
}

Write-Output "Update complete. Please import."
& "$PSScriptRoot\import.ps1" $Project $Locale || $(exit)
Write-Output "Imported. Exporting..."
& "$PSScriptRoot\export.ps1" $Project $Locale
