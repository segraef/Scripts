Param(
   [string]$org = "x00",
   [string]$project = "Modules",
   [string]$token = "token",
   [string]$branchName = "users/segraef/provider-upgrade"
)

az extension add --name azure-devops

echo $token | az devops login --organization https://dev.azure.com/$org
az devops configure --defaults organization=https://dev.azure.com/$org project=$project
$repos = az repos list | ConvertFrom-Json

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))

# Create Pull Request on all repos
foreach($repo in $repos){
    Write-Host $repo.name
    # az repos pr create --repository $repo.name --source-branch $branchName --open --output table
}

