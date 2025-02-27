# Define the list of Azure DevOps project names
$organization = "org1"
$pat = "<pat>"
$projects = @(
  [PSCustomObject]@{
    name = "project1"
  }
)
$VerbosePreference = 'Continue'

# Log in to Azure DevOps using PAT
$env:AZURE_DEVOPS_EXT_PAT = "$pat"

# Function to get all projects in the organization
function Get-AdoProjects {
  $uri = "https://dev.azure.com/$organization/_apis/projects?api-version=6.0"
  $response = Invoke-RestMethod -Uri $uri -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat")) }
  return $response.value
}

# Function to get repositories for a given project
function Get-AdoRepositories($project) {
  $uri = "https://dev.azure.com/$organization/$project/_apis/git/repositories?api-version=6.0"
  $uri = $uri -replace " ", "%20"
  $response = Invoke-RestMethod -Uri $uri -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat")) }
  return $response.value
}

# Function to get all Azure Pipelines
function Get-AdoPipelines($project) {
  $uri = "https://dev.azure.com/$organization/$project/_apis/pipelines?api-version=6.0"
  $uri = $uri -replace " ", "%20"
  $response = Invoke-RestMethod -Uri $uri -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat")) }
  return $response.value
}

# Function to get all build policies
function Get-AdoBuildPolicies($project) {
  $uri = "https://dev.azure.com/$organization/$project/_apis/policy/configurations?api-version=6.0"
  $uri = $uri -replace " ", "%20"
  $response = Invoke-RestMethod -Uri $uri -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat")) }
  return $response.value
}

function CreateBuildValidationPolicy($project, $repo, $buildDefinition) {
  # check matching policies
  $matchingPolicies = $buildPolicies | Where-Object { $_.settings.buildDefinitionId -eq $buildDefinition.id }
  if ($matchingPolicies) {
    Write-Verbose "Policy already exists for $($repo.name) using pipeline $($buildDefinition.name). Updating."
    az repos policy build update `
      --id $matchingPolicies.id `
      --blocking $false `
      --branch main `
      --build-definition-id $buildDefinition.id `
      --display-name $repo.name `
      --enabled $true `
      --manual-queue-only $false `
      --queue-on-source-update-only $false `
      --repository-id $repo.id `
      --valid-duration 0 `
      --project $project.name

      # Build Validation Policy
      # --blocking $false                     - Policy Requirement: Optional
      # --manual-queue-only $false            - Trigger: Manual
      # --valid-duration 0                    - Build expiration: Immediately when main is updated
  } else {
    Write-Verbose "Creating build validation policy for $($repo.name) using pipeline $($buildDefinition.name)."
    az repos policy build create `
      --blocking $false `
      --branch main `
      --build-definition-id $buildDefinition.id `
      --display-name $repo.name `
      --enabled $true `
      --manual-queue-only $false `
      --queue-on-source-update-only $false `
      --repository-id $repo.id `
      --valid-duration 0 `
      --project $project.name
  }
}

# Main script
Write-Verbose "Getting projects ..."
if ($projects.Count -eq 0) {
  Write-Verbose "Getting all projects ..."
  $projects = Get-AdoProjects
} else {
  Write-Verbose "Using provided project(s): $($projects.name)"
}
Write-Verbose "Found $($projects.Count) project(s): $($projects.name)"
foreach ($project in $projects) {
  Write-Verbose "Getting repos for $($project.name) ..."
  $repos = Get-AdoRepositories -project $project.name
  Write-Verbose "Found $($repos.Count) repos."
  $pipelines = Get-AdoPipelines -project $project.name
  Write-Verbose "Found $($pipelines.Count) pipelines."
  $buildPolicies = Get-AdoBuildPolicies -project $project.name
  Write-Verbose "Found $($buildPolicies.Count) build policies."
  # Check matching pipelines
  $checkedRepos = $repos | Where-Object { $_.name -in $pipelines.name }
  Write-Verbose "Found $($checkedRepos.Count) repos with matching pipelines."

  Read-Host "Press Enter to continue"

  foreach ($repo in $repos) {
    $buildDefinition = $pipelines | Where-Object { $_.name -eq "$($repo.name)" }
    # $response = Read-Host "Do you want to create build validation for repo $($repo.name) using pipeline $($buildDefinition.name)? (y/n)"
    # if ($response -eq 'y') {
      CreateBuildValidationPolicy -repo $repo -project $project -buildDefinition $buildDefinition
    # } else {
    #   Write-Verbose "Skipping $($repo.name)"
    # }
  }
}
