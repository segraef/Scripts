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
  Author:         Sebastian Gräf
  Creation Date:  21/06/2021
  Purpose/Change: Initial script development

.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>

#region Parameters

[CmdletBinding()]
param
(
  [String]$Message,
  [Switch]$Warning,
  [System.Management.Automation.ErrorRecord]$ErrorObj
)

#endregion

#region Initialisations

$ErrorActionPreference = "Continue"
$VerbosePreference = "Continue"

#endregion

#region Declarations
#endregion

#region Functions
#endregion

#region Execution

$LogMessage = "[$(Get-Date -f g)] "

if ($PSBoundParameters.ContainsKey("ErrorObj")) {
  $LogMessage += " $ErrorObj $($ErrorObj.ScriptStackTrace.Split("`n") -join ' <-- ')"
  Write-Error -Message $LogMessage
}
elseif ($PSBoundParameters.ContainsKey("Warning")) {
  $LogMessage += " $Message"
  Write-Warning -Message $LogMessage
}
else {
  $LogMessage += " $Message"
  Write-Verbose -Message $LogMessage
}

#endregion
