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
      if ($PSCmdlet.ShouldProcess("Cloning repository $repo into $repoPath")) {
        New-Item -ItemType Directory -Path $repoPath -Force
        Set-Location -Path $repoPath
        Write-Output "Cloning repository $repo into $repoPath."
        git clone "https://github.com/$organization/$repo.git"
      }
    } else {
      Write-Output "Directory $repoPath already exists. Updating only."
      if ((Get-ChildItem -Path $repoPath).Count -eq 0) {
        if ($PSCmdlet.ShouldProcess("Cloning repository $repo into $repoPath")) {
          Write-Output "Cloning repository $repo into $repoPath."
          git clone "https://github.com/$organization/$repo.git"
        }
      } else {
        if ($PSCmdlet.ShouldProcess("Pulling latest changes for $repo")) {
          Write-Output "Pulling latest changes for $repo."
          Set-Location -Path $repoPath
          git checkout main
          git pull
        }
      }
    }
  }
}
