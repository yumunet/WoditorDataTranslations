param([Parameter(Mandatory)][string]$NewWoditorPath)
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Export-ZipResource([string]$InputPath, [string]$OutputPath, [int]$ResourceID) {
    $temp = "$OutputPath.zip"
    cmd /c "ResourceHacker -open ""$InputPath"" -save ""$temp"" -action extract -mask ZIP,$ResourceID"
    if (-not (Test-Path -LiteralPath $temp)) { 
        Write-Error "Failed to extract ZIP resource $ResourceID from $InputPath"
    }

    if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Recurse }
    # Japanese filenames use CP932 (Windows Shift_JIS)
    [IO.Compression.ZipFile]::ExtractToDirectory($temp, $OutputPath, [Text.Encoding]::GetEncoding(932))

    Remove-Item -LiteralPath $temp
}

$root = Split-Path -Path $PSScriptRoot -Parent

# Extract empty data files from Editor.exe
$baseSystemEmptyDataDir = "$NewWoditorPath\1666"
$completelyEmptyDataDir = "$NewWoditorPath\1667"

Get-Command -Name "ResourceHacker" -ErrorAction SilentlyContinue > $null
if (-not $?) {
    Write-Error "ResourceHacker is not found. Please add it to PATH."
}

$editorPath = "$NewWoditorPath\Editor.exe"
if (-not (Test-Path -LiteralPath $editorPath)) {
    Write-Error "Editor.exe not found: $editorPath"
}

Export-ZipResource $editorPath $baseSystemEmptyDataDir 1666
Export-ZipResource $editorPath $completelyEmptyDataDir 1667

# Place each Data directory
$dataDirMap = @{
    "BaseSystemEmptyData" = $baseSystemEmptyDataDir
    "CompletelyEmptyData" = $completelyEmptyDataDir 
    "SampleGame"          = $NewWoditorPath
}
foreach ($map in $dataDirMap.GetEnumerator()) {
    $src = "$($map.Value)\Data"
    $dest = "$root\$($map.Key)\ja-JP\_woditor\Data"

    if (-not (Test-Path -LiteralPath $src -PathType Container)) {
        Write-Error "Source directory not found: $src"
    }

    if (Test-Path -LiteralPath $dest -PathType Container) {
        Remove-Item -LiteralPath $dest -Recurse
    }
    Copy-Item -LiteralPath $src -Destination $dest -Recurse
}

# Launch and immediately close each ja-JP editor, then export the projects
. "$PSScriptRoot\.util.ps1"
$projectNames = @("BaseSystemEmptyData", "CompletelyEmptyData", "SampleGame")
foreach ($project in $projectNames) {
    Start-AndKillEditor "$root\$project\ja-JP\_woditor\Editor.exe"
}

foreach ($project in $projectNames) {
    & "$PSScriptRoot\export.ps1" $project "ja-JP"
}

Write-Host "Please update and export the other locales manually."
