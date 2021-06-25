<#
    .SYNOPSIS
      Exports build and release definitions from a source Azure DevOps project and imports these into a destination project.
      If no destination project give it will only export build and release defintions and save it as JSON.

    .DESCRIPTION
      The script will create two folders with all exported build and release definitions as JSON.
      Once a destination organization and project are given, the script will import the exported
      build and release defintions into the target project.

      Required Modules (will be installed if not present): VSTeam

    .PARAMETER sourceAccount
        Azure DevOps source account/organization.

    .PARAMETER sourceProject
        Azure DevOps source project.

    .PARAMETER sourcePersonalAccessToken
        Azure DevOps source Personal Access Token.

    .PARAMETER sourcePersonalAccessToken
        Azure DevOps source Secure Access Token.

    .PARAMETER destinationAccount
        Azure DevOps destination account/organization.

    .PARAMETER destinationProject
        Azure DevOps destination account/organization.

    .PARAMETER destinationPersonalAccessToken
        Azure DevOps destination Personal Access Token.

    .PARAMETER destinationSecureAccessToken
        Azure DevOps destination Secure Access Token.

    .NOTES
      Version:        1.0
      Author:         Sebastian Gräf
      Email:          sebastian@graef.io
      Creation Date:  08/13/2019
      Purpose/Change: Initial script development
#>

#region Parameters

param (
    [Parameter(Mandatory = $true)]
    [string]$sourceAccount,
    [Parameter(Mandatory = $true)]
    [string]$sourceProject,
    [Parameter(Mandatory = $true)]
    [string]$sourcePersonalAccessToken,
    [Parameter(Mandatory = $false)]
    [securestring]$sourceSecureAccessToken,
    [Parameter(Mandatory = $False)]
    [string]$destinationAccount,
    [Parameter(Mandatory = $False)]
    [string]$destinationProject,
    [Parameter(Mandatory = $False)]
    [string]$destinationPersonalAccessToken,
    [Parameter(Mandatory = $False)]
    [securestring]$destinationSecureAccessToken
)

#endregion

#region Initialisations

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

Import-Module ..\Load-Module.ps1

#endregion

#region Declarations
#endregion

#region Functions
#endregion

#region Execution

Load-Module VSTeam

if ($sourceAccount -and $sourceProject) {
    # Set the source project
    if ($sourcePersonalAccessToken) {
        Set-VSTeamAccount -Account $sourceAccount -PersonalAccessToken $sourcePersonalAccessToken
    }
    elseif ($sourcePersonalAccessToken) {
        Set-VSTeamAccount -Account $sourceAccount -SecurePersonalAccessToken $sourceSecureAccessToken
    }
    else {
        Write-Output "Exiting script since no token given"
    }

    # Get all release definitions
    $releaseDefinitions = Get-VSTeamReleaseDefinition -ProjectName $sourceProject

    # Get all build definitions
    $buildDefinitions = Get-VSTeamBuildDefinition -ProjectName $sourceProject

    # Create definition folders
    $buildDefinitionDirectory = New-Item "$sourceAccount.$sourceProject.BuildDefinitions" -ItemType Directory -Force
    $releaseDefinitionDirectory = New-Item "$sourceAccount.$sourceProject.ReleaseDefinitions" -ItemType Directory -Force

    # Export build defintions
    foreach ($buildDefinition in $buildDefinitions) {
        $fileName = $buildDefinitionDirectory.FullName + "\" + $buildDefinition.Name + ".json"
        Get-VSTeamBuildDefinition -ProjectName $sourceProject -Id $buildDefinition.ID -json | Out-File $fileName
    }
    Write-Output "Your build definitions can be found here: $buildDefinitionDirectory"

    # Export release defintions
    foreach ($releaseDefinition in $releaseDefinitions) {
        $fileName = $releaseDefinitionDirectory.FullName + "\" + $releaseDefinition.Name + ".json"
        Get-VSTeamReleaseDefinition -ProjectName $sourceProject -Id $releaseDefinition.ID -json | Out-File $fileName
    }
    Write-Output "Your release definitions can be found here: $releaseDefinitionDirectory"
}

if ($destinationAccount -and $destinationProject) {
    # Set the destination project
    if ($destinationPersonalAccessToken) {
        Set-VSTeamAccount -Account $destinationAccount -PersonalAccessToken $destinationPersonalAccessToken
    }
    elseif ($destinationSecureAccessToken) {
        Set-VSTeamAccount -Account $sourceAccount -SecurePersonalAccessToken $destinationSecureAccessToken
    }
    else {
        Write-Output "Exiting script since no token given"
    }

    # Import release defintions
    $releaseDefinitions = Get-ChildItem $releaseDefinitionDirectory.FullName
    foreach ($releaseDefinition in $releaseDefinitions) {
        $fileName = $releaseDefinition.FullName
        Add-VSTeamReleaseDefinition -ProjectName $destinationProject -inFile $fileName
    }

    # Import build defintions
    $buildDefinitions = Get-ChildItem $buildDefinitionDirectory.FullName
    foreach ($buildDefinition in $buildDefinitions) {
        $fileName = $buildDefinition.FullName
        Add-VSTeamReleaseDefinition -ProjectName $destinationProject -inFile $fileName
    }
}
