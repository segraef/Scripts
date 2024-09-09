$tfrepos = gh repo list azure -L 5000 --json name --jq '.[].name' | findstr terraform-azurerm-avm

$allItems = @()
Write-Host "Fetching issues and PRs for $($tfrepos.Count) repos"
foreach ($repo in $tfrepos)
{
  Write-Host "Fetching issues and PRs for $repo"

  # Fetch issues
  $issues = gh issue list -R "Azure/$repo" --json number,title,url | ConvertFrom-Json
  foreach ($issue in $issues) {
    $issue | Add-Member -NotePropertyName "repo" -NotePropertyValue $repo
    $issue | Add-Member -NotePropertyName "type" -NotePropertyValue "issue"
  }
  $allItems += $issues
}

$allItems | ConvertTo-Json

$allItems | Where-Object { $_.type -eq "issue" } | Select-Object title,url

# Add all issues to project'

foreach ($issue in $allItems)
{
  if($issue.repo -ne "terraform-azurerm-avm-template")
  {
      Write-Host "Adding Issue $($issue.title) on repo $($issue.repo)"
      gh issue edit $issue.url --add-project "AVM - Module Issues"
  }
}
