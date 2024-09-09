$tfrepos = gh repo list azure -L 5000 --json name --jq '.[].name' | Select-String -Pattern "terraform-azurerm-avm"

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

  # Fetch PRs
  $prs = gh pr list -R "Azure/$repo" --json number,title,url | ConvertFrom-Json
  foreach ($pr in $prs) {
    $pr | Add-Member -NotePropertyName "repo" -NotePropertyValue $repo
    $pr | Add-Member -NotePropertyName "type" -NotePropertyValue "pr"
  }
  $allItems += $prs
}

$allItems | ConvertTo-Json

# list PRs starting with 'chore'

$allItems | Where-Object { $_.title -contains "chore: repository governance" -and $_.type -eq "pr" } | Select-Object title,url

# approve all PRs starting with 'chore'

foreach ($pr in $allItems | Where-Object { $_.title -eq "chore: repository governance" -and $_.type -eq "pr" })
{
  Write-Host "Approving PR $($pr.title) on repo $($pr.repo)"
  gh pr review $pr.number -R "Azure/$($pr.repo)" --approve --body "Please ensure all checks pass before merging."
#  gh pr merge $pr.number -R "Azure/$($pr.repo)" --squash
}
