# Define the list of Azure DevOps project names
$organization = "yourOrg"
$destinationFolder = "/Users/user/$organization"
$pat = ""
$VerbosePreference = 'Continue'

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
  Write-Verbose $uri
  $response = Invoke-RestMethod -Uri $uri -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat")) }
  return $response.value
}

# Function to clone or update repositories
function CloneOrUpdateRepo($repo, $projectFolder) {
  $repoName = $repo.name
  $repoUrl = $repo.remoteUrl
  $repoFolder = "$projectFolder/$repoName"

  if (-not (Test-Path -Path $repoFolder)) {
    Write-Verbose "Cloning $($repo.name)"
    git clone $repoUrl $repoFolder
  } else {
    Write-Verbose "Pulling/Refreshing $($repo.name)"
    Set-Location -Path $repoFolder
    git checkout main
    git pull
    Set-Location -Path $projectFolder
  }
}

# Main script
Write-Verbose "Getting projects ..."
$projects = Get-AdoProjects
Write-Verbose "Found $($projects.Count) projects: $($projects.name)"
foreach ($project in $projects) {
  $projectFolder = "$destinationFolder/$($project.name)"
  if (-not (Test-Path -Path $projectFolder)) {
    Write-Verbose "Creating folder $projectFolder"
    New-Item -ItemType Directory -Path $projectFolder
  }

  Write-Verbose "Getting repos for $($project.name) ..."
  $repos = Get-AdoRepositories -project $project.name
  Write-Verbose "Found $($repos.Count) repos: $($repos.name)"
  # ask to proceed
  Read-Host "Press Enter to continue"
  foreach ($repo in $repos) {
    $response = Read-Host "Do you want to clone/update the repo $($repo.name)? (y/n)"
    if ($response -eq 'y') {
      CloneOrUpdateRepo -repo $repo -projectFolder $projectFolder
    } else {
      Write-Verbose "Skipping $($repo.name)"
    }
  }
}
