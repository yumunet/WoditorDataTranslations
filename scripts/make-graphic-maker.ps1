param([Parameter(Mandatory)][string]$Locale, [string]$Encoding)
$ErrorActionPreference = "Stop"

function Test-JsonEncoding([PSCustomObject]$Json) {
    $enc = [System.Text.Encoding]::GetEncoding($Encoding)
    foreach ($prop in $Json.PSObject.Properties) {
        $value = $prop.Value
        if ($value -is [string]) {
            $encodedValue = $enc.GetString($enc.GetBytes($value))
            if ($value -ne $encodedValue) {
                Write-Warning("Cannot encode in ${Encoding}: $value")
            }
        }
        elseif ($value -is [PSCustomObject]) {
            Test-JsonEncoding $value
        }
    }
}

function New-ExeFile() {
    Get-Command -Name "ResourceHacker" -ErrorAction SilentlyContinue > $null
    if (-not $?) {
        Write-Error "ResourceHacker is not found. Please add it to PATH."
    }

    $logFile = "$PSScriptRoot\temp.log"
    function Write-LogAndError([string]$message) {
        Write-Host (Get-Content -LiteralPath $logFile -Raw)
        Remove-Item -LiteralPath $logFile
        Write-Error $message
    }

    # Apply resources
    $tempResourceFile = "$outputDir\temp.res"
    cmd /c "ResourceHacker -open ""$langDir\app.rc"" -save ""$tempResourceFile"" -action compile -log ""$logFile"""
    if ($LASTEXITCODE -ne 0) { Write-LogAndError "Failed to compile app.rc" }

    cmd /c "ResourceHacker -open ""$originalDir\$exeName"" -save ""$outputDir\$exeName"" -action addoverwrite -resource ""$tempResourceFile"" -log ""$logFile"""
    Remove-Item -LiteralPath $tempResourceFile
    if ($LASTEXITCODE -ne 0) { Write-LogAndError "Failed to write $exeName" }

    # If there is a manifest, apply it as well
    $manifestFile = "$langDir\app.manifest"
    if (Test-Path -LiteralPath $manifestFile) {
        cmd /c "ResourceHacker -open ""$outputDir\$exeName"" -save ""$outputDir\$exeName"" -action addoverwrite -resource ""$manifestFile"" -mask MANIFEST,1, -log ""$logFile"""
        if ($LASTEXITCODE -ne 0) { Write-LogAndError "Failed to write manifest to $exeName" }
    }

    Remove-Item -LiteralPath $logFile

    # Edit strings within the binary
    Add-Type -TypeDefinition @"
using System;
public static class ByteSearch {
    public static int IndexOf(byte[] src, byte[] dest) {
        for (int i = 0; i <= src.Length - dest.Length; i++) {
            bool matched = true;
            for (int j = 0; j < dest.Length; j++) {
                if (src[i + j] != dest[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched)
                return i;
        }
        return -1;
    }
}
"@
    $exeBytes = [System.IO.File]::ReadAllBytes("$outputDir\$exeName")
    foreach ($prop in $json.binary_strings.PSObject.Properties) {
        if ($prop.Value -eq "") {
            Write-Warning "Translation is empty: binary_strings > $($prop.Name)"
            continue
        }
        # Encode the old string in Shift_JIS and the new string in the specified encoding
        $oldBytes = [System.Text.Encoding]::GetEncoding("shift_jis").GetBytes($prop.Name) + [byte]0
        $newBytes = [System.Text.Encoding]::GetEncoding($Encoding).GetBytes($prop.Value) + [byte]0
        if ($oldBytes.Length -lt $newBytes.Length) {
            Write-Warning "Translation is longer than the original: binary_strings > $($prop.Name)"
            continue
        }
        # Overwrite the old string with the new string
        $pos = [ByteSearch]::IndexOf($exeBytes, $oldBytes)
        if ($pos -eq -1) {
            Write-Error "Not found in the exe file: $($prop.Name)"
        }
        $newBytes.CopyTo($exeBytes, $pos)
        # Zero‑fill the remaining region
        for ($i = $newBytes.Length; $i -lt $oldBytes.Length; $i++) {
            $exeBytes[$pos + $i] = 0
        }
    }
    [System.IO.File]::WriteAllBytes("$outputDir\$exeName", $exeBytes)
}

function ConvertTo-FlatMap([PSCustomObject]$Node, [string]$CurrentPath = "", [string]$TranslatedPath = "") {
    $list = @()
    foreach ($prop in $Node.PSObject.Properties) {
        $key = $prop.Name
        $value = $prop.Value
        if ($key -eq "@translation") { continue }

        if ($value -is [string]) {
            # File
            $translation = $value
            if ($translation -eq "") {
                $translation = $key
                Write-Warning "Translation is empty: $CurrentPath\$key"
            }
            $list += [PSCustomObject]@{
                RelativePath = "$CurrentPath\$key"
                Translation  = "$TranslatedPath\$translation"
            }
        }
        elseif ($value -is [PSCustomObject]) {
            # Subdirectory
            if ($key -eq "Graphics") {
                # The Graphics directory is not translatable
                $translation = $key
            }
            else {
                $translation = $value."@translation"
                if ($null -eq $translation) {
                    $translation = $key
                    Write-Warning "@translation key does not exist: $CurrentPath\$key" 
                }
                elseif ($translation -eq "") {
                    $translation = $key
                    Write-Warning "Translation is empty: $CurrentPath\$key"
                }
            }
            $newPath = "$CurrentPath\$key"
            $newTranslatedPath = "$TranslatedPath\$translation"
            $list += [PSCustomObject]@{
                RelativePath = $newPath
                Translation  = $newTranslatedPath
            }
            $list += ConvertTo-FlatMap $value $newPath $newTranslatedPath
        }
    }
    return $list
}

function Copy-ImageFiles() {
    # Check if any files are missing from the JSON
    $actualItems = Get-ChildItem -LiteralPath $originalDir -Recurse
    foreach ($item in $actualItems) {
        # Ignore root files
        if ($item.DirectoryName -eq $originalDir) {
            continue
        }
        # Ignore Setting.txt
        if ($item.Name -eq "Setting.txt") {
            continue
        }

        $relativePath = $item.FullName.Substring($originalDir.Length)
        if (-not ($pathMap.RelativePath -contains $relativePath)) {
            Write-Warning "Item exists but not in JSON: $relativePath"
        }
    }

    # Copy files and directories using names provided in JSON
    foreach ($map in $pathMap) {
        $srcPath = $originalDir + $map.RelativePath
        if (-not (Test-Path -LiteralPath $srcPath)) {
            Write-Warning "Item not found in the original: $($map.RelativePath)"
            continue
        }
        $destPath = $outputDir + $map.Translation
        if (Test-Path -LiteralPath $destPath) {
            Write-Warning "Translation is duplicated: $($map.Translation)"
            continue
        }
        Copy-Item -LiteralPath $srcPath -Destination $destPath
    }

    # Delete unnecessary files
    function Get-TranslatedPath([string]$originalRelativePath) {
        $translation = $pathMap.Where({ $_.RelativePath -eq $originalRelativePath })[0].Translation
        if ($null -eq $translation) {
            Write-Error "No translation found: ""$originalRelativePath"""
        }
        return "$outputDir$translation"
    }

    $filePathsToRemove = @(
        "\Graphics\デフォルト規格\服\[女]雪国服[紫].png"     # Same as "[女]雪国服[紫2].png"
        "\Graphics\デフォルト規格\装飾\羽根なし帽[紫].png"   # Same as "羽根なし帽[紫2].png"
        "\Graphics\デフォルト規格\装飾\羽根なし帽[赤].png"   # Same as "羽根なし帽[赤2].png"
        "\Graphics\デフォルト規格\装飾\羽帽子.png"           # Same as "羽根付き帽[青1].png"
        "\Graphics\デフォルト規格\装飾\羽根付き帽[紫].png"   # Same as "羽根付き帽[紫2].png"
        "\Graphics\デフォルト規格\装飾\羽根付き帽[赤].png"   # Same as "羽根付き帽[赤2].png"
        "\Graphics\デフォルト規格\追加\クセ毛用鉢巻[白].png" # Same as "クセ毛用鉢巻[白2].png"
        "\Graphics\デフォルト規格\追加\鉢巻1[白].png"        # Same as "鉢巻1[白2].png"
        "\Graphics\デフォルト規格\頭\つんつん[赤]$.png"      # Almost the same as "つんつん[赤1]$.png"
        "\Graphics\デフォルト規格\頭\短髪[茶].png"           # Same as "短髪[茶1].png"
        "\Graphics\デフォルト規格\頭\短髪[茶]$.png"          # Same as "短髪[茶1]$.png"
        "\Graphics\デフォルト規格\頭追加\つけ癖毛1[茶].png"  # Same as "つけ癖毛1[茶1].png"
        "\Graphics\デフォルト規格_子供\装飾\[子]羽根なし帽[紫].png" # Same as "[子]羽根なし帽[紫2].png"
        "\Graphics\デフォルト規格_子供\装飾\[子]羽根なし帽[赤].png" # Same as "[子]羽根なし帽[赤2].png"
        "\Graphics\デフォルト規格_子供\装飾\[子]羽根付き帽[紫].png" # Same as "[子]羽根付き帽[紫2].png"
        "\Graphics\デフォルト規格_子供\装飾\[子]羽根付き帽[赤].png" # Same as "[子]羽根付き帽[赤2].png"
        "\Graphics\顔A[幼児192x192]（キタカライさんベース）\前髪\4下ろし髪D - コピー.png" # Same as "4下ろし髪D.png"
        "\Graphics\顔A[幼児192x192]（キタカライさんベース）\口\2ほほえみ口B.png"    # Same as "2への字.png"
        "\Graphics\顔B[少年192x192]（キタカライさんベース）\目\青年女_ハート目.png" # Blurry
        "\Graphics\顔C[青年男192x192]（キタカライさんベース）\まゆ\3りりしい2.png"  # Same as "2キリッ.png"
        "\Graphics\顔C[青年男192x192]（キタカライさんベース）\目\2まじめ目2.png"    # Same as "2まじめ目.png"
        "\Graphics\顔C[青年男192x192]（キタカライさんベース）\目\2まじめ目2$.png"   # Same as "2まじめ目$.png"
        "\Graphics\顔F[中年女192x192]（キタカライさんベース）\服\シンプル上着.png"  # Same as "ベスト.png"
        "\Graphics\顔F[中年女192x192]（キタカライさんベース）\服\シンプル上着$.png" # Same as "ベスト$.png"
        "\Graphics\顔F[中年女192x192]（キタカライさんベース）\前髪\4盛り髪.png"     # Same as "後ろ髪\4ｿﾌﾄｸﾘｰﾑ.png.png"
    )
    foreach ($path in $filePathsToRemove) {
        Remove-Item -LiteralPath (Get-TranslatedPath $path)
    }

    # Move some files to the appropriate locations
    Move-Item -LiteralPath (Get-TranslatedPath "\Graphics\顔F[中年女192x192]（キタカライさんベース）\アクセサリ\フリルエプロン.png")`
        -Destination "$(Get-TranslatedPath "\Graphics\顔F[中年女192x192]（キタカライさんベース）\服")\"

    Move-Item -LiteralPath (Get-TranslatedPath "\Graphics\顔C[青年男192x192]（キタカライさんベース）\口\2中年男ニヤリ.png")`
        -Destination "$(Get-TranslatedPath "\Graphics\顔E[中年男192x192]（キタカライさんベース）\口")\"

    # Add a front image to files that lack one
    $blankFrontImage = "$originalDir\Graphics\顔A[幼児192x192]（キタカライさんベース）\アクセサリ\羽[黒].png"
    $filePathsNoFrontImage = @(
        "\Graphics\顔C[青年男192x192]（キタカライさんベース）\服\電動装甲GC_背$.png"
        "\Graphics\顔D[青年女192x192]（キタカライさんベース）\アクセサリ\筒ヘアアクセ$.png"
        "\Graphics\顔D[青年女192x192]（キタカライさんベース）\アクセサリ\追加お団子ヘア$.png"
        "\Graphics\顔D[青年女192x192]（キタカライさんベース）\アクセサリ\追加みつあみヘア$.png"
        "\Graphics\顔E[中年男192x192]（キタカライさんベース）\ベース装飾\げっそり$.png"
        "\Graphics\顔E[中年男192x192]（キタカライさんベース）\ベース装飾\しわ影$.png"
        "\Graphics\顔E[中年男192x192]（キタカライさんベース）\ベース装飾\目元傷右$.png"
        "\Graphics\顔E[中年男192x192]（キタカライさんベース）\ベース装飾\目元傷左$.png"
    )
    foreach ($path in $filePathsNoFrontImage) {
        $TranslatedPath = Get-TranslatedPath $path
        if ($TranslatedPath -notmatch "\$\.png$") {
            Write-Warning "Does not end with `$: $TranslatedPath"
            continue
        }
        Copy-Item -LiteralPath $blankFrontImage -Destination ($TranslatedPath -replace "\$\.png$", ".png")
    }
}

function New-SettingFiles() {
    function Get-ExeTranslation([string]$original) {
        $translation = $json.binary_strings.$original
        if ($null -eq $translation) {
            Write-Warning """$original"" key does not exist in binary_strings"
        }
        elseif ($translation -eq "") {
            Write-Warning """$original"" key translation in binary_strings is empty"
        }
        return $translation
    }

    $headers = @()
    $enc = [System.Text.Encoding]::GetEncoding($Encoding)
    for ($i = 0; $i -lt 2; $i++) {
        $filename = "setting_header$($i+1).txt"
        $content = Get-Content -LiteralPath "$langDir\$filename" -Raw
        
        # Test the encoding
        $encodedContent = $enc.GetString($enc.GetBytes($content))
        if ($content -ne $encodedContent) {
            Write-Warning "Cannot encode in ${Encoding}: $filename"
        }

        $headers += , $($content -split "`r`n")
    }

    $settingFiles = Get-ChildItem -LiteralPath $originalDir -Filter "Setting.txt" -Recurse
    foreach ($file in $settingFiles) {
        $content = Get-Content -LiteralPath $file -Encoding "shift_jis"
        $dirRelativePath = $file.DirectoryName.Substring($originalDir.Length)

        $headerIndex = -1
        $originalHeaderLineCount = 0
        $dirName = $file.Directory.Name
        if ($dirName.StartsWith("デフォルト規格")) {
            $headerIndex = 0
            $originalHeaderLineCount = 17
        }
        elseif ($dirName.StartsWith("顔")) {
            $headerIndex = 1
            $originalHeaderLineCount = 36
        }
        else {
            Write-Error "Unknown directory: $dirName"
        }

        $newContent = $headers[$headerIndex]
        for ($i = $originalHeaderLineCount; $i -lt $content.Count; $i++) {
            $line = $content[$i]
            if ($line.StartsWith("#")) {
                # Comment
                $prop = $json.setting_comments.PSObject.Properties.Where({ $_.Name -eq $line })[0]
                if ($null -eq $prop) {
                    Write-Warning "A comment not present in JSON was found: $line"
                    continue
                }
                if ($prop.Value -eq "") {
                    Write-Warning "A comment translation is empty: $line"
                    continue
                }
                $line = $prop.Value
            }
            elseif ($line.StartsWith("連動パーツ:")) {
                # Linked Parts Settings
                $directoryNames = ($line -replace "^連動パーツ:") -split ","
                $newDirectoryNames = @()
                foreach ($name in $directoryNames) {
                    $dirTranslation = $pathMap.Where({ $_.RelativePath -eq "$dirRelativePath\$name" })[0].Translation
                    $newName = Split-Path -Path $dirTranslation -Leaf
                    $newDirectoryNames += $newName
                }

                $newSettingName = Get-ExeTranslation "連動パーツ:"
                $line = $newSettingName + ($newDirectoryNames -join ",")
            }
            else {
                # Folder Settings
                $match = [Regex]::Match($line, "^(.+)=(.+)")
                if ($match.Success) {
                    $key = $match.Groups[1].Value
                    $value = $match.Groups[2].Value
                    
                    $dirTranslation = $pathMap.Where({ $_.RelativePath -eq "$dirRelativePath\$key" })[0].Translation
                    $newKey = Split-Path -Path $dirTranslation -Leaf

                    $newValue = $value
                    $newValue = $newValue -replace "表", (Get-ExeTranslation "表")
                    $newValue = $newValue -replace "裏", (Get-ExeTranslation "裏")

                    $line = "$newKey=$newValue"
                }
            }
            $newContent += $line
        }

        # Write Setting.txt in the specified encoding
        $translatedDirPath = $pathMap.Where({ $_.RelativePath -eq $dirRelativePath })[0].Translation
        if (-not (Test-Path -LiteralPath "${outputDir}$translatedDirPath")) {
            New-Item -Path "${outputDir}$translatedDirPath" -ItemType Directory > $null
        }
        Set-Content -LiteralPath "${outputDir}$translatedDirPath\$($file.Name)" -Value $newContent -Encoding $Encoding
    }
}

$root = Split-Path -Path $PSScriptRoot -Parent
$originalDir = "$root\Extras\GraphicMaker\original"
$langDir = "$root\Extras\GraphicMaker\$Locale"
$outputDir = "$langDir\_output"
$exeName = "GraphicMaker.exe"

if ($Locale -eq "ja-JP" -or $Locale -eq "original") {
    Write-Error """$Locale"" cannot be specified"
}

if ($Encoding -eq "") {
    if ($Locale -eq "en-US") {
        $Encoding = "us-ascii"
    }
    else {
        Write-Error "Please specify the encoding"
    }
}

# Clear output directory
if (Test-Path -LiteralPath $outputDir) {
    Remove-Item -LiteralPath $outputDir -Recurse
    New-Item -Path $outputDir -ItemType Directory > $null
}

# Load translations.json and test the encoding
$json = Get-Content -LiteralPath "$langDir\translations.json" -Raw | ConvertFrom-Json
Test-JsonEncoding $json

Write-Host "Patching the exe file..."
New-ExeFile

$pathMap = ConvertTo-FlatMap $json.image_filenames

Write-Host "Copying all image files..."
Copy-ImageFiles

Write-Host "Making Setting.txt files..."
New-SettingFiles

Write-Host "Copying document files..."
Copy-Item -LiteralPath "$langDir\document_preview_image.txt" -Destination "$outputDir\$($json.document_filenames."合成器でプレビュー画像が表示されない人へ.txt")"
Copy-Item -LiteralPath "$langDir\document_readme.txt" -Destination "$outputDir\$($json.document_filenames."説明書・パーツ規格について.txt")"

Write-Host "Done!"
