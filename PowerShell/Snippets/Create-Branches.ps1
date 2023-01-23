Param(
   [string]$destinationFolder = "."
)

$repos = Get-ChildItem -Path $destinationFolder -Directory

foreach($repo in $repos) {
   $($repo.FullName)
   Set-Location "$($repo.FullName)";
   git checkout -b users/segraef/provider-upgrade;
   git push --set-upstream origin users/segraef/provider-upgrade;
   git add .;
   git commit -m "provider upgrade";
   git push;
}

