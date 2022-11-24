$folder = '.'
$localRepos = Get-ChildItem $folder -Recurse

foreach($repo in $localRepos) {
    Set-Locatation $repo.FullName
    # git checkout main; git pull; git remote update origin --prune; git branch -vv | Select-String -Pattern ": gone]" | % { $_.toString().Trim().Split(" ")[0]} | % { git branch -D $_ }
 }
