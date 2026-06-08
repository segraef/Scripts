#Requires -Version 7.0

<#
.SYNOPSIS
  Exports build and release definitions from a source Azure DevOps project and optionally imports them into a destination project.

.DESCRIPTION
  Connects to a source Azure DevOps organisation/project with VSTeam and exports every
  build and release definition to JSON, written into two folders named
  "<account>.<project>.BuildDefinitions" and "<account>.<project>.ReleaseDefinitions".

  When a destination account and project are also supplied, the exported JSON files are
  imported into the destination project. If no destination is given, the script only
  exports and saves the definitions as JSON.

  Required Modules (installed if not present): VSTeam.

.PARAMETER sourceAccount
  Azure DevOps source account/organisation.

.PARAMETER sourceProject
  Azure DevOps source project.

.PARAMETER sourcePersonalAccessToken
  Azure DevOps source Personal Access Token (plain string, used with -PersonalAccessToken).

.PARAMETER sourceSecureAccessToken
  Azure DevOps source Secure Access Token (used with -SecurePersonalAccessToken when no plain PAT is supplied).

.PARAMETER destinationAccount
  Azure DevOps destination account/organisation.

.PARAMETER destinationProject
  Azure DevOps destination project.

.PARAMETER destinationPersonalAccessToken
  Azure DevOps destination Personal Access Token (plain string, used with -PersonalAccessToken).

.PARAMETER destinationSecureAccessToken
  Azure DevOps destination Secure Access Token (used with -SecurePersonalAccessToken when no plain PAT is supplied).

.INPUTS
  None.

.OUTPUTS
  JSON files for each build and release definition, written to two folders in the current directory.

.EXAMPLE
  ./Export-AzDOBuildReleaseDefinitions.ps1 -sourceAccount 'contoso' -sourceProject 'Web' -sourcePersonalAccessToken 'pat'
  Exports all build and release definitions from the Web project to JSON.

.EXAMPLE
  ./Export-AzDOBuildReleaseDefinitions.ps1 -sourceAccount 'contoso' -sourceProject 'Web' -sourcePersonalAccessToken 'pat' -destinationAccount 'fabrikam' -destinationProject 'Web' -destinationPersonalAccessToken 'pat2'
  Exports definitions from the source project and imports them into the destination project.

.NOTES
  Author: Sebastian Gräf
  Repo:   https://github.com/segraef/Scripts
  Version history is tracked in git, not in this header.
#>

[CmdletBinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$sourceAccount,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$sourceProject,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$sourcePersonalAccessToken,

    [Parameter()]
    [securestring]$sourceSecureAccessToken,

    [Parameter()]
    [string]$destinationAccount,

    [Parameter()]
    [string]$destinationProject,

    [Parameter()]
    [string]$destinationPersonalAccessToken,

    [Parameter()]
    [securestring]$destinationSecureAccessToken
)

#region Initialisation
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Write-Log.psm1" -Force
#endregion

#region Functions
function Initialize-RequiredModule {
    <#
    .SYNOPSIS
      Ensure a PowerShell module is available, installing it from the gallery if required.

    .DESCRIPTION
      Imports the named module if it is already available, otherwise installs it for the
      current user from the PowerShell Gallery and then imports it.

    .PARAMETER Name
      The module name to ensure is loaded.

    .EXAMPLE
      Initialize-RequiredModule -Name 'VSTeam'
      Imports VSTeam, installing it first if it is not present.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if (Get-Module -Name $Name) {
        Write-Log "Module '$Name' is already imported."
        return
    }

    try {
        if (-not (Get-Module -ListAvailable -Name $Name)) {
            if ($PSCmdlet.ShouldProcess($Name, 'Install module')) {
                Write-Log "Installing module '$Name' from the gallery."
                Install-Module -Name $Name -Force -Scope CurrentUser
            }
        }

        Import-Module -Name $Name
        Write-Log "Module '$Name' imported."
    }
    catch {
        Write-Log -Message "Failed to ensure module '$Name'." -ErrorRecord $_
        throw
    }
}
#endregion

#region Execution
Write-Log "Executing $($MyInvocation.MyCommand.Name)."

Initialize-RequiredModule -Name 'VSTeam'

$buildDefinitionDirectory = $null
$releaseDefinitionDirectory = $null

if ($sourceAccount -and $sourceProject) {
    # Set the source project.
    if ($sourcePersonalAccessToken) {
        Set-VSTeamAccount -Account $sourceAccount -PersonalAccessToken $sourcePersonalAccessToken
    }
    elseif ($sourceSecureAccessToken) {
        Set-VSTeamAccount -Account $sourceAccount -SecurePersonalAccessToken $sourceSecureAccessToken
    }
    else {
        Write-Log 'Exiting script since no source token given.' -Level Warning
        return
    }

    try {
        # Get all release definitions.
        $releaseDefinitions = Get-VSTeamReleaseDefinition -ProjectName $sourceProject

        # Get all build definitions.
        $buildDefinitions = Get-VSTeamBuildDefinition -ProjectName $sourceProject
    }
    catch {
        Write-Log -Message "Failed to read definitions from project '$sourceProject'." -ErrorRecord $_
        throw
    }

    # Create definition folders.
    if ($PSCmdlet.ShouldProcess("$sourceAccount.$sourceProject", 'Create export folders')) {
        try {
            $buildDefinitionDirectory = New-Item "$sourceAccount.$sourceProject.BuildDefinitions" -ItemType Directory -Force
            $releaseDefinitionDirectory = New-Item "$sourceAccount.$sourceProject.ReleaseDefinitions" -ItemType Directory -Force
        }
        catch {
            Write-Log -Message 'Failed to create export folders.' -ErrorRecord $_
            throw
        }
    }

    # Export build definitions.
    foreach ($buildDefinition in $buildDefinitions) {
        $fileName = Join-Path $buildDefinitionDirectory.FullName "$($buildDefinition.Name).json"
        if ($PSCmdlet.ShouldProcess($fileName, 'Export build definition')) {
            try {
                Get-VSTeamBuildDefinition -ProjectName $sourceProject -Id $buildDefinition.ID -json | Out-File $fileName
            }
            catch {
                Write-Log -Message "Failed to export build definition '$($buildDefinition.Name)'." -ErrorRecord $_
                throw
            }
        }
    }
    Write-Log "Your build definitions can be found here: $buildDefinitionDirectory"

    # Export release definitions.
    foreach ($releaseDefinition in $releaseDefinitions) {
        $fileName = Join-Path $releaseDefinitionDirectory.FullName "$($releaseDefinition.Name).json"
        if ($PSCmdlet.ShouldProcess($fileName, 'Export release definition')) {
            try {
                Get-VSTeamReleaseDefinition -ProjectName $sourceProject -Id $releaseDefinition.ID -json | Out-File $fileName
            }
            catch {
                Write-Log -Message "Failed to export release definition '$($releaseDefinition.Name)'." -ErrorRecord $_
                throw
            }
        }
    }
    Write-Log "Your release definitions can be found here: $releaseDefinitionDirectory"
}

if ($destinationAccount -and $destinationProject) {
    # Set the destination project.
    if ($destinationPersonalAccessToken) {
        Set-VSTeamAccount -Account $destinationAccount -PersonalAccessToken $destinationPersonalAccessToken
    }
    elseif ($destinationSecureAccessToken) {
        Set-VSTeamAccount -Account $destinationAccount -SecurePersonalAccessToken $destinationSecureAccessToken
    }
    else {
        Write-Log 'Exiting script since no destination token given.' -Level Warning
        return
    }

    if (-not $releaseDefinitionDirectory -or -not $buildDefinitionDirectory) {
        Write-Log 'No exported definitions available to import; run the export step first.' -Level Warning
        return
    }

    try {
        # Import release definitions.
        $releaseDefinitions = Get-ChildItem $releaseDefinitionDirectory.FullName
        foreach ($releaseDefinition in $releaseDefinitions) {
            $fileName = $releaseDefinition.FullName
            if ($PSCmdlet.ShouldProcess($fileName, 'Import release definition')) {
                Add-VSTeamReleaseDefinition -ProjectName $destinationProject -inFile $fileName
            }
        }

        # Import build definitions.
        $buildDefinitions = Get-ChildItem $buildDefinitionDirectory.FullName
        foreach ($buildDefinition in $buildDefinitions) {
            $fileName = $buildDefinition.FullName
            if ($PSCmdlet.ShouldProcess($fileName, 'Import build definition')) {
                Add-VSTeamBuildDefinition -ProjectName $destinationProject -inFile $fileName
            }
        }
    }
    catch {
        Write-Log -Message "Failed to import definitions into project '$destinationProject'." -ErrorRecord $_
        throw
    }
}

Write-Log "Finished $($MyInvocation.MyCommand.Name)."
#endregion
