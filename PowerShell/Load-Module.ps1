#Requires -Version 7.0

<#
.SYNOPSIS
  Ensures a PowerShell module is available and imported, installing it if needed.

.DESCRIPTION
  Resolves a module by name in three steps: if it is already loaded it does
  nothing, if it is installed but not loaded it imports it, and if it is neither
  it attempts to install it from the PowerShell Gallery (current-user scope) and
  then import it. If the module cannot be found in the gallery the script logs
  the failure and exits with code 1.

.PARAMETER Module
  Name of the module to load. Must be a non-empty string matching a module that
  is installed locally or published to the PowerShell Gallery.

.INPUTS
  None. This script does not accept pipeline input.

.OUTPUTS
  None. Progress and outcome are written to the log stream.

.EXAMPLE
  ./Load-Module.ps1 -Module 'Az.Accounts'
  Imports Az.Accounts, installing it from the PowerShell Gallery first if it is
  not already present on the machine.

.NOTES
  Author: Sebastian Gräf
  Repo:   https://github.com/segraef/Scripts
#>

#region Parameters
[CmdletBinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Module
)
#endregion

#region Initialisation
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Write-Log.psm1" -Force
#endregion

#region Execution
Write-Log "Executing $($MyInvocation.MyCommand.Name)."

try {
    if (Get-Module | Where-Object { $_.Name -eq $Module }) {
        Write-Log "Module '$Module' is already imported."
    }
    elseif (Get-Module -ListAvailable | Where-Object { $_.Name -eq $Module }) {
        if ($PSCmdlet.ShouldProcess($Module, 'Import module')) {
            Import-Module $Module
            Write-Log "Imported module '$Module'."
        }
    }
    elseif (Find-Module -Name $Module | Where-Object { $_.Name -eq $Module }) {
        if ($PSCmdlet.ShouldProcess($Module, 'Install and import module')) {
            Install-Module -Name $Module -Force -Scope CurrentUser
            Import-Module $Module
            Write-Log "Installed and imported module '$Module'."
        }
    }
    else {
        Write-Log "Module '$Module' not imported, not available and not in the online gallery, exiting." -Level Warning
        exit 1
    }
}
catch {
    Write-Log -Message "Failed to load module '$Module'." -ErrorRecord $_
    throw
}

Write-Log "Finished executing $($MyInvocation.MyCommand.Name)."
#endregion
