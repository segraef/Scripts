#Requires -Version 7.0

<#
.SYNOPSIS
  Retrieves the content of a single file from a private Azure DevOps Git repository.

.DESCRIPTION
  Calls the Azure DevOps Git Items REST API to download the text content of one
  file from a private repository, authenticating with a Personal Access Token (PAT)
  over HTTP Basic auth. The file content is written to the output stream so it can
  be captured, piped, or redirected to disk.

  Prerequisites:
    - An Azure DevOps organisation reachable at https://<account>.visualstudio.com.
    - A PAT with at least Code (Read) scope on the target project/repository.

.PARAMETER DevOpsAccountName
  The Azure DevOps organisation (account) name. Used to build the base URL
  https://<DevOpsAccountName>.visualstudio.com.

.PARAMETER DevOpsTeamProjectName
  The team project that contains the target repository.

.PARAMETER FileRepo
  The name (or id) of the Git repository to read the file from.

.PARAMETER DevOpsPAT
  The Azure DevOps Personal Access Token used to authenticate, supplied as a
  SecureString. Requires Code (Read) scope.

.PARAMETER User
  The user name portion of the Basic auth pair. Azure DevOps PAT auth ignores the
  user name, so this is normally left empty.

.PARAMETER FileRepoBranch
  The branch to read the file from. Defaults to 'master'.

.PARAMETER FilePath
  The repository-relative path of the file to retrieve.

.PARAMETER ApiVersion
  The Azure DevOps REST API version to target. Defaults to '4.1'.

.INPUTS
  None. This script does not accept pipeline input.

.OUTPUTS
  System.String. The text content of the requested file is written to the output
  stream.

.EXAMPLE
  $pat = Read-Host -AsSecureString
  ./Get-DevOpsPrivateRepoFile.ps1 -DevOpsAccountName 'contoso' -DevOpsTeamProjectName 'Platform' -FileRepo 'Platform' -DevOpsPAT $pat -FilePath 'Scripts/PowerShell/Deploy.ps1'
  Downloads Deploy.ps1 from the master branch of the Platform repository and writes
  its content to the output stream.

.EXAMPLE
  ./Get-DevOpsPrivateRepoFile.ps1 -DevOpsAccountName 'contoso' -DevOpsTeamProjectName 'Platform' -FileRepo 'Platform' -DevOpsPAT $pat -FilePath 'README.md' -FileRepoBranch 'main' > README.md
  Downloads README.md from the main branch and saves it to a local file.

.NOTES
  Author: Sebastian Gräf
  Repo:   https://github.com/segraef/Scripts
#>

#region Parameters
[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DevOpsAccountName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DevOpsTeamProjectName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$FileRepo,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [securestring]$DevOpsPAT,

    [Parameter()]
    [string]$User = '',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$FileRepoBranch = 'master',

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$FilePath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ApiVersion = '4.1'
)
#endregion

#region Initialisation
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Write-Log.psm1" -Force
#endregion

#region Functions
function Get-DevOpsRepoFileContent {
    <#
    .SYNOPSIS
      Downloads the content of one file from a private Azure DevOps Git repository.

    .DESCRIPTION
      Builds the Azure DevOps Git Items REST API URI for the requested file and
      retrieves its content using PAT-based Basic authentication.

    .PARAMETER DevOpsAccountName
      The Azure DevOps organisation (account) name.

    .PARAMETER DevOpsTeamProjectName
      The team project that contains the target repository.

    .PARAMETER FileRepo
      The Git repository to read the file from.

    .PARAMETER DevOpsPAT
      The Azure DevOps Personal Access Token, supplied as a SecureString.

    .PARAMETER User
      The user name portion of the Basic auth pair (normally empty for PAT auth).

    .PARAMETER FileRepoBranch
      The branch to read the file from.

    .PARAMETER FilePath
      The repository-relative path of the file to retrieve.

    .PARAMETER ApiVersion
      The Azure DevOps REST API version to target.

    .OUTPUTS
      System.String. The text content of the requested file.

    .EXAMPLE
      Get-DevOpsRepoFileContent -DevOpsAccountName 'contoso' -DevOpsTeamProjectName 'Platform' -FileRepo 'Platform' -DevOpsPAT $pat -FilePath 'README.md'
      Returns the content of README.md from the master branch.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DevOpsAccountName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DevOpsTeamProjectName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FileRepo,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [securestring]$DevOpsPAT,

        [Parameter()]
        [string]$User = '',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$FileRepoBranch = 'master',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ApiVersion = '4.1'
    )

    $devOpsBaseUrl = "https://$DevOpsAccountName.visualstudio.com"
    $plainPat = [System.Net.NetworkCredential]::new('', $DevOpsPAT).Password

    try {
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f $User, $plainPat)))
        $devOpsAuthHeader = @{ Authorization = ('Basic {0}' -f $base64AuthInfo) }

        $itemsPath = "/$DevOpsTeamProjectName/_apis/git/repositories/$FileRepo/items"
        $queryParts = @(
            "path=$FilePath"
            '$format=json'
            'includeContent=true'
            "versionDescriptor.version=$FileRepoBranch"
            'versionDescriptor.versionType=branch'
            "api-version=$ApiVersion"
        )
        $uri = $devOpsBaseUrl + $itemsPath + '?' + ($queryParts -join '&')

        Write-Log "Requesting '$FilePath' from repository '$FileRepo' (branch '$FileRepoBranch')."

        $file = Invoke-RestMethod -Method Get -ContentType 'application/json' -Uri $uri -Headers $devOpsAuthHeader

        return $file.content
    }
    catch {
        Write-Log -Message "Failed to retrieve '$FilePath' from repository '$FileRepo'." -ErrorRecord $_
        throw
    }
    finally {
        $plainPat = $null
    }
}
#endregion

#region Execution
Write-Log "Executing $($MyInvocation.MyCommand.Name)."

$content = Get-DevOpsRepoFileContent `
    -DevOpsAccountName $DevOpsAccountName `
    -DevOpsTeamProjectName $DevOpsTeamProjectName `
    -FileRepo $FileRepo `
    -DevOpsPAT $DevOpsPAT `
    -User $User `
    -FileRepoBranch $FileRepoBranch `
    -FilePath $FilePath `
    -ApiVersion $ApiVersion

Write-Output $content

Write-Log "Finished $($MyInvocation.MyCommand.Name)."
#endregion
