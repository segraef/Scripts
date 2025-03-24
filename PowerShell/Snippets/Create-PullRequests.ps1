Param(
   [string]$org = "x00",
   [string]$project = "Modules",
   [string]$token = "token",
   [string]$branchName = "users/segraef/provider-upgrade"
)

az extension add --name azure-devops

Write-Output $token | az devops login --organization https://dev.azure.com/$org
az devops configure --defaults organization=https://dev.azure.com/$org project=$project
$repos = az repos list | ConvertFrom-Json

# Create Pull Request on all repos
foreach($repo in $repos){
    Write-Output $repo.name
    az repos pr create --repository $repo.name --source-branch $branchName --open --output table
}

