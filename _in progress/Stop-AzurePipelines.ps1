# Replace the values in this for the variables with your own.
$AzureDevOpsPAT = "{Personal Access Token}"
$OrganizationName = "{DevOps Organization Name}"
$ProjectName = "{DevOps Project Name}"

$AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsPAT)")) }

$Uri= "https://dev.azure.com/$($OrganizationName)/$($ProjectName)/_apis/build/builds?statusFilter=notStarted&api-version=5.1"

$PendingJobs = Invoke-RestMethod -Uri $Uri -Headers $AzureDevOpsAuthenicationHeader -Method get -ContentType "application/json"
$JobsToCancel = $PendingJobs.value

ForEach($build in $JobsToCancel)
{
   $build.status = "Cancelling"
   $body = $build | ConvertTo-Json -Depth 10
   $urlToCancel = "https://dev.azure.com/$($OrganizationName)/$($ProjectName)/_apis/build/builds/$($build.id)?api-version=5.1"
   $urlToCancel
   # Invoke-RestMethod -Uri $urlToCancel -Method Patch -ContentType application/json -Body $body -Header $AzureDevOpsAuthenicationHeader
}