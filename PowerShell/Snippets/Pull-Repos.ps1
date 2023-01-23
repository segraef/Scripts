Param(
   [string]$destinationFolder = "."
)

$repos = Get-ChildItem -Path $destinationFolder -Directory

foreach($repo in $repos) {
   $($repo.FullName)
   Set-Location "$($repo.FullName)";
   git checkout main;
   git pull;
}
