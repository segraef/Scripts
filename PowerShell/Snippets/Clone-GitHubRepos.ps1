function Clone-GitHubRepos {

<#
.SYNOPSIS
  Clones or updates GitHub repositories for a specified organization.

.DESCRIPTION
  This script clones or updates GitHub repositories for a specified organization into a specified destination folder.

.PARAMETER destinationFolder
  The folder where the repositories will be cloned or updated.

.PARAMETER org
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
  Clone-GitHubRepos -destinationFolder "Git/Folder1" -org "Azure" -repos @("repo1", "repo2")

.EXAMPLE
  $tfrepos = gh repo list azure -L 5000 --json name --jq '.[].name' | Select-String -Pattern "terraform-azurerm-avm"
  Clone-GitHubRepos -repos $tfrepos
#>

    #region Parameters

    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]$destinationFolder,
        [Parameter()]
        [string]$org,
        [Parameter()]
        [string[]]$repos
    )

    #endregion

    Write-Output "Found $($repos.Count) repositories."
    $confirmation = Read-Host "Do you want to proceed with processing these repositories? (y/n)"
    if ($confirmation -ne 'y') {
        return
    }

    foreach ($repo in $repos) {
        $repoPath = Join-Path -Path $destinationFolder -ChildPath "$org/$repo"
        If (!(Test-Path -Path $repoPath)) {
            New-Item -ItemType Directory -Path $repoPath -Force
            Set-Location -Path $repoPath
            Write-Output "Cloning repository $repo into $repoPath."
            git clone "https://github.com/$org/$repo.git"
        } else {
            Write-Output "Directory $repoPath already exists. Updating only."
            if ((Get-ChildItem -Path $repoPath).Count -eq 0) {
                Write-Output "Cloning repository $repo into $repoPath."
                git clone "https://github.com/$org/$repo.git"
            } else {
                Write-Output "Pulling latest changes for $repo."
                Set-Location -Path $repoPath
                git checkout main
                git pull
            }
        }
    }
}
