param([hashtable]$WoditorPaths)
$ErrorActionPreference = "Stop"

$root = Split-Path -Path $PSScriptRoot -Parent

if (-not $WoditorPaths) {
    Write-Error "The WoditorPaths parameter is required. Specify it in the following format: @{""ja-JP"" = ""C:\Woditor\Japanese""; ""en-US"" = ""C:\Woditor\English""}"
}

# Get all project names
$projectNames = @()
foreach ($subDir in Get-ChildItem -LiteralPath $root -Directory) {
    if (Test-Path -LiteralPath "$subDir\assets") {
        $projectNames += $subDir.Name
    }
}

# Update all Woditor files
foreach ($path in $WoditorPaths.GetEnumerator()) {
    & "$PSScriptRoot\install-woditor.ps1" $path.Key $path.Value
}

# Ask whether to export all projects
$choiceType = "System.Management.Automation.Host.ChoiceDescription"
$choice = $host.ui.PromptForChoice("Confirm", "Do you want to export all projects?", @((New-Object $choiceType "&No", "No"), (New-Object $choiceType "&Yes", "Yes")), 0)
if ($choice -eq 1) {
    # Launch and immediately close each editor (optional)
    $choice = $host.ui.PromptForChoice("Confirm", "Have system variable or system string names changed, or have new game settings been added? If you select Yes, each editor will be launched once to update the data.", @((New-Object $choiceType "&No", "No"), (New-Object $choiceType "&Yes", "Yes")), 0)
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
