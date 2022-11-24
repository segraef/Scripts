$folder = Get-Location # '.'
$localRepos = Get-ChildItem $folder.Path -Directory | select *

foreach($repo in $localRepos) {
    "$($repo.FullName)"
    Set-Location "$($repo.FullName)"
    git tag -d 1.0.0
    git checkout main; git pull; git remote update origin --prune; git branch -vv | Select-String -Pattern ": gone]" | % { $_.toString().Trim().Split(" ")[0]} | % { git branch -D $_ }
}
Set-Location $folder.Path
