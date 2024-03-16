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

foreach ($repo in $tfrepos)
{
  Write-Host "Fetching issues for $repo"
  $issues = gh issue list -R "Azure/$repo" --json title,url | ConvertFrom-Json
  $allIssues += $issues
}
$allIssues | ConvertTo-Json


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
