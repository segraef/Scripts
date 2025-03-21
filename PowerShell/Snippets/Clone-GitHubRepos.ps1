function Clone-GitHubRepos {
    [CmdletBinding()]
    Param(
        [string]$destinationFolder = "/Users/segraef/Git/GitHub",
        [string]$org = 'Azure',
        [string[]]$repos
    )

    Write-Output "Found $($repos.Count) repositories."
    $confirmation = Read-Host "Do you want to proceed with processing these repositories? (y/n)"
    if ($confirmation -ne 'y') {
        return
    }

    foreach ($repo in $repos) {
        $repoPath = Join-Path -Path $destinationFolder -ChildPath "$org/$repo"
        If (!(Test-Path -Path $repoPath)) {
            New-Item -ItemType Directory -Path $repoPath -Force
            Set-Location -Path $repoPath
            Write-Output "Cloning repository $repo into $repoPath."
            git clone "https://github.com/$org/$repo.git"
        } else {
            Write-Output "Directory $repoPath already exists. Updating only."
            if ((Get-ChildItem -Path $repoPath).Count -eq 0) {
                Write-Output "Cloning repository $repo into $repoPath."
                git clone "https://github.com/$org/$repo.git"
            } else {
                Write-Output "Pulling latest changes for $repo."
                Set-Location -Path $repoPath
                git checkout main
                git pull
            }
        }
    }
}

# Example usage:
$tfrepos = gh repo list azure -L 5000 --json name --jq '.[].name' | Select-String -Pattern "terraform-azurerm-avm"
Clone-GitHubRepos -repos $tfrepos
