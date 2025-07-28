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
            # Exited by error
        }
        $commonEventName = $NewNames[$index]

        # Replace
        $newEventCode = "$head(""$commonEventName""$otherStringArgs)"
        $content = $content.Replace($match.Groups[0], $newEventCode)
    }

    [IO.File]::WriteAllText($FilePath, $content)
}

Set-Location (Split-Path -Path $PSScriptRoot -Parent)
$textsDir = "$Project\$Locale\texts"
$sourceDirName = "reference-update-source"
$sourceDir = "scripts\$sourceDirName"

if (-not (Test-Path -Path $sourceDir)) {
    Write-Output "The project directory before updating common events is required: $sourceDir"
    Write-Output "  Run the git command ""git worktree add $sourceDir -b $sourceDirName"""
    Write-Output "  or copy all files to that directory."
    exit 1
}

$oldNames = Import-CommonEventNames "$sourceDir\$textsDir"
$newNames = Import-CommonEventNames $textsDir

$files = Get-ChildItem -Path "$textsDir\BasicData\CommonEvent" | Where-Object { $_.Name -match "^\d+.txt$" } | Sort-Object
foreach ($file in $files) {
    Update-EventCode $file $newNames $oldNames
}
$files = Get-ChildItem -Path "$textsDir\BasicData\MapData" -Recurse | Where-Object { $_.Name -match "^Event_\d+.txt$" } | Sort-Object
foreach ($file in $files) {
    Update-EventCode $file $newNames $oldNames
}

Write-Output "Update complete. Please import."
.\scripts\import.ps1 $Project $Locale || $(exit)
Write-output "Imported. Exporting..."
.\scripts\export.ps1 $Project $Locale
