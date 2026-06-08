#Requires -Version 7.0

<#
.SYNOPSIS
  Create Azure Pipelines and Pull Request Build Validation checks.

.DESCRIPTION
  Logs in to Azure DevOps with a Personal Access Token, discovers every
  'pipeline.yml' file under a source path, and creates an Azure Pipeline for
  each one whose name does not already exist in the target folder. Optionally
  creates a branch Build Validation policy for each new pipeline.

  When run inside an Azure Pipeline, set the AZURE_DEVOPS_EXT_PAT environment
  variable to $(System.AccessToken); az devops login consumes it because tty is
  not available in a pipeline run.

  Prerequisites:
    - Azure CLI 2.13.0 or later.
    - Azure CLI 'azure-devops' extension 0.18.0 or later (auto-installed).
    - A repository for which the pipeline needs to be configured.
    - The '<ProjectName>' Build Service must have 'Edit build pipeline'
      permission. See
      https://learn.microsoft.com/azure/devops/pipelines/policies/permissions

.PARAMETER OrganizationName
  Required. The name of the Azure DevOps organization.

.PARAMETER ProjectName
  Required. The name of the Azure DevOps project.

.PARAMETER RepositoryName
  Required. Repository for which the pipeline needs to be configured.

.PARAMETER PAT
  Required. The access token with appropriate permissions to create Azure
  Pipelines, supplied as a SecureString. The System.AccessToken from an Azure
  Pipeline run usually has sufficient permissions. See
  https://learn.microsoft.com/azure/devops/pipelines/process/access-tokens

.PARAMETER BranchName
  Optional. Branch name for which the pipelines will be configured.
  Default: 'main'.

.PARAMETER PipelineTargetPath
  Optional. Path of the folder where the pipeline needs to be created.

.PARAMETER PipelineSourcePath
  Optional. Path of the pipeline YAML file(s) used for creating Azure Pipelines.
  All 'pipeline.yml' files under the given folder are searched and created
  accordingly. Default is the current execution path.

.PARAMETER CreateBuildValidation
  Optional. Also create a Pull Request Build Validation policy for each new
  pipeline.

.INPUTS
  None. This script does not accept pipeline input.

.OUTPUTS
  None. Creates Azure Pipelines and (optionally) Build Validation policies as a
  side effect.

.EXAMPLE
  $pat = Read-Host -AsSecureString
  ./New-AzPipeline.ps1 -OrganizationName graef.io -ProjectName Project1 -RepositoryName Repository1 -PAT $pat

  Create all pipelines for the project 'graef.io/Project1' using a PAT. The
  pipelines are configured to use the default branch 'main' and the given
  repository. Each 'pipeline.yml' under the source path produces one Azure
  Pipeline named after its parent folder.

.NOTES
  Author: Sebastian Gräf
  Repo:   https://github.com/segraef/Scripts
  Version history is tracked in git, not in this header.
#>

[CmdletBinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory, HelpMessage = 'Azure DevOps Organization: <OrganizationName>')]
    [ValidateNotNullOrEmpty()]
    [string]$OrganizationName,

    [Parameter(Mandatory, HelpMessage = 'Azure DevOps Project: <ProjectName>')]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectName,

    [Parameter(Mandatory, HelpMessage = 'Azure DevOps Repository: <RepositoryName>')]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryName,

    [Parameter(Mandatory, HelpMessage = 'Azure DevOps Personal Access Token: <PAT>')]
    [ValidateNotNull()]
    [securestring]$PAT,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$BranchName = 'main',

    [Parameter()]
    [string]$PipelineTargetPath,

    [Parameter()]
    [string]$PipelineSourcePath,

    [Parameter()]
    [switch]$CreateBuildValidation
)

#region Initialisation
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Write-Log.psm1" -Force
#endregion

#region Functions
function Connect-AzDevOpsCli {
    <#
    .SYNOPSIS
      Install the Azure DevOps CLI extension and log in with a PAT.

    .DESCRIPTION
      Ensures dynamic extension install is enabled, adds/upgrades the
      azure-devops extension, verifies the CLI is available, logs in using the
      supplied PAT via the AZURE_DEVOPS_EXT_PAT environment variable, and sets
      the default organization and project.

    .PARAMETER OrganizationUrl
      The full Azure DevOps organization URL (https://dev.azure.com/<org>/).

    .PARAMETER ProjectName
      The Azure DevOps project name to set as the default.

    .PARAMETER PAT
      The Personal Access Token as a SecureString.

    .EXAMPLE
      Connect-AzDevOpsCli -OrganizationUrl 'https://dev.azure.com/graef.io/' -ProjectName Project1 -PAT $pat
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OrganizationUrl,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [securestring]$PAT
    )

    Write-Log 'Installing Azure CLI extension devops.'
    az config set extension.use_dynamic_install=yes_without_prompt  # allow installing extensions without prompt
    az extension add --upgrade -n azure-devops

    Write-Log 'Checking availability of Azure CLI and the Azure DevOps CLI extension.'
    az | Out-Null
    az devops -h | Out-Null

    Write-Log "Logging in to Azure DevOps project at $OrganizationUrl$ProjectName with a PAT."
    $plainPat = [System.Net.NetworkCredential]::new('', $PAT).Password
    $env:AZURE_DEVOPS_EXT_PAT = $plainPat
    Write-Output $plainPat | az devops login

    Write-Log "Setting default Azure DevOps configuration to $OrganizationUrl and $ProjectName."
    az devops configure --defaults organization="$OrganizationUrl" project="$ProjectName" --use-git-aliases true
}

function Get-ExistingAzPipeline {
    <#
    .SYNOPSIS
      List existing Azure Pipelines in the target folder.

    .DESCRIPTION
      Queries Azure DevOps for the pipelines that already exist under the target
      folder so they can be skipped during creation.

    .PARAMETER OrganizationUrl
      The full Azure DevOps organization URL.

    .PARAMETER ProjectName
      The Azure DevOps project name.

    .PARAMETER PipelineTargetPath
      The folder path under which to list pipelines.

    .EXAMPLE
      Get-ExistingAzPipeline -OrganizationUrl $url -ProjectName Project1 -PipelineTargetPath '/'
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OrganizationUrl,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectName,

        [Parameter()]
        [string]$PipelineTargetPath
    )

    Write-Log "Listing all Azure Pipelines in $PipelineTargetPath."
    $azurePipelines = az pipelines list --organization $OrganizationUrl --project $ProjectName --folder-path $PipelineTargetPath |
        ConvertFrom-Json |
        Sort-Object name
    Write-Log "Found $($azurePipelines.Count) Azure Pipeline(s) in $ProjectName."

    Write-Output $azurePipelines
}

function Get-YamlPipelineDefinition {
    <#
    .SYNOPSIS
      Discover 'pipeline.yml' files and build pipeline definition objects.

    .DESCRIPTION
      Recursively searches the source path for 'pipeline.yml' files and, for
      each one, builds a PSCustomObject describing the pipeline to create
      (project, repository, branch, folder, relative YAML path, and the name
      derived from the parent folder).

    .PARAMETER PipelineSourcePath
      The folder under which to search for 'pipeline.yml' files. Resolved
      relative to the current location.

    .PARAMETER ProjectName
      The Azure DevOps project name.

    .PARAMETER RepositoryName
      The repository name for which the pipelines are configured.

    .PARAMETER BranchName
      The branch name for which the pipelines are configured.

    .PARAMETER PipelineTargetPath
      The folder path where pipelines are created.

    .EXAMPLE
      Get-YamlPipelineDefinition -PipelineSourcePath './pipelines' -ProjectName P1 -RepositoryName R1 -BranchName main -PipelineTargetPath '/'
    #>
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]$PipelineSourcePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BranchName,

        [Parameter()]
        [string]$PipelineTargetPath
    )

    $sourcePath = if ([string]::IsNullOrWhiteSpace($PipelineSourcePath)) { '.' } else { $PipelineSourcePath }
    $resolvedSourcePath = (Resolve-Path -Path $sourcePath).Path
    Write-Log "Identifying relevant Azure Pipelines under $resolvedSourcePath."
    $ymlPipelines = Get-ChildItem -Path $resolvedSourcePath -Recurse -File -Filter 'pipeline.yml' |
        Sort-Object FullName
    Write-Log "Found $($ymlPipelines.Count) YAML Pipeline(s) in $resolvedSourcePath."

    $pipelinesArray = @()
    foreach ($pipeline in $ymlPipelines) {
        $ymlPath = [IO.Path]::GetRelativePath($resolvedSourcePath, $pipeline.FullName).Replace('\', '/')
        $parentFolderName = Split-Path -Path (Split-Path -Path $pipeline.FullName -Parent) -Leaf
        $pipelineName = $parentFolderName  # used as the pipeline name

        $pipeObj = [PSCustomObject]@{
            ProjectName = $ProjectName
            RepositoryName = $RepositoryName
            BranchName = $BranchName
            FolderPath = $PipelineTargetPath
            ymlPath = $ymlPath
            parentFolderName = $parentFolderName
            pipelineName = $pipelineName
        }

        $pipelinesArray += $pipeObj
    }

    Write-Output $pipelinesArray
}

function New-AzPipelineDefinition {
    <#
    .SYNOPSIS
      Create a single Azure Pipeline and, optionally, its Build Validation.

    .DESCRIPTION
      Creates one Azure Pipeline from a discovered definition object. When
      requested, also creates a branch Build Validation policy scoped to the
      pipeline's path.

    .PARAMETER Pipeline
      The pipeline definition object produced by Get-YamlPipelineDefinition.

    .PARAMETER OrganizationUrl
      The full Azure DevOps organization URL.

    .PARAMETER CreateBuildValidation
      Also create a Pull Request Build Validation policy for the new pipeline.

    .EXAMPLE
      New-AzPipelineDefinition -Pipeline $def -OrganizationUrl $url -CreateBuildValidation
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$Pipeline,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OrganizationUrl,

        [Parameter()]
        [switch]$CreateBuildValidation
    )

    if (-not $PSCmdlet.ShouldProcess($Pipeline.pipelineName, 'Create Azure Pipeline')) {
        return
    }

    Write-Log "Creating Azure pipeline $($Pipeline.pipelineName)."
    $pipelineResult = az pipelines create --project "$($Pipeline.ProjectName)" `
        --organization "$OrganizationUrl" `
        --repository "$($Pipeline.RepositoryName)" `
        --repository-type tfsgit `
        --branch "$($Pipeline.BranchName)" `
        --folder-path "$($Pipeline.FolderPath)" `
        --name "$($Pipeline.pipelineName)" `
        --yml-path "$($Pipeline.ymlPath)" `
        --skip-run
    $pipelineObject = $pipelineResult | ConvertFrom-Json

    if ($CreateBuildValidation) {
        $pathFilter = $Pipeline.ymlPath -replace 'pipeline.yml', '*'
        Write-Log "Configuring branch Build Validation for $($Pipeline.pipelineName)."
        az repos policy build create `
            --blocking true `
            --branch "$($Pipeline.BranchName)" `
            --build-definition-id $pipelineObject.id `
            --display-name "Check $($Pipeline.pipelineName)" `
            --manual-queue-only true `
            --queue-on-source-update-only true `
            --valid-duration 1440 `
            --path-filter $pathFilter `
            --repository-id $pipelineObject.repository.id `
            --enabled true
    }
}
#endregion

#region Execution
Write-Log "Executing $($MyInvocation.MyCommand.Name)."

try {
    $orgUrl = "https://dev.azure.com/$OrganizationName/"

    Connect-AzDevOpsCli -OrganizationUrl $orgUrl -ProjectName $ProjectName -PAT $PAT

    $azurePipelines = Get-ExistingAzPipeline -OrganizationUrl $orgUrl -ProjectName $ProjectName -PipelineTargetPath $PipelineTargetPath

    $pipelinesArray = Get-YamlPipelineDefinition `
        -PipelineSourcePath $PipelineSourcePath `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -BranchName $BranchName `
        -PipelineTargetPath $PipelineTargetPath

    $pipelinesToBeSkipped = $pipelinesArray | Where-Object { $_.pipelineName -in $azurePipelines.name }
    $pipelinesToBeUpdated = $pipelinesArray | Where-Object { $_.pipelineName -notin $azurePipelines.name }

    if ($pipelinesToBeUpdated.Count -eq 0) {
        Write-Log 'No Pipelines have been identified. Exiting.'
        return
    }

    Write-Log "$($pipelinesToBeUpdated.Count) Pipeline(s) have been identified to be updated."
    Write-Log "$($pipelinesToBeSkipped.Count) Pipeline(s) will be skipped."

    foreach ($pipeline in $pipelinesToBeUpdated) {
        New-AzPipelineDefinition -Pipeline $pipeline -OrganizationUrl $orgUrl -CreateBuildValidation:$CreateBuildValidation
    }

    Write-Log "$($pipelinesToBeUpdated.Count) Azure pipeline(s) created!"
    if ($CreateBuildValidation) {
        Write-Log "$($pipelinesToBeUpdated.Count) Pull Request Build Validation(s) created!"
    }
    Write-Log "$($pipelinesToBeSkipped.Count) Azure pipeline(s) skipped!"

    $url = $orgUrl + $ProjectName + '/' + '_build?definitionScope=%5C' + $PipelineTargetPath
    Write-Log "Please check your Azure Pipelines here: $url"
}
catch {
    Write-Log -Message ('Reason: [{0}]' -f $_.Exception.Message) -ErrorRecord $_
    throw
}

Write-Log "Finished $($MyInvocation.MyCommand.Name)."
#endregion
