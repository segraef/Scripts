#Requires -Version 7.0

<#
.SYNOPSIS
  Displays GitHub API rate-limit buckets using GitHub CLI.

.DESCRIPTION
  Queries GitHub's /rate_limit endpoint through GitHub CLI and renders the
  response as either formatted JSON or a terminal-friendly table sorted by the
  most constrained buckets first.

  This PowerShell version only requires GitHub CLI. Unlike the Bash version, it
  does not require jq because JSON parsing is handled natively by PowerShell.

  Requirements:
    - GitHub CLI: gh
    - An authenticated gh session

  Setup:
    Install GitHub CLI, then authenticate once:

      gh auth login

    Examples:
      macOS:   brew install gh
      Windows: winget install --id GitHub.cli
      Linux:   https://cli.github.com/ for distro-specific packages

  This script polls GitHub's /rate_limit endpoint, which is exempt from rate
  limiting, so watch mode is safe to use.

.PARAMETER Watch
  Refresh continuously until interrupted.

.PARAMETER Interval
  Refresh interval in seconds for watch mode. Default is 10.

.PARAMETER Json
  Print the raw API response as formatted JSON.

.PARAMETER Quiet
  Only show buckets whose remaining value is below the limit and whose limit is
  greater than zero.

.PARAMETER Help
  Show usage information.

.INPUTS
  None. This script does not accept pipeline input.

.OUTPUTS
  System.String. Renders the rate-limit table, formatted JSON, or usage text.

.EXAMPLE
  ./Get-GitHubRateLimit.ps1
  Print a one-off snapshot of all rate-limit buckets.

.EXAMPLE
  ./Get-GitHubRateLimit.ps1 -Watch -Interval 60
  Refresh the table every 60 seconds until interrupted.

.EXAMPLE
  ./Get-GitHubRateLimit.ps1 -Quiet
  Show only buckets with limit greater than zero and remaining below limit.

.EXAMPLE
  ./Get-GitHubRateLimit.ps1 -Json
  Print the raw API response as formatted JSON.

.NOTES
  Author: Sebastian Gräf
  Repo:   https://github.com/segraef/Scripts
  Version history is tracked in git, not in this header.
#>

[CmdletBinding()]
param
(
    [Alias('w')]
    [switch]$Watch,

    [Alias('i')]
    [ValidateRange(1, 86400)]
    [int]$Interval = 10,

    [Alias('j')]
    [switch]$Json,

    [Alias('q')]
    [switch]$Quiet,

    [Alias('h')]
    [switch]$Help
)

#region Initialisation
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Write-Log.psm1" -Force
#endregion

#region Functions
function Show-Usage {
    <#
    .SYNOPSIS
      Print command-line usage information for this script.

    .DESCRIPTION
      Emits a human-readable summary of switches, short flags, requirements and
      examples to the output stream.

    .EXAMPLE
      Show-Usage
      Print the usage banner.
    #>
    [CmdletBinding()]
    param ()

    Write-Output @'
Get-GitHubRateLimit - GitHub API rate-limit monitor

Usage:
  Get-GitHubRateLimit.ps1              # snapshot
  Get-GitHubRateLimit.ps1 -Watch       # watch mode (refresh every 10s)
  Get-GitHubRateLimit.ps1 -Watch -Interval 5
  Get-GitHubRateLimit.ps1 -Json        # raw JSON
  Get-GitHubRateLimit.ps1 -Quiet       # only buckets with limit > 0 and remaining < limit
  Get-GitHubRateLimit.ps1 -Help

Short flags:
  -w -i 5 -j -q -h

Requirements:
  - gh (GitHub CLI)
  - an authenticated gh session

Setup:
  1. Install GitHub CLI.
     macOS:   brew install gh
     Windows: winget install --id GitHub.cli
     Linux:   https://cli.github.com/
  2. Authenticate once:
     gh auth login

Notes:
  - This PowerShell version does not require jq.
  - It uses gh for API calls and auth context.
  - /rate_limit itself is exempt from rate limiting, so polling it is safe.

Examples:
  Get-GitHubRateLimit.ps1
  Get-GitHubRateLimit.ps1 -Quiet
  Get-GitHubRateLimit.ps1 -Watch -Interval 60
  Get-GitHubRateLimit.ps1 -Json
'@
}

function Test-CommandExists {
    <#
    .SYNOPSIS
      Test whether a command is available on PATH.

    .DESCRIPTION
      Returns $true when Get-Command can resolve the supplied command name,
      otherwise $false.

    .PARAMETER Name
      The command name to resolve (for example 'gh').

    .EXAMPLE
      Test-CommandExists -Name 'gh'
      Returns $true when GitHub CLI is installed.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = 'Exists is a state predicate, not a plural noun.')]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Get-Style {
    <#
    .SYNOPSIS
      Build an ANSI escape sequence for a terminal style code.

    .DESCRIPTION
      Returns an ANSI escape sequence for the supplied SGR code, or an empty
      string when output is redirected or the terminal is 'dumb'.

    .PARAMETER Code
      The SGR (Select Graphic Rendition) code, for example '31' for red.

    .EXAMPLE
      Get-Style -Code '1'
      Returns the bold escape sequence when the terminal supports colour.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Code
    )

    if ([Console]::IsOutputRedirected -or $env:TERM -eq 'dumb') {
        return ''
    }

    return [char]27 + '[' + $Code + 'm'
}

function Get-Bar {
    <#
    .SYNOPSIS
      Render a coloured usage bar for a rate-limit bucket.

    .DESCRIPTION
      Produces a fixed-width bar whose filled portion is proportional to the
      remaining quota, coloured green, yellow or red by percentage remaining.

    .PARAMETER Remaining
      The remaining requests in the bucket.

    .PARAMETER Limit
      The total request limit for the bucket.

    .PARAMETER Width
      The bar width in characters. Default is 24.

    .EXAMPLE
      Get-Bar -Remaining 50 -Limit 100
      Returns a half-filled bar.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [int]$Remaining,

        [Parameter(Mandatory)]
        [int]$Limit,

        [Parameter()]
        [int]$Width = 24
    )

    if ($Limit -le 0) {
        return ' ' * $Width
    }

    $filled = [math]::Floor(($Remaining * $Width) / $Limit)
    if ($filled -lt 0) {
        $filled = 0
    }
    if ($filled -gt $Width) {
        $filled = $Width
    }
    $empty = $Width - $filled
    $pct = [math]::Floor(($Remaining * 100) / $Limit)

    $colour = $script:C_GRN
    if ($pct -lt 10) {
        $colour = $script:C_RED
    }
    elseif ($pct -lt 33) {
        $colour = $script:C_YEL
    }

    $filledText = if ($filled -gt 0) { '█' * $filled } else { '' }
    $emptyText = if ($empty -gt 0) { '░' * $empty } else { '' }

    return "$colour$filledText$($script:C_DIM)$emptyText$($script:C_RESET)"
}

function Get-HumanReset {
    <#
    .SYNOPSIS
      Format a Unix reset timestamp as a human-readable countdown.

    .DESCRIPTION
      Converts an absolute Unix epoch reset time into a relative string such as
      'in 4m05s', 'in 30s', or 'now' when the reset is in the past.

    .PARAMETER Target
      The reset time as Unix epoch seconds.

    .EXAMPLE
      Get-HumanReset -Target 1717000000
      Returns a relative countdown string for that reset time.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [long]$Target
    )

    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $diff = $Target - $now
    if ($diff -le 0) {
        return 'now'
    }

    $minutes = [math]::Floor($diff / 60)
    $seconds = $diff % 60
    if ($minutes -gt 0) {
        return ('in {0}m{1:00}s' -f $minutes, $seconds)
    }

    return ('in {0}s' -f $seconds)
}

function Get-HostName {
    <#
    .SYNOPSIS
      Resolve the GitHub host the current gh session is logged in to.

    .DESCRIPTION
      Parses 'gh auth status' to extract the host name, falling back to
      'github.com' when it cannot be determined.

    .EXAMPLE
      Get-HostName
      Returns 'github.com' for a standard authenticated session.
    #>
    [CmdletBinding()]
    param ()

    try {
        $status = gh auth status 2>&1 | Out-String
        $match = [regex]::Match($status, 'Logged in to\s+([^\s]+)')
        if ($match.Success) {
            return $match.Groups[1].Value
        }
    }
    catch {
        Write-Log -Message 'Could not determine gh host; falling back to github.com.' -ErrorRecord $_
    }

    return 'github.com'
}

function Invoke-Render {
    <#
    .SYNOPSIS
      Fetch and render the current GitHub rate-limit state.

    .DESCRIPTION
      Calls 'gh api rate_limit' and renders the response either as formatted
      JSON (when -Json is set) or as a coloured table sorted by the most
      constrained buckets first. Honours the script-level -Quiet switch.

    .EXAMPLE
      Invoke-Render
      Render a single snapshot of the rate-limit buckets.
    #>
    [CmdletBinding()]
    param ()

    $payloadText = gh api rate_limit 2>$null
    if (-not $payloadText) {
        throw 'gh api failed - are you authenticated? (gh auth status)'
    }

    if ($Json) {
        Write-Output ($payloadText | ConvertFrom-Json | ConvertTo-Json -Depth 8)
        return
    }

    $payload = $payloadText | ConvertFrom-Json

    $user = '?'
    try {
        $user = (gh api user --jq .login 2>$null).Trim()
        if (-not $user) {
            $user = '?'
        }
    }
    catch {
        Write-Log -Message 'Could not resolve gh user login.' -ErrorRecord $_
    }

    $hostName = Get-HostName
    $now = Get-Date -Format 'HH:mm:ss'
    Write-Output ("{0}{1}GitHub rate limits{2}  user={3}{4}{5}  host={6}  {7}{8}{2}" -f $script:C_BOLD, $script:C_CYN, $script:C_RESET, $script:C_BOLD, $user, $script:C_RESET, $hostName, $script:C_DIM, $now)
    Write-Output ''

    $entries = foreach ($property in $payload.resources.PSObject.Properties) {
        $value = $property.Value
        $pct = if ($value.limit -gt 0) { [math]::Floor(($value.remaining * 100) / $value.limit) } else { 100 }
        [pscustomobject]@{
            Key = $property.Name
            Remaining = [int]$value.remaining
            Limit = [int]$value.limit
            Used = [int]$value.used
            Reset = [long]$value.reset
            Pct = [int]$pct
        }
    }

    foreach ($entry in ($entries | Sort-Object Pct, Key)) {
        if ($Quiet -and (($entry.Remaining -eq $entry.Limit) -or ($entry.Limit -eq 0))) {
            continue
        }

        $line = "{0}{1,-26}{2} {3,5}/{4,-5} {5} {6,3}%  resets {7}" -f `
            $script:C_BOLD, $entry.Key, $script:C_RESET, $entry.Remaining, $entry.Limit, (Get-Bar -Remaining $entry.Remaining -Limit $entry.Limit -Width 24), $entry.Pct, (Get-HumanReset -Target $entry.Reset)
        Write-Output $line
    }
}
#endregion

#region Execution
if ($Help) {
    Show-Usage
    return
}

$script:C_RESET = Get-Style '0'
$script:C_DIM = Get-Style '2'
$script:C_BOLD = Get-Style '1'
$script:C_RED = Get-Style '31'
$script:C_YEL = Get-Style '33'
$script:C_GRN = Get-Style '32'
$script:C_CYN = Get-Style '36'

if (-not (Test-CommandExists -Name 'gh')) {
    Write-Log -Message 'gh not installed.' -Level Error
    exit 1
}

try {
    gh auth status *> $null
}
catch {
    Write-Log -Message 'gh is installed but not authenticated. Run: gh auth login' -ErrorRecord $_
    exit 1
}

if ($Watch) {
    while ($true) {
        Clear-Host
        try {
            Invoke-Render
        }
        catch {
            Write-Log -Message 'Failed to render rate-limit snapshot.' -ErrorRecord $_
        }
        Write-Output ''
        Write-Output ("{0}refresh every {1}s - ctrl-c to exit{2}" -f $script:C_DIM, $Interval, $script:C_RESET)
        Start-Sleep -Seconds $Interval
    }
}
else {
    Invoke-Render
}
#endregion
