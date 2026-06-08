#Requires -Version 7.0

<#
.SYNOPSIS
  Clone or update GitHub and/or Azure DevOps repositories into a local folder.

.DESCRIPTION
  Thin dispatcher over RepoTools.psm1. Resolves the destination folder to an
  absolute path and routes to Update-GitHubRepos, Update-AdoRepos, or both,
  depending on -Provider. Missing repositories are cloned; existing ones are
  checked out to the default branch and pulled.

  Requires the git CLI on PATH. The GitHub path needs an organisation and a
  repository list; the Azure DevOps path needs an organisation and a personal
  access token.

.PARAMETER Provider
  Which source to process: GitHub, AzureDevOps, or All (default).

.PARAMETER DestinationFolder
  The root folder repositories are cloned or updated under. Must already exist.

.PARAMETER Organization
  The GitHub or Azure DevOps organisation name.

.PARAMETER Repos
  The GitHub repository names to clone or update (required for GitHub/All).

.PARAMETER Pat
  The Azure DevOps personal access token (required for AzureDevOps/All).

.PARAMETER DefaultBranch
  The branch to checkout before pulling on existing clones. Defaults to 'main'.

.INPUTS
  None.

.OUTPUTS
  None.

.EXAMPLE
  ./Update-Repos.ps1 -Provider GitHub -DestinationFolder 'C:/Repos' -Organization 'Azure' -Repos @('bicep','azure-cli')
  Clones or updates the two named GitHub repositories under C:/Repos/Azure.

.EXAMPLE
  $pat = Read-Host -AsSecureString 'PAT'
  ./Update-Repos.ps1 -Provider AzureDevOps -DestinationFolder 'C:/Repos' -Organization 'contoso' -Pat $pat
  Clones or updates every repository in every project of the contoso organisation.

.NOTES
  Author: Sebastian Gräf
  Repo:   https://github.com/segraef/Scripts
  Version history is tracked in git, not in this header.
#>

[CmdletBinding(SupportsShouldProcess)]
param
(
    [Parameter()]
    [ValidateSet('GitHub', 'AzureDevOps', 'All')]
    [string]$Provider = 'All',

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationFolder,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Organization,

    [Parameter()]
    [string[]]$Repos,

    [Parameter()]
    [securestring]$Pat,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DefaultBranch = 'main'
)

#region Initialisation
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Write-Log.psm1" -Force
Import-Module "$PSScriptRoot/RepoTools.psm1" -Force
#endregion

#region Execution
Write-Log "Executing $($MyInvocation.MyCommand.Name) (provider '$Provider')."

if (-not (Test-Path -Path $DestinationFolder)) {
    throw "The DestinationFolder '$DestinationFolder' does not exist."
}
$DestinationFolder = (Resolve-Path -Path $DestinationFolder).Path

if ($Provider -in 'GitHub', 'All') {
    if (-not $Repos) {
        throw "The Repos parameter is required for the '$Provider' provider."
    }
    Write-Log 'Updating GitHub repositories.'
    Update-GitHubRepos -TargetFolder $DestinationFolder -Organization $Organization -Repos $Repos -DefaultBranch $DefaultBranch
}

if ($Provider -in 'AzureDevOps', 'All') {
    if (-not $Pat) {
        throw "The Pat parameter is required for the '$Provider' provider."
    }
    Write-Log 'Updating Azure DevOps repositories.'
    Update-AdoRepos -Organization $Organization -TargetFolder $DestinationFolder -Pat $Pat -DefaultBranch $DefaultBranch
}

Write-Log "Finished $($MyInvocation.MyCommand.Name)."
#endregion
