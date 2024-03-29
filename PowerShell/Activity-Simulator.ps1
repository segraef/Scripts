﻿#Requires -Version 5.1

<#
.SYNOPSIS
    Simulates Mouse and Keyboard Activity to avoid Screensaver coming up.

.DESCRIPTION
    Simulates Mouse and Keyboard Activity to avoid Screensaver coming up.

.PARAMETER Minutes
	Commit minutes for simulating activity. If no string given you will be asked.

.PARAMETER Verbose
    Run in Verbose Mode.

.EXAMPLE
	PS C:\> Avtivity-Simulator.ps1 -Minutes 60

.LINK
    https://graef.io

.NOTES
    Author:  Sebastian Gräf
    Email:   sebastian@graef.io
    Date:    September 9, 2017
#>

[Cmdletbinding()]
Param (
	[Parameter(Mandatory = $false)]
	[string]$Minutes
)

Begin {
	Write-Verbose " [$($MyInvocation.InvocationName)] :: Start Process"
}

Process {
	Add-Type -AssemblyName System.Windows.Forms
	$shell = New-Object -com "Wscript.Shell"

	$pshost = Get-Host
	$pswindow = $pshost.ui.rawui
	$pswindow.windowtitle = 'Activity-Simulator'

	if (!$minutes) {
		$Minutes = Read-Host -Prompt "Enter minutes for simulating activity"
	}

	for ($i = 0; $i -lt $Minutes; $i++) {
		$start = (Get-Date -Format HH:mm:ss)
		$timeleft = $Minutes - $i
		Clear-Host
		Write-Output "Start: $start"
		$shell.sendkeys(' ')
		for ($j = 0; $j -lt 6; $j++) {
			for ($k = 0; $k -lt 10; $k++) {
				Write-Progress -Activity 'Simulating activity ...' -PercentComplete ($k * 10) -Status "Please wait $timeleft Minutes."
				Start-Sleep -Seconds 1
			}
		}
		$Pos = [System.Windows.Forms.Cursor]::Position
		$x = ($pos.X % 500) + 1
		$y = ($pos.Y % 500) + 1
		[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y)
	}
}
End {
	Write-Verbose " [$($MyInvocation.InvocationName)] :: End Process"
}
