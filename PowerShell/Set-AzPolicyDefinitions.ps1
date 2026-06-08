#Requires -Version 7.0

<#
.SYNOPSIS
  Create Azure Policy definitions from a folder of policy JSON files.

.DESCRIPTION
  Reads every JSON file in the supplied folder and registers each one as an
  Azure Policy definition under the specified management group. The file base
  name becomes both the policy name and display name; the JSON body supplies
  the policy rule, parameters and resource mode.

  Prerequisites: the Az PowerShell module must be installed and an authenticated
  Azure session (Connect-AzAccount) must be active with rights to create policy
  definitions at the chosen management group scope.

.PARAMETER PolicyFolder
  Path to the folder containing the policy definition JSON files. Each file is
  processed in turn.

.PARAMETER ManagementGroupName
  Name (ID) of the management group at which the policy definitions are created.

.PARAMETER PolicyDescription
  Description applied to every policy definition created in this run.

.INPUTS
  None. This script does not accept pipeline input.

.OUTPUTS
  Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyDefinition
  One object per policy definition created.

.EXAMPLE
  ./Set-AzPolicyDefinitions.ps1 -PolicyFolder './policies' -ManagementGroupName 'mg-corp'
  Creates a policy definition for every JSON file in ./policies under the
  'mg-corp' management group, using the default description.

.EXAMPLE
  ./Set-AzPolicyDefinitions.ps1 -PolicyFolder './policies' -ManagementGroupName 'mg-corp' -PolicyDescription 'Apply Diagnostics Settings'
  Creates the policy definitions with a custom description.

.NOTES
  Author: Sebastian Gräf
  Repo:   https://github.com/segraef/Scripts
  Version history is tracked in git, not in this header.
#>

#region Parameters
[CmdletBinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PolicyFolder,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ManagementGroupName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PolicyDescription = 'Apply Diagnostics Settings'
)
#endregion

#region Initialisation
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Write-Log.psm1" -Force
#endregion

#region Functions
function New-PolicyDefinition {
    <#
    .SYNOPSIS
      Create a single Azure Policy definition from a policy JSON file.

    .DESCRIPTION
      Parses the supplied JSON file, extracts the policy rule, parameters and
      mode, then creates an Azure Policy definition named after the file base
      name at the given management group scope.

    .PARAMETER Path
      Full path to the policy definition JSON file.

    .PARAMETER ManagementGroupName
      Name (ID) of the management group at which the definition is created.

    .PARAMETER Description
      Description applied to the policy definition.

    .EXAMPLE
      New-PolicyDefinition -Path './policies/audit-vm.json' -ManagementGroupName 'mg-corp' -Description 'Apply Diagnostics Settings'
      Creates the 'audit-vm' policy definition under the 'mg-corp' management group.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManagementGroupName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description
    )

    $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    Write-Log "Processing policy definition '$name' from '$Path'."

    try {
        $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
        $policyRule = $json.policyRule | ConvertTo-Json -Depth 8 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
        $parameters = $json.parameters | ConvertTo-Json -Depth 8 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
    }
    catch {
        Write-Log -Message "Failed to parse policy file '$Path'." -ErrorRecord $_
        throw
    }

    if ($PSCmdlet.ShouldProcess($name, 'Create Azure policy definition')) {
        try {
            New-AzPolicyDefinition -Name $name -DisplayName $name -Policy $policyRule -Description $Description -Parameter $parameters -Mode $json.mode -ManagementGroupName $ManagementGroupName
        }
        catch {
            Write-Log -Message "Failed to create policy definition '$name'." -ErrorRecord $_
            throw
        }
    }
}
#endregion

#region Execution
Write-Log "Executing $($MyInvocation.MyCommand.Name)."

foreach ($item in (Get-ChildItem -Path $PolicyFolder -File)) {
    New-PolicyDefinition -Path $item.FullName -ManagementGroupName $ManagementGroupName -Description $PolicyDescription
}

Write-Log "Finished executing $($MyInvocation.MyCommand.Name)."
#endregion
