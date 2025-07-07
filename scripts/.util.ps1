$Script:otherFiles = "*.txt"

function Copy-Assets([string]$Src, [string]$Dest) {
    robocopy $Src $Dest /mir /xf *.dat *.project $otherFiles /xd MapData AutoBackup* > $null
    robocopy "$Src\BasicData" "$Dest\BasicData" MapTree.dat MapTreeOpenStatus.dat > $null
}

function Copy-Others([string]$Src, [string]$Dest) {
    robocopy $Src $Dest $otherFiles /s /purge > $null
}
