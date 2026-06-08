#Requires -Version 7.0

<#
.SYNOPSIS
  Simulates mouse and keyboard activity to stop the screensaver from starting.

.DESCRIPTION
  Sends a periodic keystroke and nudges the cursor for the requested number of
  minutes so the session stays active and the screensaver or lock timeout does
  not trigger. A progress bar shows the remaining time. If no duration is given
  the script prompts for one.

.PARAMETER Minutes
  Number of minutes to simulate activity for. If omitted, the script prompts
  for a value.

.INPUTS
  None. This script does not accept pipeline input.

.OUTPUTS
  None. Status is written to the host and progress streams.

.EXAMPLE
  ./Activity-Simulator.ps1 -Minutes 60
  Keeps the session active for 60 minutes.

.LINK
  https://graef.io

.NOTES
  Author: Sebastian Gräf
  Repo:   https://github.com/segraef/Scripts
#>

#region Parameters
[CmdletBinding()]
param
(
    [Parameter()]
    [string]$Minutes
)
#endregion

#region Execution
begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    Import-Module "$PSScriptRoot/Write-Log.psm1" -Force

    Write-Verbose " [$($MyInvocation.InvocationName)] :: Start Process"
}

process {
    Add-Type -AssemblyName System.Windows.Forms
    $shell = New-Object -ComObject 'Wscript.Shell'

    $pshost = Get-Host
    $pswindow = $pshost.ui.rawui
    $pswindow.windowtitle = 'Activity-Simulator'

    if (!$Minutes) {
        $Minutes = Read-Host -Prompt 'Enter minutes for simulating activity'
    }

    for ($i = 0; $i -lt $Minutes; $i++) {
        $start = (Get-Date -Format HH:mm:ss)
        $timeleft = $Minutes - $i
        Clear-Host
        Write-Log "Start: $start"
        $shell.sendkeys(' ')
        for ($j = 0; $j -lt 6; $j++) {
            for ($k = 0; $k -lt 10; $k++) {
                Write-Progress -Activity 'Simulating activity ...' -PercentComplete ($k * 10) -Status "Please wait $timeleft Minutes."
                Start-Sleep -Seconds 1
            }
        }
        $pos = [System.Windows.Forms.Cursor]::Position
        $x = ($pos.X % 500) + 1
        $y = ($pos.Y % 500) + 1
        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y)
    }
}

end {
    Write-Verbose " [$($MyInvocation.InvocationName)] :: End Process"
}
#endregion
