$Global:OtherFiles = @("*.txt")

function Copy-Assets([string]$Src, [string]$Dest) {
    robocopy $Src $Dest /mir /xf .gitkeep *.dat *.project $OtherFiles /xd MapData AutoBackup* > $null
    robocopy "$Src\BasicData" "$Dest\BasicData" MapTree.dat MapTreeOpenStatus.dat > $null
}

function Copy-Others([string]$Src, [string]$Dest) {
    robocopy $Src $Dest $OtherFiles /s > $null
}

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class Window {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder name, int count);
}
"@
function Start-AndKillEditor([string]$EditorPath) {
    $process = Start-Process -FilePath $EditorPath -PassThru

    while (-not $process.HasExited) {
        $process.Refresh()
        $name = [Text.StringBuilder]::new(256)
        [void][Window]::GetClassName($process.MainWindowHandle, $name, 256)

        if ($name.ToString().StartsWith("Afx")) {
            [void]$process.CloseMainWindow()
            break
        }

        Start-Sleep -Milliseconds 100
    }

    $process.WaitForExit()
    $process.Dispose()
}
