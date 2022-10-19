Param(
   [string]$org = "x00",
   [string]$project = "Modules",
   [string]$token = "token"
)

az devops configure --defaults organization=https://dev.azure.com/$org project=$project
# $repos = az repos list --query "[].[id]" -o table
$repos = az repos list | ConvertFrom-Json

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
# Disable Repository
$json = '{ "isDisabled" : "false" }'
foreach($repo in $repos){
    $uri = "https://dev.azure.com/$org/$project/_apis/git/repositories/$($repo.id)" + "?api-version=6.0"
    Write-Host $repo.name
    $result = Invoke-RestMethod -Uri $uri -Method Patch -Body $json -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
    $result
}
