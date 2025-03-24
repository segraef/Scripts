<#
  .SYNOPSIS
    Clones or updates GitHub repositories for a specified organization.

  .DESCRIPTION
    This script clones or updates GitHub repositories for a specified organization into a specified destination folder.

  .PARAMETER destinationFolder
    The folder where the repositories will be cloned or updated.

  .PARAMETER organization
    The GitHub organization name.

  .PARAMETER repos
    The list of repositories to clone or update.

  .INPUTS
    None

  .OUTPUTS
    None

  .NOTES
    Version:        1.0
    Author:         Sebastian Graef
    Creation Date:  22-03-2025
    Purpose/Change: Initial script development

  .EXAMPLE
    Get-GitHubRepos -destinationFolder "Git/Folder1" -organization "Azure" -repos @("repo1", "repo2")

  .EXAMPLE
    $tfrepos = gh repo list azure -L 5000 --json name --jq '.[].name' | Select-String -Pattern "terraform-azurerm-avm"
    Get-GitHubRepos -repos $tfrepos
  #>

function Update-GitHubRepos {

  [CmdletBinding(SupportsShouldProcess)]
  param
  (
    [Parameter()]
    [string]$destinationFolder,
    [Parameter()]
    [string]$organization,
    [Parameter()]
    [string[]]$repos
  )

  Write-Output "Found $($repos.Count) repositories."
  $confirmation = Read-Host "Do you want to proceed with processing these repositories? (y/n)"
  if ($confirmation -ne 'y') {
    return
  }

  foreach ($repo in $repos) {
    $repoPath = Join-Path -Path $destinationFolder -ChildPath "$organization/$repo"
    If (!(Test-Path -Path $repoPath)) {
      New-Item -ItemType Directory -Path $repoPath -Force
      Set-Location -Path $repoPath
      Write-Output "Cloning repository $repo into $repoPath."
      git clone "https://github.com/$organization/$repo.git"
    } else {
      Write-Output "Directory $repoPath already exists. Updating only."
      if ((Get-ChildItem -Path $repoPath).Count -eq 0) {
        Write-Output "Cloning repository $repo into $repoPath."
        git clone "https://github.com/$organization/$repo.git"
      } else {
        Write-Output "Pulling latest changes for $repo."
        Set-Location -Path $repoPath
        git checkout main
        git pull
      }
    }
  }
}


<#
.SYNOPSIS
  Script to clone or update Azure DevOps repositories for all projects in an organization.

.DESCRIPTION
  This script clones or updates Azure DevOps repositories for all projects in a specified organization into a specified destination folder.

.PARAMETER organization
  The Azure DevOps organization name.

.PARAMETER destinationFolder
  The folder where the repositories will be cloned or updated.

.PARAMETER pat
  The personal access token for authentication.

.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         Sebastian Graef
  Creation Date:  22-03-2025
  Purpose/Change: Initial script development

.EXAMPLE
  CloneUpdate-AdoRepos.ps1 -organization "yourOrg" -destinationFolder "C:\Repos" -pat "yourPAT"
#>

function Update-AdoRepos {

  [CmdletBinding(SupportsShouldProcess)]
  param
  (
    [Parameter()]
    [string]$organization,
    [Parameter()]
    [string]$destinationFolder,
    [Parameter()]
    [string]$pat
  )

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
    Write-Output $uri
    $response = Invoke-RestMethod -Uri $uri -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat")) }
    return $response.value
  }

  # Function to clone or update repositories
  function CloneOrUpdateRepo($repo, $projectFolder) {
    $repoName = $repo.name
    $repoUrl = $repo.remoteUrl
    $repoFolder = "$projectFolder/$repoName"

    if (-not (Test-Path -Path $repoFolder)) {
      Write-Output "Cloning $($repo.name)"
      git clone $repoUrl $repoFolder
    } else {
      Write-Output "Pulling/Refreshing $($repo.name)"
      Set-Location -Path $repoFolder
      git checkout main
      git pull
      Set-Location -Path $projectFolder
    }
  }

  # Main script
  Write-Output "Getting projects ..."
  $projects = Get-AdoProjects
  Write-Output "Found $($projects.Count) projects: $($projects.name)"
  foreach ($project in $projects) {
    $projectFolder = "$destinationFolder/$($project.name)"
    if (-not (Test-Path -Path $projectFolder)) {
      Write-Output "Creating folder $projectFolder"
      New-Item -ItemType Directory -Path $projectFolder
    }

    Write-Output "Getting repos for $($project.name) ..."
    $repos = Get-AdoRepositories -project $project.name
    Write-Output "Found $($repos.Count) repos: $($repos.name)"
    Read-Host "Press Enter to continue"
    foreach ($repo in $repos) {
      $response = Read-Host "Do you want to clone/update the repo $($repo.name)? (y/n)"
      if ($response -eq 'y') {
        CloneOrUpdateRepo -repo $repo -projectFolder $projectFolder
      } else {
        Write-Output "Skipping $($repo.name)"
      }
    }
  }
}

<#
.SYNOPSIS
  Script to clone or update repositories for a specified organization.

.DESCRIPTION
  This script clones or updates repositories for a specified organization into a specified destination folder. It supports both GitHub and Azure DevOps repositories.

.PARAMETER destinationFolder
  The folder where the repositories will be cloned or updated.

.PARAMETER organization
  The organization name (GitHub or Azure DevOps).

.PARAMETER repos
  The list of GitHub repositories to clone or update.

.PARAMETER pat
  The personal access token for Azure DevOps authentication.

.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         Sebastian Graef
  Creation Date:  22-03-2025
  Purpose/Change: Initial script development

.EXAMPLE
  Update-Repos -destinationFolder "C:\Repos" -organization "yourOrg" -repos @("repo1", "repo2")

.EXAMPLE
  Update-Repos -destinationFolder "C:\Repos" -organization "yourOrg" -pat "yourPAT"
#>

function Update-Repos {

  [CmdletBinding()]
  param
  (
    [Parameter()]
    [string]$destinationFolder,
    [Parameter()]
    [string]$organization,
    [Parameter()]
    [string[]]$repos,
    [Parameter()]
    [string]$pat
  )

  if ($pat) {
    Write-Output "- Updating Azure DevOps repositories"
    Update-AdoRepos -organization $organization -destinationFolder $destinationFolder -pat $pat
  } else {
    Write-Output "- Updating GitHub repositories"
    Update-GitHubRepos -destinationFolder $destinationFolder -organization $organization -repos $repos
  }
}
