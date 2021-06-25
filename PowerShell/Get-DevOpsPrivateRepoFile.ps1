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

$devOpsAccountName = 'segraef'
$devOpsTeamProjectName = 'Oahu'
$devOpsPAT = 'xxx'
$devOpsBaseUrl = 'https://' + $devOpsAccountName + '.visualstudio.com'

$FileRepo = 'Oahu'
$FileRepoBranch = 'master'
$FilePath = 'Scripts/PowerShell/123.ps1'

$User=""

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$devOpsPAT)));
$devOpsAuthHeader = @{Authorization=("Basic {0}" -f $base64AuthInfo)};

$Uri = $devOpsBaseUrl + '/' + $devOpsTeamProjectName + '/_apis/git/repositories/' + $FileRepo  + '/items?path=' + $FilePath + '&$format=json&includeContent=true&versionDescriptor.version=' + $FileRepoBranch + '&versionDescriptor.versionType=branch&api-version=4.1'

$File = Invoke-RestMethod -Method Get -ContentType application/json -Uri $Uri -Headers $devOpsAuthHeader

Write-Host $File.content

Write-Log "Finished executing $($MyInvocation.MyCommand.Name)"

#endregion
