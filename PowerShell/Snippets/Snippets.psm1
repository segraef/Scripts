#Requires -Version 7.0

<#
.SYNOPSIS
  Reusable automation helpers distilled from the personal snippet collection.

.DESCRIPTION
  Converts the ad-hoc scripts under PowerShell/Snippets into a single module of
  advanced functions covering Azure (Az PowerShell, Azure CLI), Azure DevOps
  (REST + CLI), GitHub (gh CLI) and local git/file housekeeping. Every function
  carries comment-based help, validated parameters in place of the original
  hardcoded organisation/subscription/token/prefix literals, and ShouldProcess
  support on the state-changing ones.

  Prerequisites depend on the function used: the Az PowerShell modules and an
  authenticated context (Connect-AzAccount) for the Az* helpers, the Azure CLI
  with the azure-devops extension for the DevOps helpers, and the GitHub CLI
  (gh) authenticated for the GitHub helpers.

  Import with:

      Import-Module "$PSScriptRoot/Snippets.psm1" -Force

.NOTES
  Author: Sebastian Gräf
  Repo:   https://github.com/segraef/Scripts
  Version history is tracked in git, not in this header.
#>

#region Initialisation
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/../Write-Log.psm1" -Force
#endregion

#region Functions

function Test-AvmModule {
    <#
    .SYNOPSIS
      Generate the README and run local Pester/validation/deployment tests for AVM modules.

    .DESCRIPTION
      Dot-sources the Set-AVMModule and Test-ModuleLocally tooling from a local
      clone of Azure/bicep-registry-modules, regenerates each module README, then
      executes the requested end-to-end test cases against the given subscription.
      Ensures an Azure context exists and sets the subscription before testing.

    .PARAMETER RepositoryPath
      Path to a local clone of Azure/bicep-registry-modules.

    .PARAMETER Module
      One or more module paths relative to avm/res (for example 'web/site').

    .PARAMETER SubscriptionId
      Azure subscription ID used as the deployment/validation target context.

    .PARAMETER TenantId
      Azure AD tenant ID injected as the TenantId additional token.

    .PARAMETER NamePrefix
      Naming prefix injected as the namePrefix additional token.

    .PARAMETER TestCase
      Test case folder names under tests/e2e to run. Pass 'all' to discover and
      run every test case folder. Defaults to 'all'.

    .PARAMETER Location
      Azure region used for validation/deployment. Defaults to australiaeast.

    .EXAMPLE
      Test-AvmModule -RepositoryPath ~/git/bicep-registry-modules -Module 'web/site' -SubscriptionId $subId -TenantId $tenantId -NamePrefix 'asf3re'
      Regenerates the README for avm/res/web/site and runs all its e2e test cases.

    .OUTPUTS
      None. Emits test progress and results to the log/host.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Module,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SubscriptionId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NamePrefix,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$TestCase = @('all'),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Location = 'australiaeast'
    )

    try {
        if (-not (Get-AzContext)) {
            Write-Log 'No Azure context found. Authenticating.'
            Connect-AzAccount
        }
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }
    catch {
        Write-Log -Message 'Failed to establish Azure context.' -ErrorRecord $_
        throw
    }

    try {
        . "$RepositoryPath/utilities/tools/Set-AVMModule.ps1"
        . "$RepositoryPath/utilities/tools/Test-ModuleLocally.ps1"
    }
    catch {
        Write-Log -Message "Failed to load AVM tooling from '$RepositoryPath'." -ErrorRecord $_
        throw
    }

    foreach ($currentModule in $Module) {
        Write-Log "Generating README for module '$currentModule'."
        try {
            Set-AVMModule -ModuleFolderPath "$RepositoryPath/avm/res/$currentModule" -Recurse
        }
        catch {
            Write-Log -Message "Failed to generate README for '$currentModule'." -ErrorRecord $_
            throw
        }

        $testModuleLocallyInput = @{
            TemplateFilePath = "$RepositoryPath/avm/res/$currentModule/main.bicep"
            PesterTest = $true
            ValidationTest = $true
            DeploymentTest = $true
            ValidateOrDeployParameters = @{
                Location = $Location
                SubscriptionId = $SubscriptionId
                RemoveDeployment = $true
            }
            AdditionalTokens = @{
                namePrefix = $NamePrefix
                TenantId = $TenantId
            }
        }

        $resolvedCases = $TestCase
        if ($TestCase -contains 'all') {
            $resolvedCases = Get-ChildItem -Path "$RepositoryPath/avm/res/$currentModule/tests/e2e" -Directory |
                ForEach-Object { $_.Name }
        }

        foreach ($case in $resolvedCases) {
            Write-Log "Running test case '$case' on module '$currentModule'."
            $testModuleLocallyInput.ModuleTestFilePath = "$RepositoryPath/avm/res/$currentModule/tests/e2e/$case/main.test.bicep"
            try {
                Test-ModuleLocally @testModuleLocallyInput
            }
            catch {
                Write-Log -Message "Test case '$case' on module '$currentModule' failed." -ErrorRecord $_
            }
        }
    }
}

function Add-GitHubIssueToProject {
    <#
    .SYNOPSIS
      Add open issues from matching GitHub repositories to a GitHub project.

    .DESCRIPTION
      Lists repositories in the given owner whose name matches a pattern, collects
      their open issues via the GitHub CLI, and adds each issue to the named
      project. Repositories matching the exclude pattern are skipped.

    .PARAMETER Owner
      GitHub owner/organisation to list repositories from.

    .PARAMETER RepositoryFilter
      Substring used to select repositories by name (for example 'terraform-azurerm-avm').

    .PARAMETER Project
      Title of the GitHub project to add the issues to.

    .PARAMETER ExcludeRepository
      Repository name to skip (for example a template repo). Optional.

    .PARAMETER RepositoryLimit
      Maximum number of repositories to fetch from the owner. Defaults to 5000.

    .EXAMPLE
      Add-GitHubIssueToProject -Owner Azure -RepositoryFilter 'terraform-azurerm-avm' -Project 'AVM - Module Issues' -ExcludeRepository 'terraform-azurerm-avm-template'
      Adds every open issue from matching repos to the project, skipping the template repo.

    .OUTPUTS
      None. Adds issues to the project as a side effect.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Owner,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryFilter,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [string]$ExcludeRepository,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$RepositoryLimit = 5000
    )

    try {
        $repos = gh repo list $Owner -L $RepositoryLimit --json name --jq '.[].name' |
            Select-String -Pattern $RepositoryFilter |
            ForEach-Object { $_.Line }
    }
    catch {
        Write-Log -Message "Failed to list repositories for owner '$Owner'." -ErrorRecord $_
        throw
    }

    Write-Log "Fetching issues for $($repos.Count) repositories."
    foreach ($repo in $repos) {
        if ($ExcludeRepository -and $repo -eq $ExcludeRepository) {
            Write-Log "Skipping excluded repository '$repo'."
            continue
        }

        Write-Log "Fetching issues for '$repo'."
        try {
            $issues = gh issue list -R "$Owner/$repo" --json 'number,title,url' | ConvertFrom-Json
        }
        catch {
            Write-Log -Message "Failed to list issues for '$repo'." -ErrorRecord $_
            continue
        }

        foreach ($issue in $issues) {
            if ($PSCmdlet.ShouldProcess($issue.url, "Add to project '$Project'")) {
                Write-Log "Adding issue '$($issue.title)' from '$repo' to project '$Project'."
                try {
                    gh issue edit $issue.url --add-project $Project
                }
                catch {
                    Write-Log -Message "Failed to add issue '$($issue.url)' to project '$Project'." -ErrorRecord $_
                }
            }
        }
    }
}

function Add-AzureDevOpsPullRequest {
    <#
    .SYNOPSIS
      Open a pull request from a source branch across every repository in an Azure DevOps project.

    .DESCRIPTION
      Signs in to Azure DevOps with the supplied PAT, configures the default
      organisation and project, lists all repositories, and creates a pull request
      from the given source branch in each one. Requires the azure-devops Azure CLI
      extension (added if missing).

    .PARAMETER Organization
      Azure DevOps organisation name (the segment in https://dev.azure.com/<org>).

    .PARAMETER Project
      Azure DevOps project name.

    .PARAMETER Token
      Personal access token used to authenticate the Azure CLI to Azure DevOps.

    .PARAMETER SourceBranch
      Source branch to open each pull request from (for example users/segraef/provider-upgrade).

    .EXAMPLE
      Add-AzureDevOpsPullRequest -Organization contoso -Project Modules -Token $pat -SourceBranch 'users/segraef/provider-upgrade'
      Opens a PR from the branch in every repository of the Modules project.

    .OUTPUTS
      None. Creates pull requests as a side effect.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory)]
        [securestring]$Token,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceBranch
    )

    $orgUrl = "https://dev.azure.com/$Organization"
    try {
        az extension add --name azure-devops
        $plainToken = [System.Net.NetworkCredential]::new('', $Token).Password
        $plainToken | az devops login --organization $orgUrl
        az devops configure --defaults organization=$orgUrl project=$Project
        $repos = az repos list | ConvertFrom-Json
    }
    catch {
        Write-Log -Message "Failed to query Azure DevOps repositories for '$Project'." -ErrorRecord $_
        throw
    }

    foreach ($repo in $repos) {
        if ($PSCmdlet.ShouldProcess($repo.name, "Create pull request from '$SourceBranch'")) {
            Write-Log "Creating pull request in '$($repo.name)'."
            try {
                az repos pr create --repository $repo.name --source-branch $SourceBranch --open --output table
            }
            catch {
                Write-Log -Message "Failed to create pull request in '$($repo.name)'." -ErrorRecord $_
            }
        }
    }
}

function Remove-GoneGitBranch {
    <#
    .SYNOPSIS
      Prune local git branches whose upstream is gone across nested repositories.

    .DESCRIPTION
      Walks each git repository under the given root, fetches and prunes remote
      tracking references, then deletes local branches whose upstream has been
      removed (marked ': gone]' by git branch -vv). Returns to the starting
      directory when finished.

    .PARAMETER Path
      Root directory whose subdirectories are treated as repositories. Defaults to
      the current location.

    .EXAMPLE
      Remove-GoneGitBranch -Path ~/git/work
      Prunes stale local branches in every repository found under the work folder.

    .OUTPUTS
      None. Deletes local branches as a side effect.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path = (Get-Location).Path
    )

    $origin = (Get-Location).Path
    try {
        $repos = Get-ChildItem -Path $Path -Directory -Recurse
        foreach ($repo in $repos) {
            Write-Log "Processing repository '$($repo.FullName)'."
            Set-Location $repo.FullName
            try {
                git checkout main
                git pull
                git remote update origin --prune
                $goneBranches = git branch -vv |
                    Select-String -Pattern ': gone]' |
                    ForEach-Object { $_.ToString().Trim().Split(' ')[0] }

                foreach ($branch in $goneBranches) {
                    if ($PSCmdlet.ShouldProcess("$($repo.FullName):$branch", 'Delete local branch')) {
                        git branch -D $branch
                    }
                }
            }
            catch {
                Write-Log -Message "Failed to prune branches in '$($repo.FullName)'." -ErrorRecord $_
            }
        }
    }
    finally {
        Set-Location $origin
    }
}

function New-GitFeatureBranch {
    <#
    .SYNOPSIS
      Create, push and commit a feature branch across nested repositories.

    .DESCRIPTION
      For each repository directory under the given root, creates the named branch,
      pushes it with upstream tracking, stages all changes, commits them with the
      supplied message and pushes the commit. Returns to the starting directory
      when finished.

    .PARAMETER Path
      Root directory whose subdirectories are treated as repositories. Defaults to
      the current directory.

    .PARAMETER BranchName
      Name of the branch to create (for example users/segraef/provider-upgrade).

    .PARAMETER CommitMessage
      Commit message used for the staged changes. Defaults to 'provider upgrade'.

    .EXAMPLE
      New-GitFeatureBranch -Path . -BranchName 'users/segraef/provider-upgrade' -CommitMessage 'provider upgrade'
      Creates and pushes the branch in every repository under the current folder.

    .OUTPUTS
      None. Creates branches and commits as a side effect.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path = '.',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BranchName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CommitMessage = 'provider upgrade'
    )

    $origin = (Get-Location).Path
    try {
        $repos = Get-ChildItem -Path $Path -Directory
        foreach ($repo in $repos) {
            if ($PSCmdlet.ShouldProcess($repo.FullName, "Create and push branch '$BranchName'")) {
                Write-Log "Creating branch '$BranchName' in '$($repo.FullName)'."
                Set-Location $repo.FullName
                try {
                    git checkout -b $BranchName
                    git push --set-upstream origin $BranchName
                    git add .
                    git commit -m $CommitMessage
                    git push
                }
                catch {
                    Write-Log -Message "Failed to create/push branch in '$($repo.FullName)'." -ErrorRecord $_
                }
            }
        }
    }
    finally {
        Set-Location $origin
    }
}

function New-BuildValidationPolicy {
    <#
    .SYNOPSIS
      Create or update build validation branch policies for Azure DevOps repositories.

    .DESCRIPTION
      Enumerates repositories, pipelines and existing policy configurations in each
      Azure DevOps project (resolved via REST using the supplied PAT), then creates
      or updates an optional, manually triggered build validation policy on the
      target branch for every repository whose name matches a pipeline. If no
      projects are supplied, all projects in the organisation are processed.

    .PARAMETER Organization
      Azure DevOps organisation name.

    .PARAMETER Token
      Personal access token used for REST and Azure CLI calls.

    .PARAMETER Project
      One or more project names to process. When omitted, all projects are discovered.

    .PARAMETER Branch
      Target branch the policy applies to. Defaults to main.

    .PARAMETER ApiVersion
      Azure DevOps REST API version. Defaults to 6.0.

    .EXAMPLE
      New-BuildValidationPolicy -Organization contoso -Token $pat -Project 'Modules'
      Creates or updates build validation policies for the Modules project.

    .OUTPUTS
      None. Creates or updates branch policies as a side effect.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [securestring]$Token,

        [Parameter()]
        [string[]]$Project,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Branch = 'main',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ApiVersion = '6.0'
    )

    $plainToken = [System.Net.NetworkCredential]::new('', $Token).Password
    $env:AZURE_DEVOPS_EXT_PAT = $plainToken
    $authHeader = @{
        Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$plainToken"))
    }

    function Invoke-AdoCollection {
        param
        (
            [Parameter(Mandatory)]
            [string]$Uri
        )
        $encoded = $Uri -replace ' ', '%20'
        (Invoke-RestMethod -Uri $encoded -Headers $authHeader).value
    }

    try {
        if (-not $Project) {
            Write-Log 'No project supplied; discovering all projects.'
            $projectNames = (Invoke-AdoCollection -Uri "https://dev.azure.com/$Organization/_apis/projects?api-version=$ApiVersion").name
        }
        else {
            $projectNames = $Project
        }
    }
    catch {
        Write-Log -Message 'Failed to resolve Azure DevOps projects.' -ErrorRecord $_
        throw
    }

    Write-Log "Processing $($projectNames.Count) project(s)."
    foreach ($projectName in $projectNames) {
        try {
            $repos = Invoke-AdoCollection -Uri "https://dev.azure.com/$Organization/$projectName/_apis/git/repositories?api-version=$ApiVersion"
            $pipelines = Invoke-AdoCollection -Uri "https://dev.azure.com/$Organization/$projectName/_apis/pipelines?api-version=$ApiVersion"
            $buildPolicies = Invoke-AdoCollection -Uri "https://dev.azure.com/$Organization/$projectName/_apis/policy/configurations?api-version=$ApiVersion"
        }
        catch {
            Write-Log -Message "Failed to read configuration for project '$projectName'." -ErrorRecord $_
            continue
        }

        Write-Log "Project '$projectName': $($repos.Count) repos, $($pipelines.Count) pipelines, $($buildPolicies.Count) policies."
        foreach ($repo in $repos) {
            $buildDefinition = $pipelines | Where-Object { $_.name -eq $repo.name }
            if (-not $buildDefinition) {
                Write-Log "No matching pipeline for repository '$($repo.name)'; skipping." -Level Verbose
                continue
            }

            $matchingPolicy = $buildPolicies | Where-Object { $_.settings.buildDefinitionId -eq $buildDefinition.id }
            if ($matchingPolicy) {
                if ($PSCmdlet.ShouldProcess($repo.name, 'Update build validation policy')) {
                    Write-Log "Updating build validation policy for '$($repo.name)' using pipeline '$($buildDefinition.name)'."
                    try {
                        az repos policy build update `
                            --id $matchingPolicy.id `
                            --blocking $false `
                            --branch $Branch `
                            --build-definition-id $buildDefinition.id `
                            --display-name $repo.name `
                            --enabled $true `
                            --manual-queue-only $false `
                            --queue-on-source-update-only $false `
                            --repository-id $repo.id `
                            --valid-duration 0 `
                            --project $projectName
                    }
                    catch {
                        Write-Log -Message "Failed to update policy for '$($repo.name)'." -ErrorRecord $_
                    }
                }
            }
            else {
                if ($PSCmdlet.ShouldProcess($repo.name, 'Create build validation policy')) {
                    Write-Log "Creating build validation policy for '$($repo.name)' using pipeline '$($buildDefinition.name)'."
                    try {
                        az repos policy build create `
                            --blocking $false `
                            --branch $Branch `
                            --build-definition-id $buildDefinition.id `
                            --display-name $repo.name `
                            --enabled $true `
                            --manual-queue-only $false `
                            --queue-on-source-update-only $false `
                            --repository-id $repo.id `
                            --valid-duration 0 `
                            --project $projectName
                    }
                    catch {
                        Write-Log -Message "Failed to create policy for '$($repo.name)'." -ErrorRecord $_
                    }
                }
            }
        }
    }
}

function New-AzServicePrincipalAssignment {
    <#
    .SYNOPSIS
      Create an Azure AD service principal and assign it a role at a scope.

    .DESCRIPTION
      Creates a service principal with a generated display name and grants it the
      requested role definition at the supplied scope using the Az PowerShell
      modules. Requires an authenticated Azure context.

    .PARAMETER SubscriptionId
      Subscription ID used to build the default scope when Scope is not supplied.

    .PARAMETER Role
      Role definition name to assign. Defaults to Contributor.

    .PARAMETER Scope
      Assignment scope. Defaults to the supplied subscription.

    .PARAMETER DisplayName
      Service principal display name. Defaults to a generated '<random>-sp' value.

    .EXAMPLE
      New-AzServicePrincipalAssignment -SubscriptionId $subId -Role Reader
      Creates a service principal and grants it Reader on the subscription.

    .OUTPUTS
      The created role assignment object.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SubscriptionId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Role = 'Contributor',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Scope = "/subscriptions/$SubscriptionId",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName = "$(Get-Random -Minimum 100000 -Maximum 999999)-sp"
    )

    if ($PSCmdlet.ShouldProcess($Scope, "Create service principal '$DisplayName' with role '$Role'")) {
        try {
            $sp = New-AzADServicePrincipal -DisplayName $DisplayName
            New-AzRoleAssignment -RoleDefinitionName $Role -ServicePrincipalName $sp.AppId -Scope $Scope
        }
        catch {
            Write-Log -Message "Failed to create service principal or role assignment at '$Scope'." -ErrorRecord $_
            throw
        }
    }
}

function Remove-ItemByPrefix {
    <#
    .SYNOPSIS
      Recursively remove files or folders matching a name prefix.

    .DESCRIPTION
      Finds items (including hidden ones) whose name matches the given prefix
      pattern under the current location and removes them recursively. Honours
      -WhatIf/-Confirm via ShouldProcess.

    .PARAMETER Prefix
      Name pattern to match (for example '.pre*' or '.git').

    .PARAMETER ExcludeHidden
      Exclude hidden items from the search. By default hidden items are included
      (matching the original snippet behaviour).

    .EXAMPLE
      Remove-ItemByPrefix -Prefix '.pre*'
      Removes every item whose name starts with '.pre' beneath the current folder.

    .OUTPUTS
      None. Deletes items as a side effect.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Prefix,

        [Parameter()]
        [switch]$ExcludeHidden
    )

    try {
        $items = Get-ChildItem -Path $Prefix -Recurse -Hidden:(-not $ExcludeHidden)
    }
    catch {
        Write-Log -Message "Failed to enumerate items matching '$Prefix'." -ErrorRecord $_
        throw
    }

    foreach ($item in $items) {
        if ($PSCmdlet.ShouldProcess($item.FullName, 'Remove item')) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force
            }
            catch {
                Write-Log -Message "Failed to remove '$($item.FullName)'." -ErrorRecord $_
            }
        }
    }
}

function ConvertTo-TerraformModuleName {
    <#
    .SYNOPSIS
      Convert child item names to dash-separated terraform-azurerm module names.

    .DESCRIPTION
      Reads the immediate child items of the given path, lower-cases each base name
      and inserts a dash before each upper-case letter, then emits a quoted
      'terraform-azurerm<name>' string per item. Useful for generating module name
      lists.

    .PARAMETER Path
      Directory whose child items are converted. Defaults to the current directory.

    .EXAMPLE
      ConvertTo-TerraformModuleName -Path .
      Emits a quoted terraform-azurerm module name for each child item.

    .OUTPUTS
      System.String. One quoted module name per child item.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path = '.'
    )

    try {
        $names = Get-ChildItem -Path $Path
    }
    catch {
        Write-Log -Message "Failed to enumerate items under '$Path'." -ErrorRecord $_
        throw
    }

    foreach ($name in $names) {
        $converted = ($name.BaseName -replace '(?-i)[A-Z]', '-$&').ToLower()
        Write-Output """terraform-azurerm$converted"","
    }
}

function Export-AzProviderReadAction {
    <#
    .SYNOPSIS
      Export all Azure provider read operations to a CSV file.

    .DESCRIPTION
      Queries the full set of Azure provider operations, filters to those whose
      operation name contains 'read', and exports the operation names to a CSV
      file. Requires an authenticated Azure context.

    .PARAMETER Path
      Output CSV path. Defaults to Get-AllActions.csv in the current directory.

    .EXAMPLE
      Export-AzProviderReadAction -Path ./read-actions.csv
      Writes every read operation to read-actions.csv.

    .OUTPUTS
      None. Writes a CSV file as a side effect.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path = 'Get-AllActions.csv'
    )

    if ($PSCmdlet.ShouldProcess($Path, 'Export provider read actions')) {
        try {
            Get-AzProviderOperation -OperationSearchString '*' |
                Where-Object { $_.Operation -like '*read*' } |
                Select-Object Operation |
                Export-Csv -Path $Path -NoTypeInformation -Force
        }
        catch {
            Write-Log -Message "Failed to export provider read actions to '$Path'." -ErrorRecord $_
            throw
        }
    }
}

function Get-RBACDetails {
    <#
    .SYNOPSIS
      Collect RBAC role assignments for a management group hierarchy or a single scope.

    .DESCRIPTION
      With -ManagementGroup, recursively walks the management group, its
      subscriptions and their resource groups, attaching role assignments to each
      node, and optionally exports the result to CSV. With -Scope, returns a flat
      list of role assignments for that single scope. Requires an authenticated
      Azure context.

    .PARAMETER ManagementGroup
      Management group name to walk recursively (hierarchy mode).

    .PARAMETER Scope
      A single resource scope to query (flat mode).

    .PARAMETER CsvPath
      Optional CSV output path used in hierarchy mode.

    .EXAMPLE
      Get-RBACDetails -ManagementGroup root -CsvPath ./rbac.csv
      Walks the root management group hierarchy and writes the result to rbac.csv.

    .EXAMPLE
      Get-RBACDetails -Scope '/subscriptions/<id>'
      Returns the role assignments at the given subscription scope.

    .OUTPUTS
      System.Object[]. The collected RBAC detail objects.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ManagementGroup', SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = 'RBACDetails is the established name of this collection helper.')]
    param
    (
        [Parameter(Mandatory, ParameterSetName = 'ManagementGroup')]
        [ValidateNotNullOrEmpty()]
        [string]$ManagementGroup,

        [Parameter(Mandatory, ParameterSetName = 'Scope')]
        [ValidateNotNullOrEmpty()]
        [string]$Scope,

        [Parameter(ParameterSetName = 'ManagementGroup')]
        [ValidateNotNullOrEmpty()]
        [string]$CsvPath
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq 'Scope') {
            $roleAssignments = Get-AzRoleAssignment -Scope $Scope
            return $roleAssignments | ForEach-Object {
                [PSCustomObject]@{
                    Scope = $_.Scope
                    RoleDefinitionName = $_.RoleDefinitionName
                    PrincipalType = $_.PrincipalType
                    PrincipalId = $_.PrincipalId
                    ObjectId = $_.ObjectId
                    ObjectType = $_.ObjectType
                    CanDelegate = $_.CanDelegate
                }
            }
        }

        $rbacDetails = @()
        $mgInfo = Get-AzManagementGroup -GroupName $ManagementGroup
        $mgRbac = Get-AzManagementGroupRoleAssignment -GroupId $ManagementGroup
        $mgInfo | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'Management Group' -Force
        $mgInfo | Add-Member -MemberType NoteProperty -Name 'RoleAssignment' -Value $mgRbac -Force
        $rbacDetails += $mgInfo

        $subscriptions = Get-AzManagementGroupSubscriptions -GroupId $ManagementGroup
        foreach ($subscription in $subscriptions) {
            $subRbac = Get-AzRoleAssignment -Scope $subscription.Id
            $subscription | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'Subscription' -Force
            $subscription | Add-Member -MemberType NoteProperty -Name 'RoleAssignment' -Value $subRbac -Force
            $rbacDetails += $subscription

            $resourceGroups = Get-AzResourceGroup -SubscriptionId $subscription.Id
            foreach ($resourceGroup in $resourceGroups) {
                $rgInfo = Get-AzResourceGroup -Name $resourceGroup.ResourceGroupName
                $rgRbac = Get-AzRoleAssignment -Scope $resourceGroup.ResourceId
                $rgInfo | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'Resource Group' -Force
                $rgInfo | Add-Member -MemberType NoteProperty -Name 'RoleAssignment' -Value $rgRbac -Force
                $rbacDetails += $rgInfo
            }
        }
    }
    catch {
        Write-Log -Message 'Failed to collect RBAC details.' -ErrorRecord $_
        throw
    }

    if ($CsvPath) {
        if ($PSCmdlet.ShouldProcess($CsvPath, 'Export RBAC details to CSV')) {
            try {
                $rbacDetails | Export-Csv -Path $CsvPath -NoTypeInformation
            }
            catch {
                Write-Log -Message "Failed to export RBAC details to '$CsvPath'." -ErrorRecord $_
                throw
            }
        }
    }

    Write-Output $rbacDetails
}

function Get-RBACHierarchy {
    <#
    .SYNOPSIS
      Print the RBAC hierarchy from a management group down to its resource groups.

    .DESCRIPTION
      Walks a management group, its subscriptions and their resource groups,
      logging each node and its role assignments (role name plus assignee). A
      human-readable companion to Get-RBACDetails. Requires an authenticated Azure
      context.

    .PARAMETER ManagementGroupId
      Management group ID to start from (for example 'root').

    .EXAMPLE
      Get-RBACHierarchy -ManagementGroupId root
      Logs the role assignments across the root management group hierarchy.

    .OUTPUTS
      None. Writes the hierarchy to the log/host.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManagementGroupId
    )

    try {
        $mgInfo = Get-AzManagementGroup -GroupId $ManagementGroupId
        $mgRbac = Get-AzRoleAssignment -Scope "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"

        Write-Log "Management Group: $($mgInfo.DisplayName)"
        foreach ($role in $mgRbac) {
            Write-Log "  Role: $($role.RoleDefinitionName) - Assigned to: $($role.SignInName)"
        }

        $subscriptions = Get-AzSubscription -ManagementGroup $ManagementGroupId
        foreach ($subscription in $subscriptions) {
            Write-Log "  Subscription: $($subscription.Name)"
            $subRbac = Get-AzRoleAssignment -Scope $subscription.Id
            foreach ($role in $subRbac) {
                Write-Log "    Role: $($role.RoleDefinitionName) - Assigned to: $($role.SignInName)"
            }

            $resourceGroups = Get-AzResourceGroup -SubscriptionId $subscription.Id
            foreach ($rg in $resourceGroups) {
                Write-Log "    Resource Group: $($rg.ResourceGroupName)"
                $rgRbac = Get-AzRoleAssignment -ResourceGroupName $rg.ResourceGroupName
                foreach ($role in $rgRbac) {
                    Write-Log "      Role: $($role.RoleDefinitionName) - Assigned to: $($role.SignInName)"
                }
            }
        }
    }
    catch {
        Write-Log -Message "Failed to walk RBAC hierarchy for '$ManagementGroupId'." -ErrorRecord $_
        throw
    }
}

function Invoke-AzureDevOpsRest {
    <#
    .SYNOPSIS
      Patch every repository in an Azure DevOps project via the REST API.

    .DESCRIPTION
      Configures the Azure CLI defaults, lists the repositories in the given
      project, and sends a PATCH request to each repository's Git API with the
      supplied JSON body (default re-enables the repository). Authentication uses
      basic auth built from the supplied PAT.

    .PARAMETER Organization
      Azure DevOps organisation name.

    .PARAMETER Project
      Azure DevOps project name.

    .PARAMETER Token
      Personal access token used for basic authentication.

    .PARAMETER Body
      JSON body sent with each PATCH request. Defaults to '{ "isDisabled" : "false" }'.

    .PARAMETER ApiVersion
      Azure DevOps REST API version. Defaults to 6.0.

    .EXAMPLE
      Invoke-AzureDevOpsRest -Organization contoso -Project Modules -Token $pat
      Re-enables every repository in the Modules project.

    .OUTPUTS
      The REST responses from each repository PATCH.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory)]
        [securestring]$Token,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Body = '{ "isDisabled" : "false" }',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ApiVersion = '6.0'
    )

    $orgUrl = "https://dev.azure.com/$Organization"
    $plainToken = [System.Net.NetworkCredential]::new('', $Token).Password
    $authHeader = @{
        Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$plainToken"))
    }

    try {
        az devops configure --defaults organization=$orgUrl project=$Project
        $repos = az repos list | ConvertFrom-Json
    }
    catch {
        Write-Log -Message "Failed to list repositories for project '$Project'." -ErrorRecord $_
        throw
    }

    foreach ($repo in $repos) {
        $uri = "$orgUrl/$Project/_apis/git/repositories/$($repo.id)?api-version=$ApiVersion"
        if ($PSCmdlet.ShouldProcess($repo.name, 'Patch repository')) {
            Write-Log "Patching repository '$($repo.name)'."
            try {
                Invoke-RestMethod -Uri $uri -Method Patch -Body $Body -ContentType 'application/json' -Headers $authHeader
            }
            catch {
                Write-Log -Message "Failed to patch repository '$($repo.name)'." -ErrorRecord $_
            }
        }
    }
}

function Approve-GitHubPullRequest {
    <#
    .SYNOPSIS
      Approve matching pull requests across GitHub repositories.

    .DESCRIPTION
      Lists repositories in the given owner whose name matches a filter, collects
      their open pull requests via the GitHub CLI, and approves every PR whose
      title matches the supplied title using gh pr review. Optionally adds a review
      body.

    .PARAMETER Owner
      GitHub owner/organisation to list repositories from.

    .PARAMETER RepositoryFilter
      Substring used to select repositories by name.

    .PARAMETER TitleMatch
      Exact pull request title to approve.

    .PARAMETER ReviewBody
      Optional review comment body. Defaults to a check-before-merge reminder.

    .PARAMETER RepositoryLimit
      Maximum number of repositories to fetch. Defaults to 5000.

    .EXAMPLE
      Approve-GitHubPullRequest -Owner Azure -RepositoryFilter 'terraform-azurerm-avm' -TitleMatch 'chore: repository governance'
      Approves every matching governance PR across the selected repositories.

    .OUTPUTS
      None. Submits PR reviews as a side effect.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Owner,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryFilter,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TitleMatch,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ReviewBody = 'Please ensure all checks pass before merging.',

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$RepositoryLimit = 5000
    )

    try {
        $repos = gh repo list $Owner -L $RepositoryLimit --json name --jq '.[].name' |
            Select-String -Pattern $RepositoryFilter |
            ForEach-Object { $_.Line }
    }
    catch {
        Write-Log -Message "Failed to list repositories for owner '$Owner'." -ErrorRecord $_
        throw
    }

    Write-Log "Fetching pull requests for $($repos.Count) repositories."
    foreach ($repo in $repos) {
        try {
            $prs = gh pr list -R "$Owner/$repo" --json 'number,title,url' | ConvertFrom-Json
        }
        catch {
            Write-Log -Message "Failed to list pull requests for '$repo'." -ErrorRecord $_
            continue
        }

        foreach ($pr in $prs | Where-Object { $_.title -eq $TitleMatch }) {
            if ($PSCmdlet.ShouldProcess("$repo#$($pr.number)", 'Approve pull request')) {
                Write-Log "Approving PR '$($pr.title)' on repository '$repo'."
                try {
                    gh pr review $pr.number -R "$Owner/$repo" --approve --body $ReviewBody
                }
                catch {
                    Write-Log -Message "Failed to approve PR '$($pr.url)'." -ErrorRecord $_
                }
            }
        }
    }
}

function Rename-ItemByPattern {
    <#
    .SYNOPSIS
      Recursively rename items by replacing a substring in their names.

    .DESCRIPTION
      Finds items under the given prefix path and renames each one, replacing the
      old pattern with the new value in the item name. Honours -WhatIf/-Confirm via
      ShouldProcess.

    .PARAMETER Prefix
      Path or name prefix to enumerate (for example '.terraform').

    .PARAMETER OldValue
      Substring to replace in each item name.

    .PARAMETER NewValue
      Replacement substring.

    .EXAMPLE
      Rename-ItemByPattern -Prefix '.terraform' -OldValue 'eus' -NewValue 'ae'
      Renames matching items, swapping 'eus' for 'ae' in their names.

    .OUTPUTS
      None. Renames items as a side effect.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Prefix,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OldValue,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NewValue
    )

    try {
        $items = Get-ChildItem -Path $Prefix -Recurse
    }
    catch {
        Write-Log -Message "Failed to enumerate items matching '$Prefix'." -ErrorRecord $_
        throw
    }

    foreach ($item in $items) {
        $newName = $item.Name -replace $OldValue, $NewValue
        if ($newName -eq $item.Name) {
            continue
        }
        if ($PSCmdlet.ShouldProcess($item.FullName, "Rename to '$newName'")) {
            try {
                Rename-Item -Path $item.FullName -NewName $newName
            }
            catch {
                Write-Log -Message "Failed to rename '$($item.FullName)'." -ErrorRecord $_
            }
        }
    }
}

function Start-AzJitAccess {
    <#
    .SYNOPSIS
      Request just-in-time network access to a virtual machine.

    .DESCRIPTION
      Resolves the caller's public IP, builds a JIT network access request for the
      given VM and port, and invokes Start-AzJitNetworkAccessPolicy against the
      named JIT policy for the requested duration. Requires an authenticated Azure
      context with Microsoft Defender for Cloud JIT enabled on the VM.

    .PARAMETER VirtualMachineId
      Full resource ID of the target virtual machine.

    .PARAMETER JitPolicyResourceId
      Full resource ID of the jitNetworkAccessPolicies/default policy for the VM's region.

    .PARAMETER Port
      Port to open. Defaults to 3389 (RDP).

    .PARAMETER DurationHours
      How long access stays open, in hours. Defaults to 4.8 (0.2 days).

    .PARAMETER SourceAddress
      Allowed source address prefix. Defaults to the caller's public IP.

    .EXAMPLE
      Start-AzJitAccess -VirtualMachineId $vmId -JitPolicyResourceId $jitId -Port 22
      Opens SSH from the caller's IP to the VM for the default duration.

    .OUTPUTS
      The JIT network access policy result object.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$VirtualMachineId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$JitPolicyResourceId,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port = 3389,

        [Parameter()]
        [ValidateRange(0.1, 24)]
        [double]$DurationHours = 4.8,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SourceAddress
    )

    try {
        if (-not $SourceAddress) {
            $SourceAddress = (Invoke-WebRequest -Uri 'http://ifconfig.me/ip').Content
        }
        $endTime = (Get-Date).AddHours($DurationHours)
        $jitPolicy = @(
            @{
                id = $VirtualMachineId
                ports = @(
                    @{
                        number = $Port
                        endTimeUtc = "$endTime"
                        allowedSourceAddressPrefix = @("$SourceAddress")
                    }
                )
            }
        )
    }
    catch {
        Write-Log -Message 'Failed to build JIT access request.' -ErrorRecord $_
        throw
    }

    if ($PSCmdlet.ShouldProcess($VirtualMachineId, "Request JIT access on port $Port")) {
        try {
            Start-AzJitNetworkAccessPolicy -ResourceId $JitPolicyResourceId -VirtualMachine $jitPolicy
        }
        catch {
            Write-Log -Message "Failed to request JIT access for '$VirtualMachineId'." -ErrorRecord $_
            throw
        }
    }
}

#endregion

#region Execution
Export-ModuleMember -Function @(
    'Test-AvmModule',
    'Add-GitHubIssueToProject',
    'Add-AzureDevOpsPullRequest',
    'Remove-GoneGitBranch',
    'New-GitFeatureBranch',
    'New-BuildValidationPolicy',
    'New-AzServicePrincipalAssignment',
    'Remove-ItemByPrefix',
    'ConvertTo-TerraformModuleName',
    'Export-AzProviderReadAction',
    'Get-RBACDetails',
    'Get-RBACHierarchy',
    'Invoke-AzureDevOpsRest',
    'Approve-GitHubPullRequest',
    'Rename-ItemByPattern',
    'Start-AzJitAccess'
)
#endregion
