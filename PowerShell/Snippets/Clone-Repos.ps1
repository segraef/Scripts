Param(
    [string]$destinationFolder = ".",
    [string]$org = "x00",
)
# Make sure you have the Azure CLI installed and logged in via az login or az devops login
az devops configure --defaults organization=https://dev.azure.com/$org
$projects = az devops project list --organization=https://dev.azure.com/$org | ConvertFrom-Json
$repos = az repos list | ConvertFrom-Json

foreach ($project in $projects.value) {
    $repos = az repos list --project $($project.name) | ConvertFrom-Json
    foreach ($repo in $repos) {
        Write-Host "Repository [$repo.name] in project [$project.name]"
        git clone $($repo.remoteUrl) $destinationFolder/$($project.name)/$($repo.name)
    }
}
