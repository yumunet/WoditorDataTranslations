param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Locale)
$ErrorActionPreference = "Stop"

enum DBTypes {
    System
    User
    Variable
}

enum DataNameTypes {
    Manual
    FirstField
    PreviousType
    AnotherTypeByNumber
    AnotherTypeByName
}

function Convert-DataNameType([int]$Raw, [string]$LoadTypeName) {
    $type = $null
    $loadDB = $null
    $loadTypeNumber = $null
    $loadTypeName_ = $null
    if ($Raw -eq 0) {
        $type = [DataNameTypes]::Manual
    }
    elseif ($Raw -eq 1) {
        $type = [DataNameTypes]::FirstField
    }
    elseif ($Raw -eq 2) {
        $type = [DataNameTypes]::PreviousType
    }
    elseif (($Raw -ge 10000) -and ($Raw -le 39999)) {
        $type = [DataNameTypes]::AnotherTypeByNumber
        if ($Raw -le 19999) {
            $loadDB = [DBTypes]::System
            $loadTypeNumber = $Raw - 10000
        }
        elseif ($Raw -le 29999) {
            $loadDB = [DBTypes]::User
            $loadTypeNumber = $Raw - 20000
        }
        elseif ($Raw -le 39999) {
            $loadDB = [DBTypes]::Variable
            $loadTypeNumber = $Raw - 30000
        }
    }
    elseif (($Raw -eq 110000) -or ($Raw -eq 120000) -or ($Raw -eq 130000)) {
        $type = [DataNameTypes]::AnotherTypeByName
        $loadTypeName_ = $LoadTypeName
        if ($Raw -eq 110000) {
            $loadDB = [DBTypes]::System
        }
        elseif ($Raw -eq 120000) {
            $loadDB = [DBTypes]::User
        }
        elseif ($Raw -eq 130000) {
            $loadDB = [DBTypes]::Variable
        }
    }
    if ($null -eq $type) {
        Write-Error "Could not parse data name type: $Raw"
    }
    return @{
        "Type"           = $type
        "LoadDB"         = $loadDB
        "LoadTypeNumber" = $loadTypeNumber
        "LoadTypeName"   = $loadTypeName_
    }
}

function Import-OneDatabase([string]$DBTextsDir) {
    $DB = @()
    $files = Get-ChildItem -Path $DBTextsDir | Where-Object { $_.Name -match "^\d+.txt$" } | Sort-Object
    $typeIndex = 0
    foreach ($file in $files) {
        $content = [IO.File]::ReadAllText($file)
        
        $typeName = [Regex]::Match($content, "(?m)^TYPENAME=([^\r\n]+)").Groups[1].Value
        $dataNameTypeRaw = [int][Regex]::Match($content, "(?m)^DATANAME_LOAD_TYPE=(\d+)").Groups[1].Value
        $loadTypeName = [Regex]::Match($content, "(?m)^DATANAME_LOAD_NAME=([^\r\n]*)").Groups[1].Value
        $dataNameType = Convert-DataNameType $dataNameTypeRaw $loadTypeName
        $DB += @{
            "Name"         = $typeName
            "DataNameType" = $dataNameType
            "Data"         = @()
            "Fields"       = @()
        }

        # Data
        # The first line lists field names, so skip it.
        $csv = [Regex]::Match($content, "\r\n<<--CSV_START-->>\r\n.*?\r\n([\s\S]+)\r\n<<--CSV_END-->>\r\n").Groups[1].Value
        $dataMatches = $null
        if ($dataNameType["Type"] -eq [DataNameTypes]::Manual) {
            $dataMatches = [Regex]::Matches($csv, "(?m)^.+<<!--DATANAME--!>>(.*),\r\n")
        }
        elseif ($dataNameType["Type"] -eq [DataNameTypes]::FirstField) {
            $dataMatches = [Regex]::Matches($csv, "(?m)^""(.*?)(?<!"")""(?!"")") # " is escaped as "", so ignore it.
        }
        if ($null -ne $dataMatches) {
            foreach ($match in $dataMatches) {
                $DB[$typeIndex]["Data"] += $match.Groups[1].Value
            }
        }

        # Fields
        $fieldMatches = [Regex]::Matches($content, "(?m)^ITEMNAME\d+=([^\r\n]+)")
        foreach ($match in $fieldMatches) {
            $DB[$typeIndex]["Fields"] += $match.Groups[1].Value
        }

        $typeIndex++
    }
    return $DB
}

function Import-Databases([string]$TextsDir) {
    $DBs = @{}
    $DBs[[DBTypes]::Variable] = Import-OneDatabase "$TextsDir\BasicData\CDataBase"
    $DBs[[DBTypes]::User] = Import-OneDatabase "$TextsDir\BasicData\DataBase"
    $DBs[[DBTypes]::System] = Import-OneDatabase "$TextsDir\BasicData\SysDataBase"
    return $DBs
}

function Find-TypeName([Object[]]$Types, [string]$TypeName) {
    $index = 0;
    foreach ($type in $Types) {
        if ($type["Name"] -eq $TypeName) {
            break
        }
        $index++
    }
    if ($index -eq $oldDBs[$dbKey].Count) {
        return $null
    }
    return $index
}

function Get-ActualDBData([hashtable]$DBs, [DBTypes]$DBKey, [int]$TypeIndex) {
    $nameType = $DBs[$DBKey][$TypeIndex]["DataNameType"]
    switch ($nameType["Type"]) {
        { $_ -eq [DataNameTypes]::Manual -or
            $_ -eq [DataNameTypes]::FirstField } {
            return $DBs[$DBKey][$TypeIndex]["Data"]
        }
        [DataNameTypes]::PreviousType {
            return Get-ActualDBData $DBs $DBKey ($TypeIndex - 1)
        }
        [DataNameTypes]::AnotherTypeByNumber {
            return Get-ActualDBData $DBs $nameType["LoadDB"] $nameType["LoadTypeNumber"]
        }
        [DataNameTypes]::AnotherTypeByName {
            $loadDB = $nameType["LoadDB"]
            $loadTypeName = $nameType["LoadTypeName"]
            $loadTypeIndex = Find-TypeName $DBs[$loadDB] $loadTypeName
            if ($null -eq $loadTypeIndex) {
                Write-Error "Get-ActualDBData - Failed to find Type: $loadDB DB ""$loadTypeName"""
            }
            return Get-ActualDBData $DBs $loadDB $loadTypeIndex
        }
    }
    Write-Error "Missing implementation."
}

function Update-EventCode([string]$FilePath, [hashtable]$NewDBs, [hashtable]$OldDBs) {
    $content = [IO.File]::ReadAllText($FilePath)
    
    $eventCodes = [Regex]::Match($content, "\r\nWoditorEvCOMMAND_START\r\n([\s\S]+)\r\nWoditorEvCOMMAND_END\r\n").Groups[1].Value
    $dbCommandMatches = [Regex]::Matches($eventCodes, "(?m)^(\[(?:250|251|252)]\[\d+,\d+]<\d+>)\((-?\d+),(-?\d+),(-?\d+),(-?\d+)(,-?\d+)*\)\(""(.*?)"",""(.*?)"",""(.*?)"",""(.*?)""\)")
    foreach ($match in $dbCommandMatches) {
        $head = $match.Groups[1].Value
        $typeNumber = [int]$match.Groups[2].Value
        $dataNumber = [int]$match.Groups[3].Value
        $fieldNumber = [int]$match.Groups[4].Value
        $options = [int]$match.Groups[5].Value
        $otherNumbers = $match.Groups[6].Value
        $firstString = $match.Groups[7].Value
        $typeName = $match.Groups[8].Value
        $dataName = $match.Groups[9].Value
        $fieldName = $match.Groups[10].Value

        $dbKey = [DBTypes]::Variable
        if ($options -band 0x200) {
            $dbKey = [DBTypes]::User
        }
        elseif ($options -band 0x100) {
            $dbKey = [DBTypes]::System
        }

        # Find and overwrite
        $typeIndex = $typeNumber
        if ($typeName -ne "") {
            $index = Find-TypeName $OldDBs[$dbKey] $typeName
            if ($null -eq $index) {
                Write-Error "Failed to find Type: $dbKey DB ""$typeName"""
            }
            $typeName = $NewDBs[$dbKey][$index]["Name"]
            $typeIndex = $index
        }
        $typeIndexes = @($typeIndex)
        if ($typeNumber -ge 1000000) {
            # If a variable is specified, find from all Types.
            $typeIndexes = (0..($OldDBs[$dbKey].Count - 1))
            if ($dataName -ne "" -or $fieldName -ne "") {
                Write-Warning "Type is a variable. Incorrect mapping may occur. $FilePath $($match.Groups[0])"
            }
        }
        if ($dataName -ne "") {
            $successful = $false
            foreach ($typeIndex in $typeIndexes) {
                $index = (Get-ActualDBData $OldDBs $dbKey $typeIndex).IndexOf($dataName)
                if ($index -ne -1) {
                    $dataName = (Get-ActualDBData $NewDBs $dbKey $typeIndex)[$index]
                    $successful = $true
                    break
                }
            }
            if (-not $successful) {
                Write-Error "Failed to find Data: $dbKey DB ""$dataName"""
            }
        }
        if ($fieldName -ne "") {
            $successful = $false
            foreach ($typeIndex in $typeIndexes) {
                $index = $OldDBs[$dbKey][$typeIndex]["Fields"].IndexOf($fieldName)
                if ($index -ne -1) {
                    $fieldName = $NewDBs[$dbKey][$typeIndex]["Fields"][$index]
                    $successful = $true
                    break
                }
            }
            if (-not $successful) {
                Write-Error "Failed to find Field: $dbKey DB ""$fieldName"""
            }
        }

        # Replace
        $newEventCode = "$head($typeNumber,$dataNumber,$fieldNumber,$options$otherNumbers)(""$firstString"",""$typeName"",""$dataName"",""$fieldName"")"
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
The project directory before renaming databases is required:
  "$sourceDir"

Run the git command:
  git worktree add "$sourceDir" -b $sourceDirName

Or copy all files to that directory in advance, before renaming databases.
"@
}

$oldDBs = Import-Databases $sourceTextsDir
$newDBs = Import-Databases $textsDir

$files = Get-ChildItem -Path "$textsDir\BasicData\CommonEvent" | Where-Object { $_.Name -match "^\d+.txt$" }
foreach ($file in $files) {
    Update-EventCode $file $newDBs $oldDBs
}
$files = Get-ChildItem -Path "$textsDir\MapData" -Recurse | Where-Object { $_.Name -match "^Event_\d+.txt$" }
foreach ($file in $files) {
    Update-EventCode $file $newDBs $oldDBs
}

Write-Output "Update complete. Please import."
& "$PSScriptRoot\import.ps1" $Project $Locale || $(exit)
Write-Output "Imported. Exporting..."
& "$PSScriptRoot\export.ps1" $Project $Locale
