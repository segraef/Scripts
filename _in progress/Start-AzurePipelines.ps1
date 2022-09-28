<#
.SYNOPSIS
Start all specified DevOps pipelines in a target DevOps Project.

.DESCRIPTION
Starts all specified DevOps pipelines in a target DevOps Project.
If this scripts is run within an Azure pipeline the environment variable AZURE_DEVOPS_EXT_PAT needs to be set with $(System.AccessToken) within your pipeline.
Since tty is not supported within a pipelune run, az devops login is using the token which is set via AZURE_DEVOPS_EXT_PAT.

.REQUIREMENTS
- Azure CLI 2.13.0
- Azure CLI extension devops 0.18.0
- Repository for which the pipeline needs to be configured.
- The '<ProjectName>' Build Service needs 'Edit build pipeline' permissions
Reference: https://docs.microsoft.com/en-us/azure/devops/pipelines/policies/permissions?view=azure-devops#pipeline-permissions

.PARAMETER OrganizationName
Required. The name of the Azure DevOps organization.

.PARAMETER ProjectName
Required. The name of the Azure DevOps project.

.PARAMETER AzureDevOpsPAT
Required. The access token with appropriate permissions to create Azure Pipelines.
Usually the System.AccessToken from an Azure Pipeline instance run has sufficient permissions as well.
Reference: https://docs.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#how-do-i-determine-the-job-authorization-scope-of-my-yaml-pipeline
Needs at least the permissions:
- Agent Pool:           Read
- Build:                Read & execute
- Service Connections:  Read & query

.PARAMETER Branch
Optional. Name of the branch on which the pipeline run is to be queued. Default: refs/heads/main

.PARAMETER FolderPath
Optional. Folder path of pipeline. Default is root '\' level folder.

.EXAMPLE
$inputObject = @{
    OrganizationName      = 'Contoso'
    ProjectName           = 'CICD'
    AzureDevOpsPAT        = '<Placeholder>'
}
StartPipeline @inputObject

#>
function Start-AzurePipelines {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $OrganizationName,

        [Parameter(Mandatory = $true)]
        [string] $ProjectName,

        [Parameter(Mandatory = $true)]
        [string] $AzureDevOpsPAT,

        [Parameter(Mandatory = $false)]
        [string] $Branch = 'refs/heads/main',

        [Parameter(Mandatory = $false)]
        [string] $FolderPath = '\'
    )

    Write-Verbose "Trying to login to Azure DevOps project $organizationName/$projectName with a PAT"
    $orgUrl = "https://dev.azure.com/$organizationName/"
    # $AzureDevOpsPAT | az devops login

    Write-Verbose "Set default Azure DevOps configuration to $organizationName and $projectName"
    az devops configure --defaults organization=$orgUrl project=$projectName --use-git-aliases $true

    Write-Verbose "Get and list all Azure Pipelines in $folderPath"
    $azurePipelines = az pipelines list --organization $orgUrl --project $projectName --folder-path $folderPath | ConvertFrom-Json | Sort-Object name
    Write-Verbose ('Found [{0}] Azure Pipeline(s) in project [{1}]' -f $azurePipelines.Count, $projectName)

    Write-Verbose '----------------------------------'
    foreach ($pipeline in $azurePipelines) {
        Write-Verbose ('Start Azure pipeline [{0}]' -f $pipeline.name)

        $inputObject = @(
            '--id', $pipeline.id,
            '--branch', $branch,
            '--folder-path', $pipeline.path,
            '--name', $pipeline.name
        )

        $pipelineresult = az pipelines run @inputObject
    }
}