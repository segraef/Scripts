gh alias set prs 'api graphql --paginate -f filter="type:pr state:open review-requested:myusername $1" -f query="
query($filter: String!){
  search(query: $filter, type: ISSUE, first: 100) {
    issueCount
    pageInfo {
      endCursor
      startCursor
    }
    edges {
      node {
        ... on PullRequest {
          url
        }
      }
    }
  }
}
" --jq ".data.search.edges[].node.url"'

gh search prs --review-requested=Azure/avm-core-team-technical-bicep
gh search prs --review-requested=Azure/avm-core-team-technical-terraform

gh alias set issues 'api graphql --paginate -f filter="type:issue state:open $1" -f query="
query($filter: String!){
  search(query: $filter, type: ISSUE, first: 100) {
    issueCount
    pageInfo {
      endCursor
      startCursor
    }
    edges {
      node {
        ... on Issue {
          url
        }
      }
    }
  }
}
" --jq ".data.search.edges[].node.url"'

# show all issue
gh issues 'repo:Azure/terraform-azurerm-avm-res-keyvault-vault'

gh alias set openprs 'api graphql --paginate -f filter="type:pr state:open $1" -f query="
query($filter: String!){
  search(query: $filter, type: ISSUE, first: 100) {
    issueCount
    pageInfo {
      endCursor
      startCursor
    }
    edges {
      node {
        ... on PullRequest {
          url
        }
      }
    }
  }
}
" --jq ".data.search.edges[].node.url"'

# show all open pull requests
gh openprs 'repo:Azure/terraform-azurerm-avm-res-keyvault-vault'

# Get list of all repositories for a user
repos=$(curl -H "Accept: application/vnd.github.v3+json" "https://api.github.com/users/Azure/repos")

# Loop over each repository and check if it starts with 'terraform-azurerm-avm'
echo $repos | jq -r '.[] | select(.name | startswith("terraform-azurerm-avm")) | .name'

$page = 1
$allRepos = @()

do {
    $repos = Invoke-RestMethod -Uri "https://api.github.com/users/Azure/repos?page=$page&per_page=100"
    if ($repos.Count -eq 0) {
        break
    }
    $allRepos += $repos
    $page++
} while ($true)
$tfrepos = $allRepos | Where-Object { $_.name -like "terraform-azurerm-avm*" } | ForEach-Object { $_.name }
$allIssues = @()

# list issues and PRs
foreach ($repo in $tfrepos)
{
  Write-Host "Fetching issues for $repo"
  $issues = gh issue list -R "Azure/$repo" --json number,title,url | ConvertFrom-Json
  foreach ($issue in $issues) {
    $issue | Add-Member -NotePropertyName "repo" -NotePropertyValue $repo
  }
  $allIssues += $issues
}
$allIssues | ConvertTo-Json

# list PRs

$allPRs = @()
foreach ($repo in $tfrepos)
{
  Write-Host "Fetching PRs for $repo"
  $prs = gh pr list -R "Azure/$repo" --json number,title,url | ConvertFrom-Json
  foreach ($pr in $prs) {
    $pr | Add-Member -NotePropertyName "repo" -NotePropertyValue $repo
  }
  $allPRs += $prs
}
$allPRs | ConvertTo-Json

# list PRs sorted by title

$allPRs | Select-Object title,url | Sort-Object title

# list PRs starting with 'chore'

$allPRs | Select-Object title,url | Sort-Object title | Where-Object { $_.title -like "chore*" }

# approve all PRs

foreach ($pr in $allPRs)
{
  Write-Host "Approving PR $pr.title"
  gh pr review $pr.number -R --approve
}

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

$allItems | Where-Object { $_.title -like "chore*" -and $_.type -eq "pr" } | Select-Object title,url

# approve all PRs starting with 'chore'

foreach ($pr in $allItems | Where-Object { $_.title -like "chore*" -and $_.type -eq "pr" })
{
  Write-Host "Approving PR $($pr.title) on repo $($pr.repo)"
  # gh pr review $pr.number -R "Azure/$($pr.repo)" --approve
}


$page = 1
$allIssues = @()

do {
    $repos = Invoke-RestMethod -Uri "https://api.github.com/users/Azure/repos?page=$page&per_page=100"
    if ($repos.Count -eq 0) { break }
    $page++
    $tfrepos = $repos | Where-Object { $_.name -like "terraform-azurerm-avm*" } | ForEach-Object { $_.name }
    foreach ($repo in $tfrepos) {
        $allIssues += gh issue list -R "Azure/$repo" --json title,url,number | ConvertFrom-Json
    }
} while ($repos.Count -gt 0)

$allIssues | ConvertTo-Json

# APi

$apiEndpoint = "https://api.github.com/repos/Azure/Azure-Verified-Modules/projects"

# Send a GET request to the API endpoint
$projects = Invoke-RestMethod -Method Get -Uri $apiEndpoint -Headers @{
    "Authorization" = "Bearer token"
    "Accept" = "application/vnd.github.inertia-preview+json"
}

# Print the ID of each project
foreach ($project in $projects) {
    Write-Output "Project: $($project.name), ID: $($project.id)"
}

# cancel all workflows

# Get the running workflow runs
$runs = gh run list --repo segraef/bicep-registry-modules --json databaseId,status | ConvertFrom-Json

# Loop over the runs and cancel each one that's in progress
foreach ($run in $runs) {
    if ($run.status -eq 'in_progress') {
        gh run cancel $run.databaseId --repo segraef/bicep-registry-modules
    }
}

