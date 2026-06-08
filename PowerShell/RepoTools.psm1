#Requires -Version 7.0

<#
.SYNOPSIS
  Clone-or-update helpers for GitHub and Azure DevOps repositories.

.DESCRIPTION
  Provides advanced functions that mirror a remote organisation's repositories
  into a local folder: missing repositories are cloned, existing ones are
  switched to their default branch and fast-forwarded. Both providers share a
  single private helper (Update-GitRepository) so the git clone/checkout/pull
  behaviour is identical regardless of source.

  Import it from a script with:

      Import-Module "$PSScriptRoot/RepoTools.psm1" -Force

  Requires the git CLI on PATH. Update-GitHubRepos optionally uses the gh CLI
  to enumerate repositories; Update-AdoRepos calls the Azure DevOps REST API
  with a personal access token.

.NOTES
  Author: Sebastian Gräf
  Repo:   https://github.com/segraef/Scripts
#>

Import-Module "$PSScriptRoot/Write-Log.psm1" -Force

function Update-GitRepository {
    <#
    .SYNOPSIS
      Clone a repository if missing, otherwise checkout its default branch and pull.

    .DESCRIPTION
      Shared worker for the provider-specific functions. If the target folder is
      absent or empty the repository is cloned from RepositoryUrl. If it already
      contains a working tree the default branch is checked out and the latest
      changes are pulled. State-changing git operations honour -WhatIf/-Confirm.

    .PARAMETER RepositoryUrl
      The clone URL of the repository (HTTPS or SSH).

    .PARAMETER RepositoryPath
      The local folder the repository is (or will be) cloned into.

    .PARAMETER DefaultBranch
      The branch to checkout before pulling on an existing clone. Defaults to 'main'.

    .PARAMETER Name
      A friendly repository name used in log messages and ShouldProcess prompts.

    .EXAMPLE
      Update-GitRepository -RepositoryUrl 'https://github.com/Azure/foo.git' -RepositoryPath './Azure/foo' -Name 'foo'
      Clones foo if missing, otherwise checks out main and pulls.

    .NOTES
      Author: Sebastian Gräf
      Repo:   https://github.com/segraef/Scripts
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryUrl,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DefaultBranch = 'main',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Name = (Split-Path -Path $RepositoryPath -Leaf)
    )

    $isPresent = Test-Path -Path $RepositoryPath
    $isEmpty = $isPresent -and -not (Get-ChildItem -Path $RepositoryPath -Force | Select-Object -First 1)

    if (-not $isPresent -or $isEmpty) {
        if ($PSCmdlet.ShouldProcess($RepositoryPath, "Clone repository '$Name'")) {
            Write-Log "Cloning '$Name' into '$RepositoryPath'."
            try {
                New-Item -ItemType Directory -Path $RepositoryPath -Force | Out-Null
                git clone $RepositoryUrl $RepositoryPath
                if ($LASTEXITCODE -ne 0) {
                    throw "git clone exited with code $LASTEXITCODE for '$Name'."
                }
            }
            catch {
                Write-Log -Message "Failed to clone '$Name'." -ErrorRecord $_
                throw
            }
        }
        return
    }

    if ($PSCmdlet.ShouldProcess($RepositoryPath, "Checkout '$DefaultBranch' and pull '$Name'")) {
        Write-Log "Updating '$Name' (checkout '$DefaultBranch', pull)."
        try {
            git -C $RepositoryPath checkout $DefaultBranch
            if ($LASTEXITCODE -ne 0) {
                throw "git checkout '$DefaultBranch' exited with code $LASTEXITCODE for '$Name'."
            }
            git -C $RepositoryPath pull
            if ($LASTEXITCODE -ne 0) {
                throw "git pull exited with code $LASTEXITCODE for '$Name'."
            }
        }
        catch {
            Write-Log -Message "Failed to update '$Name'." -ErrorRecord $_
            throw
        }
    }
}

function Update-GitHubRepos {
    <#
    .SYNOPSIS
      Clone or update a set of GitHub repositories for an organisation.

    .DESCRIPTION
      Mirrors the named GitHub repositories into a local folder under
      <TargetFolder>/<Organization>/<repo>. Missing repositories are cloned over
      HTTPS, existing ones are checked out to the default branch and pulled via
      the shared Update-GitRepository helper.

    .PARAMETER TargetFolder
      The root folder the repositories are cloned or updated under.

    .PARAMETER Organization
      The GitHub organisation (or user) the repositories belong to.

    .PARAMETER Repos
      The repository names to clone or update.

    .PARAMETER DefaultBranch
      The branch to checkout before pulling on existing clones. Defaults to 'main'.

    .EXAMPLE
      Update-GitHubRepos -TargetFolder './Git' -Organization 'Azure' -Repos @('bicep','azure-cli')
      Clones or updates the two named repositories under ./Git/Azure.

    .EXAMPLE
      $repos = gh repo list azure -L 5000 --json name --jq '.[].name' | Select-String -Pattern 'terraform-azurerm-avm'
      Update-GitHubRepos -TargetFolder './Git' -Organization 'Azure' -Repos $repos
      Pipes a filtered repository list from the gh CLI into the updater.

    .NOTES
      Author: Sebastian Gräf
      Repo:   https://github.com/segraef/Scripts
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = 'Plural noun is the established, caller-facing command name.')]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetFolder,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Repos,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DefaultBranch = 'main'
    )

    Write-Log "Found $($Repos.Count) GitHub repositories for '$Organization'."

    foreach ($repo in $Repos) {
        $repoName = "$repo".Trim()
        $repoPath = Join-Path -Path $TargetFolder -ChildPath (Join-Path -Path $Organization -ChildPath $repoName)
        $repoUrl = "https://github.com/$Organization/$repoName.git"

        Update-GitRepository -RepositoryUrl $repoUrl -RepositoryPath $repoPath -DefaultBranch $DefaultBranch -Name $repoName
    }
}

function Update-AdoRepos {
    <#
    .SYNOPSIS
      Clone or update every repository across all projects in an Azure DevOps organisation.

    .DESCRIPTION
      Enumerates the projects in an Azure DevOps organisation via the REST API,
      then clones or updates each project's repositories into
      <TargetFolder>/<project>/<repo>. Missing repositories are cloned, existing
      ones are checked out to the default branch and pulled via the shared
      Update-GitRepository helper.

    .PARAMETER Organization
      The Azure DevOps organisation name (the segment after dev.azure.com/).

    .PARAMETER TargetFolder
      The root folder the repositories are cloned or updated under.

    .PARAMETER Pat
      The personal access token used to authenticate against the REST API.

    .PARAMETER DefaultBranch
      The branch to checkout before pulling on existing clones. Defaults to 'main'.

    .EXAMPLE
      $pat = Read-Host -AsSecureString 'PAT'
      Update-AdoRepos -Organization 'contoso' -TargetFolder 'C:/Repos' -Pat $pat
      Clones or updates every repository in every project of the contoso organisation.

    .NOTES
      Author: Sebastian Gräf
      Repo:   https://github.com/segraef/Scripts
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = 'Plural noun is the established, caller-facing command name.')]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetFolder,

        [Parameter(Mandatory)]
        [securestring]$Pat,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DefaultBranch = 'main'
    )

    $plainPat = [System.Net.NetworkCredential]::new('', $Pat).Password
    $authHeader = @{
        Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$plainPat"))
    }

    Write-Log "Getting projects for organisation '$Organization'."
    try {
        $projectsUri = "https://dev.azure.com/$Organization/_apis/projects?api-version=6.0"
        $projects = (Invoke-RestMethod -Uri $projectsUri -Headers $authHeader).value
    }
    catch {
        Write-Log -Message "Failed to list projects for '$Organization'." -ErrorRecord $_
        throw
    }

    Write-Log "Found $($projects.Count) projects: $($projects.name -join ', ')"

    foreach ($project in $projects) {
        $projectFolder = Join-Path -Path $TargetFolder -ChildPath $project.name

        if (-not (Test-Path -Path $projectFolder)) {
            if ($PSCmdlet.ShouldProcess($projectFolder, 'Create project folder')) {
                Write-Log "Creating folder '$projectFolder'."
                New-Item -ItemType Directory -Path $projectFolder -Force | Out-Null
            }
        }

        Write-Log "Getting repos for project '$($project.name)'."
        try {
            $reposUri = "https://dev.azure.com/$Organization/$($project.name)/_apis/git/repositories?api-version=6.0"
            $reposUri = $reposUri -replace ' ', '%20'
            $repos = (Invoke-RestMethod -Uri $reposUri -Headers $authHeader).value
        }
        catch {
            Write-Log -Message "Failed to list repos for project '$($project.name)'." -ErrorRecord $_
            throw
        }

        Write-Log "Found $($repos.Count) repos: $($repos.name -join ', ')"

        foreach ($repo in $repos) {
            $repoPath = Join-Path -Path $projectFolder -ChildPath $repo.name
            Update-GitRepository -RepositoryUrl $repo.remoteUrl -RepositoryPath $repoPath -DefaultBranch $DefaultBranch -Name $repo.name
        }
    }
}

Export-ModuleMember -Function Update-GitHubRepos, Update-AdoRepos
