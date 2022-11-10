# Git

Use this nice PowerShell one-liner to automatically clean up (delete) your local branches once your remote branches is deleted (merged).


```
git checkout main; git pull; git remote update origin --prune; git branch -vv | Select-String -Pattern ": gone]" | % { $_.toString().Trim().Split(" ")[0]} | % { git branch -D $_ }
```

```pwsh
git checkout main
git pull
git remote update origin --prune
git branch -vv | Select-String -Pattern ": gone]" | % { $_.toString().Trim().Split(" ")[0]} | % { git branch -D $_ }
```

