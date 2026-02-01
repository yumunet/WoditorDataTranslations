param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Locale, [string]$Tag = (Get-Date).ToString("yyyy-MM-dd"))
$ErrorActionPreference = "Stop"

$root = Split-Path -Path $PSScriptRoot -Parent
$outputDir = "$root\releases"
$outputFile = "$outputDir\${Project}_${Locale}_${Tag}.zip"

if (-not (Test-Path -Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory > $null
}

if ($Project -eq "Extras") {
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    function Compress-ArchiveWithDirectory([string[]]$sources, [string]$dest, [string]$dirName) {
        # Always -Force
        if (Test-Path -LiteralPath $dest) {
            Remove-Item -LiteralPath $dest
        }
        try {
            $zip = [System.IO.Compression.ZipFile]::Open($dest, 'Create')
            foreach ($src in $sources) {
                if (Test-Path -LiteralPath $src -PathType Container) {
                    Get-ChildItem -LiteralPath $src -Recurse -File | ForEach-Object {
                        $relative = $_.FullName.Substring($src.Length + 1)
                        $entryPath = "$dirName\$relative"
                        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entryPath) > $null
                    }
                }
                else {
                    $filename = Split-Path -Path $src -Leaf
                    $entryPath = "$dirName\$filename"
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $src, $entryPath) > $null
                }
            }
        }
        finally {
            $zip.Dispose()
        }
    }
    
    $tempZip1 = "$outputDir\GraphicMaker.zip"
    $tempZip2 = "$outputDir\Version1Assets.zip"
    Compress-ArchiveWithDirectory "$root\$Project\GraphicMaker\$Locale\_output" $tempZip1 "GraphicMaker"
    Compress-ArchiveWithDirectory "$root\$Project\Version1Assets\$Locale\_output" $tempZip2 "Version1Assets"
    Compress-ArchiveWithDirectory ($tempZip1, $tempZip2, "$root\$Project\Others\$Locale") $outputFile "$Project"
    Remove-Item -LiteralPath $tempZip1, $tempZip2
}
else {
    $langDir = "$root\$Project\$Locale"
    $woditorDataDir = "$langDir\_woditor\Data"
    
    & "$PSScriptRoot\import.ps1" $Project $Locale || $(exit 1)
    Remove-Item -Path "$woditorDataDir\BasicData\AutoBackup*" -Recurse -ErrorAction SilentlyContinue
    
    Compress-Archive -Path $woditorDataDir, "$langDir\*.*" -DestinationPath $outputFile -Force
}
