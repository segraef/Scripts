#!/usr/bin/env pwsh

<#
.SYNOPSIS
Displays GitHub API rate-limit buckets using GitHub CLI.

.DESCRIPTION
Queries GitHub's /rate_limit endpoint through GitHub CLI and renders the
response as either formatted JSON or a terminal-friendly table sorted by the
most constrained buckets first.

This PowerShell version only requires GitHub CLI. Unlike the Bash version, it
does not require jq because JSON parsing is handled natively by PowerShell.

.REQUIREMENTS
- GitHub CLI: gh
- An authenticated gh session

.SETUP
Install GitHub CLI, then authenticate once:

  gh auth login

Examples:
- macOS:  brew install gh
- Windows: winget install --id GitHub.cli
- Linux: see https://cli.github.com/ for distro-specific packages

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

.EXAMPLE
pwsh -File ./gh-ratelimit.ps1

.EXAMPLE
pwsh -File ./gh-ratelimit.ps1 -Watch -Interval 60

.EXAMPLE
pwsh -File ./gh-ratelimit.ps1 -Quiet

.EXAMPLE
pwsh -File ./gh-ratelimit.ps1 -Json
#>

param(
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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Usage {
  @'
gh-ratelimit - GitHub API rate-limit monitor

Usage:
  gh-ratelimit.ps1              # snapshot
  gh-ratelimit.ps1 -Watch       # watch mode (refresh every 10s)
  gh-ratelimit.ps1 -Watch -Interval 5
  gh-ratelimit.ps1 -Json        # raw JSON
  gh-ratelimit.ps1 -Quiet       # only buckets with limit > 0 and remaining < limit
  gh-ratelimit.ps1 -Help

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
  gh-ratelimit.ps1
  gh-ratelimit.ps1 -Quiet
  gh-ratelimit.ps1 -Watch -Interval 60
  gh-ratelimit.ps1 -Json
'@
}

function Test-CommandExists {
  param([Parameter(Mandatory = $true)][string]$Name)

  return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Get-Style {
  param([Parameter(Mandatory = $true)][string]$Code)

  if ([Console]::IsOutputRedirected -or $env:TERM -eq 'dumb') {
    return ''
  }

  return [char]27 + '[' + $Code + 'm'
}

$C_RESET = Get-Style '0'
$C_DIM = Get-Style '2'
$C_BOLD = Get-Style '1'
$C_RED = Get-Style '31'
$C_YEL = Get-Style '33'
$C_GRN = Get-Style '32'
$C_CYN = Get-Style '36'

function Get-Bar {
  param(
    [Parameter(Mandatory = $true)][int]$Remaining,
    [Parameter(Mandatory = $true)][int]$Limit,
    [int]$Width = 24
  )

  if ($Limit -le 0) {
    return ' ' * $Width
  }

  $filled = [math]::Floor(($Remaining * $Width) / $Limit)
  if ($filled -lt 0) { $filled = 0 }
  if ($filled -gt $Width) { $filled = $Width }
  $empty = $Width - $filled
  $pct = [math]::Floor(($Remaining * 100) / $Limit)

  $colour = $C_GRN
  if ($pct -lt 10) {
    $colour = $C_RED
  } elseif ($pct -lt 33) {
    $colour = $C_YEL
  }

  $filledText = if ($filled -gt 0) { '█' * $filled } else { '' }
  $emptyText = if ($empty -gt 0) { '░' * $empty } else { '' }

  return "$colour$filledText$C_DIM$emptyText$C_RESET"
}

function Get-HumanReset {
  param([Parameter(Mandatory = $true)][long]$Target)

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
  try {
    $status = gh auth status 2>&1 | Out-String
    $match = [regex]::Match($status, 'Logged in to\s+([^\s]+)')
    if ($match.Success) {
      return $match.Groups[1].Value
    }
  } catch {
  }

  return 'github.com'
}

function Render {
  $payloadText = gh api rate_limit 2>$null
  if (-not $payloadText) {
    throw 'gh api failed - are you authenticated? (gh auth status)'
  }

  if ($Json) {
    $payloadText | ConvertFrom-Json | ConvertTo-Json -Depth 8
    return
  }

  $payload = $payloadText | ConvertFrom-Json

  $user = '?'
  try {
    $user = (gh api user --jq .login 2>$null).Trim()
    if (-not $user) {
      $user = '?'
    }
  } catch {
  }

  $hostName = Get-HostName
  $now = Get-Date -Format 'HH:mm:ss'
  Write-Output ("{0}{1}GitHub rate limits{2}  user={3}{4}{5}  host={6}  {7}{8}{2}" -f $C_BOLD, $C_CYN, $C_RESET, $C_BOLD, $user, $C_RESET, $hostName, $C_DIM, $now)
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
      $C_BOLD, $entry.Key, $C_RESET, $entry.Remaining, $entry.Limit, (Get-Bar -Remaining $entry.Remaining -Limit $entry.Limit -Width 24), $entry.Pct, (Get-HumanReset -Target $entry.Reset)
    Write-Output $line
  }
}

if ($Help) {
  Show-Usage
  exit 0
}

if (-not (Test-CommandExists -Name 'gh')) {
  Write-Error 'gh not installed'
  exit 1
}

try {
  gh auth status *> $null
} catch {
  Write-Error 'gh is installed but not authenticated. Run: gh auth login'
  exit 1
}

if ($Watch) {
  while ($true) {
    Clear-Host
    try {
      Render
    } catch {
      Write-Error $_.Exception.Message
    }
    Write-Output ''
    Write-Output ("{0}refresh every {1}s - ctrl-c to exit{2}" -f $C_DIM, $Interval, $C_RESET)
    Start-Sleep -Seconds $Interval
  }
} else {
  Render
}
