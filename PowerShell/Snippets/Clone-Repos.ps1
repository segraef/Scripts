Param(
   [string]$destinationFolder = ".",
   [string]$org = "x00",
   [string]$project = "Modules"
)

az devops configure --defaults organization=https://dev.azure.com/$org project=$project
$repos = az repos list | ConvertFrom-Json

foreach($repo in $repos) {
   git clone $($repo.remoteUrl) $destinationFolder/$($repo.Name)
}
