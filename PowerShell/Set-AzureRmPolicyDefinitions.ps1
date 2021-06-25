#Requires -Version 5.1

<#
.SYNOPSIS
  <Overview of script>

.DESCRIPTION
  <Brief description of script>

.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>

.INPUTS
  <Inputs if any, otherwise state None>

.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>

.NOTES
  Version:        1.0
  Author:         <Name>
  Creation Date:  <Date>
  Purpose/Change: Initial script development

.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>

#region Parameters

[CmdletBinding()]
param
(
  [Parameter()]
  [String]$String,
  [Parameter()]
  [SecureString]$SecureString
)

#endregion

#region Initialisations

$ErrorActionPreference = "Continue"
$VerbosePreference = "Continue"

# Dot Source required Function Libraries
Import-Module ..\Write-Log.ps1

#endregion

#region Declarations
#endregion

#region Functions

function FunctionName {
  Param()

  begin {
    Write-Log "Let's start !"
  }

  process {
    try {
      Write-Output "Hello Template !"
    }

    catch {
      Write-Output $_
      Write-Log $_ -Warning
    }
  }

  end {
    if ($?) {
      Write-Log "Completed successfully !"
    }
  }
}

#endregion

#region Execution

Write-Log "Executing $($MyInvocation.MyCommand.Name)"

$policyFolder = ".\"
$managementGroup = Get-AzureRmManagementGroup | Out-GridView -PassThru
$policyDescription = "Apply Diagnostics Settings"

foreach ($item in (Get-Childitem $policyFolder)) {
    $json = Get-Content $item.FullName | ConvertFrom-Json
    $mode = $json.mode | ConvertTo-Json
    $policyRule = $json.policyRule | ConvertTo-Json -Depth 8 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
    $parameters = $json.parameters | ConvertTo-Json -Depth 8 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
    New-AzureRmPolicyDefinition -Name $item.BaseName -DisplayName $item.BaseName -Policy $policyRule -Description $policyDescription -Parameter $parameters -Mode $json.mode -ManagementGroupName $managementGroup.Name
}

Write-Log "Finished executing $($MyInvocation.MyCommand.Name)"

#endregion
