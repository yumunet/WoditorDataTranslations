param([hashtable]$WoditorPaths)
$ErrorActionPreference = "Stop"

$root = Split-Path -Path $PSScriptRoot -Parent

if (-not $WoditorPaths) {
    Write-Error "The WoditorPaths parameter is required. Specify it in the following format: @{""ja-JP"" = ""C:\Woditor\Japanese""; ""en-US"" = ""C:\Woditor\English""}"
}

# Get all project names
. "$PSScriptRoot\.util.ps1"
$projectNames = Get-ProjectNames

# Update all Woditor files
foreach ($path in $WoditorPaths.GetEnumerator()) {
    & "$PSScriptRoot\install-woditor.ps1" $path.Key $path.Value
}

# Ask whether to export all projects
$choiceType = "System.Management.Automation.Host.ChoiceDescription"
$choice = $host.ui.PromptForChoice("Confirm", "Do you want to export all projects? This is necessary if the command text or Auto.txt format has changed.", @((New-Object $choiceType "&No", "No"), (New-Object $choiceType "&Yes", "Yes")), 1)
if ($choice -eq 1) {
    # Launch and immediately close each editor (optional)
    $choice = $host.ui.PromptForChoice("Confirm", "Do you want to launch each editor once? This is necessary if system variable or system string names have changed, or new game settings have been added.", @((New-Object $choiceType "&No", "No"), (New-Object $choiceType "&Yes", "Yes")), 1)
    if ($choice -eq 1) {
        . "$PSScriptRoot\.util.ps1"
        foreach ($locale in $WoditorPaths.Keys) {
            foreach ($project in $projectNames) {
                Start-AndKillEditor "$root\$project\$locale\_woditor\Editor.exe"
            }
        }
    }

    # Export projects
    foreach ($locale in $WoditorPaths.Keys) {
        foreach ($project in $projectNames) {
            & "$PSScriptRoot\export.ps1" $project $locale
        }
    }
}
