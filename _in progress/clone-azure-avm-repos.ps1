#!/usr/bin/env pwsh

# Script to clone or update all terraform-azurerm-avm-* repos from Azure GitHub organization
# Date: June 20, 2025

$ErrorActionPreference = "Stop"
$orgName = "Azure"
$repoPrefix = "terraform-azurerm-avm-"
$baseDirectory = "/Users/segraef/Git/GitHub/$orgName"

# Function to check if user is authenticated to GitHub
function Test-GithubAuth {
    try {
        $authStatus = gh auth status 2>&1
        if ($authStatus -match "Logged in to github.com") {
            Write-Host "✅ Already authenticated to GitHub" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ Not authenticated to GitHub" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "⚠️ Not authenticated to GitHub" -ForegroundColor Yellow
        return $false
    }
}

# Function to authenticate to GitHub
function Connect-Github {
    Write-Host "🔑 Please authenticate to GitHub..."
    gh auth login
    if (-not (Test-GithubAuth)) {
        Write-Host "❌ Failed to authenticate to GitHub. Exiting script." -ForegroundColor Red
        exit 1
    }
}

# Function to update existing repository
function Update-Repository {
    param (
        [string]$repoPath,
        [string]$repoName
    )

    Write-Host "🔄 Updating repository: $repoName" -ForegroundColor Cyan
    Set-Location $repoPath

    # Check if we're on main branch, if not switch to it
    $currentBranch = git branch --show-current
    if ($currentBranch -ne "main") {
        Write-Host "  Switching to main branch..."
        git switch main
    }

    # Fetch and pull latest changes
    Write-Host "  Fetching latest changes..."
    git fetch --all
    Write-Host "  Pulling latest changes..."
    git pull
    Write-Host "  ✅ Repository updated: $repoName" -ForegroundColor Green
}

# Function to clone new repository
function New-Repository {
    param (
        [string]$repoPath,
        [string]$repoName,
        [string]$repoUrl
    )

    Write-Host "📥 Cloning repository: $repoName" -ForegroundColor Magenta
    git clone $repoUrl $repoPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Repository cloned: $repoName" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to clone repository: $repoName" -ForegroundColor Red
    }
}

# Check if authenticated to GitHub
if (-not (Test-GithubAuth)) {
    Connect-Github
}

# Create base directory if it doesn't exist
if (-not (Test-Path $baseDirectory)) {
    Write-Host "📁 Creating base directory: $baseDirectory" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $baseDirectory -Force | Out-Null
}

# Change to base directory
Set-Location $baseDirectory

# Get all repositories starting with the prefix
Write-Host "🔍 Searching for repositories with prefix: $repoPrefix in $orgName organization..." -ForegroundColor Blue
$repos = gh repo list $orgName --json name,url --limit 1000 | ConvertFrom-Json | Where-Object { $_.name -like "$repoPrefix*" }

if (-not $repos) {
    Write-Host "❌ No repositories found matching the prefix: $repoPrefix" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Found $($repos.Count) repositories matching the prefix" -ForegroundColor Green

# Process each repository
foreach ($repo in $repos) {
    $repoName = $repo.name
    $repoUrl = $repo.url
    $repoPath = Join-Path $baseDirectory $repoName

    # Check if repository exists locally
    if (Test-Path $repoPath) {
        # Check if it's a Git repository
        if (Test-Path (Join-Path $repoPath ".git")) {
            # Update repository
            Update-Repository -repoPath $repoPath -repoName $repoName
        } else {
            Write-Host "⚠️ Directory exists but is not a Git repository: $repoName" -ForegroundColor Yellow
            # Rename existing directory
            $backupPath = "$repoPath-backup-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Write-Host "  Moving existing directory to $backupPath"
            Move-Item -Path $repoPath -Destination $backupPath
            # Clone repository
            New-Repository -repoPath $repoPath -repoName $repoName -repoUrl $repoUrl
        }
    } else {
        # Clone repository
        New-Repository -repoPath $repoPath -repoName $repoName -repoUrl $repoUrl
    }
}

Write-Host "✅ All repositories processed successfully!" -ForegroundColor Green
