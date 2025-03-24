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
  function Get-AdoProjects($organization,$pat) {
    $uri = "https://dev.azure.com/$organization/_apis/projects?api-version=6.0"
    $response = Invoke-RestMethod -Uri $uri -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat")) }
    return $response.value
  }

  # Function to get repositories for a given project
  function Get-AdoRepositories($organization,$pat,$project) {
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
      if ($PSCmdlet.ShouldProcess("Cloning $($repo.name)")) {
        Write-Output "Cloning $($repo.name)"
        git clone $repoUrl $repoFolder
      }
    } else {
      if ($PSCmdlet.ShouldProcess("Pulling/Refreshing $($repo.name)")) {
        Write-Output "Pulling/Refreshing $($repo.name)"
        Set-Location -Path $repoFolder
        git checkout main
        git pull
        Set-Location -Path $projectFolder
      }
    }
  }

  # Main script
  Write-Output "Getting projects ..."
  $projects = Get-AdoProjects -organization $organization -pat $pat
  Write-Output "Found $($projects.Count) projects: $($projects.name)"
  foreach ($project in $projects) {
    $projectFolder = "$destinationFolder/$($project.name)"
    if (-not (Test-Path -Path $projectFolder)) {
      if ($PSCmdlet.ShouldProcess("Creating folder $projectFolder")) {
        Write-Output "Creating folder $projectFolder"
        New-Item -ItemType Directory -Path $projectFolder
      }
    }

    Write-Output "Getting repos for $($project.name) ..."
    $repos = Get-AdoRepositories -organization $organization -pat $pat -project $project.name
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
