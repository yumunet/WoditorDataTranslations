param([Parameter(Mandatory)][string]$Locale)
$ErrorActionPreference = "Stop"

$root = Split-Path -Path $PSScriptRoot -Parent
$originalDir = "$root\Extras\Version1Assets\original"
$langDir = "$root\Extras\Version1Assets\$Locale"
$outputDir = "$langDir\_output"

if ($Locale -eq "ja-JP" -or $Locale -eq "original") {
    Write-Error """$Locale"" cannot be specified"
}

if (Test-Path -LiteralPath $outputDir) {
    Remove-Item -LiteralPath $outputDir -Recurse
    New-Item -Path $outputDir -ItemType Directory > $null
}

$json = Get-Content -LiteralPath "$langDir\translations.json" -Raw | ConvertFrom-Json

$mapTileDir = "$outputDir\$($json.folder_names."Ver1用マップチップ[のりさん他]")"
$tileFile = "$mapTileDir\$($json.filenames."Ver1版マップチップ設定.tile")"
Copy-Item -LiteralPath "$originalDir\Ver1用マップチップ[のりさん他]" -Destination $mapTileDir -Recurse -Exclude "Ver1マップチップの使い方.txt", "Ver1版マップチップ設定.tile"
Copy-Item -LiteralPath "$langDir\document_map_tiles.txt" -Destination "$mapTileDir\$($json.filenames."Ver1マップチップの使い方.txt")"
Copy-Item -LiteralPath "$originalDir\Ver1用マップチップ[のりさん他]\Ver1版マップチップ設定.tile" -Destination $tileFile

Copy-Item -LiteralPath "$originalDir\モンスター素材[いそおきさん・すうさん]" -Destination "$outputDir\$($json.folder_names."モンスター素材[いそおきさん・すうさん]")" -Recurse

# Edit the tileset name in the .tile file
$enc = [System.Text.Encoding]::GetEncoding("shift_jis")
$tilesetName = $json.tile_binary_string."Ver1版マップチップ"
$nameBytes = $enc.GetBytes($tilesetName) + [byte]0
if ($tilesetName -ne $enc.GetString($nameBytes)) {
    Write-Warning("Cannot encode in shift_jis: ""$tilesetName""")
}
$lengthBytes = [System.BitConverter]::GetBytes([int32]$nameBytes.Length)

$bytes = [System.IO.File]::ReadAllBytes($tileFile)
$offset = 0xF
$oldDataLength = 4 + 19
$newBytes = $bytes[0..($offset - 1)] + $lengthBytes + $nameBytes + $bytes[($offset + $oldDataLength)..($bytes.Length - 1)]
[System.IO.File]::WriteAllBytes($tileFile, $newBytes)
