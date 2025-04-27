<#
.SYNOPSIS2
  Create Azure Pipelines and Build Validation Checks.

.DESCRIPTION
  This script is used to create Azure Pipelines.
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

.PARAMETER RepositoryName
  Required. Repository for which the pipeline needs to be configured.

.PARAMETER PAT
  Required. The access token whith appropirate permissions to create Azure Pipelines.
  Usually the System.AccessToken from an Azure Pipeline instance run has sufficent permissions as well.
  Reference: https://docs.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#how-do-i-determine-the-job-authorization-scope-of-my-yaml-pipeline

.PARAMETER BranchName
  Optional. Branch name for which the pipelines will be configured.
  Default: 'main'.

.PARAMETER PipelineTargetPath
  Optional. Path of the folder where the pipeline needs to be created.

.PARAMETER PipelineSourcePath
  Optional. Path of the pipelines yaml file(s) to be used for creating Azure Pipelines.
  Based on the given folder all 'pipeline.yml' files will be searched within that and created accordingly.
  Default is the execution path '/.' of this script.

.PARAMETER createBuildValidation
  Optional. Create Pull Request Build Validation in additon.

.EXAMPLE
  New-AzPipeline -OrganizationName graef.io -ProjectName Project1 -RepositoryName Repository1 -PAT <PAT>

  Create all pipelines for the project 'graef.io/Project1' using a PAT.
  The Azure Pipelines will be configured to use the default branch 'main' and the given repository name.

  Given the 'PipelineSourcePath' and the default source folder patter the script will browse all *.yml files in the
  and takes the parent folder as the desired name for the Azure Pipeline name to be created.
#>

[CmdletBinding()]
param (
  [Parameter(Mandatory = $true, HelpMessage = "Azure DevOps Organization: <OrganizationName>")][string]$OrganizationName,
  [Parameter(Mandatory = $true, HelpMessage = "Azure DevOps Project: <ProjectName>")][string]$ProjectName,
  [Parameter(Mandatory = $true, HelpMessage = "Azure DevOps Repository: <RepositoryName>")][string]$RepositoryName,
  [Parameter(Mandatory = $true, HelpMessage = "Azure DevOps Personal Access Token: <PAT>")][string]$PAT,
  [Parameter(Mandatory = $false, HelpMessage = "Azure DevOps branch: <BranchName>")][string]$BranchName = "main",
  [Parameter(Mandatory = $false)][string]$PipelineTargetPath,
  [Parameter(Mandatory = $false)][string]$PipelineSourcePath,
  [Parameter(Mandatory = $false)][bool]$CreateBuildValidation = $false
)

try {
  Write-Verbose "----------------------------------"
  Write-Verbose "Installing Azure CLI extension devops"
  az config set extension.use_dynamic_install=yes_without_prompt  # to allow installing extensions without prompt
  az extension add --upgrade -n azure-devops

  Write-Verbose "----------------------------------"
  Write-Verbose "Check for availability of Azure CLI and the CLI extension for Azure DevOps"
  $az = az
  $az = az devops -h

  Write-Verbose "----------------------------------"
  Write-Verbose "Trying to login to Azure DevOps project $OrganizationName/$ProjectName with a PAT"
  $orgUrl = "https://dev.azure.com/$OrganizationName/"
  $env:AZURE_DEVOPS_EXT_PAT = $PAT
  Write-Output $env:AZURE_DEVOPS_EXT_PAT | az devops login

  Write-Verbose "----------------------------------"
  Write-Verbose "Set default Azure DevOps configuration to $OrganizationName and $ProjectName"
  az devops configure --defaults organization="$orgUrl" project="$ProjectName" --use-git-aliases true

  Write-Verbose "----------------------------------"
  Write-Verbose "Get and list all Azure Pipelines in $PipelineTargetPath"
  $azurePipelines = az pipelines list --organization $orgUrl --project $ProjectName --folder-path $PipelineTargetPath | ConvertFrom-Json | Sort-Object name
  Write-Verbose "Found $($azurePipelines.Count) Azure Pipeline(s) in $ProjectName"

  Write-Verbose "----------------------------------"
  Write-Verbose "Identify relevant Azure Pipelines to be updated"
  $PipelineSourcePath = Join-Path (Get-Location).Path $PipelineSourcePath
  $ymlPipelines = Get-ChildItem -Path $PipelineSourcePath -Recurse | Where-Object { $_.Name -like "pipeline.yml" } | Sort-Object FullName
  Write-Verbose "Found $($ymlPipelines.Count) YAML Pipeline(s) in $PipelineSourcePath"

  $pipelinesArray = @()
  foreach ($pipeline in $ymlPipelines) {
    $pipeObj = New-Object -TypeName PSCustomObject
    $fullYmlPath = $pipeline.fullname.replace("\", "/")
    $pathSplit = $fullYmlPath.Split("/")
    $ymlPath = $pathSplit[-5] + "/" + $pathSplit[-4] + "/" + $pathSplit[-3] + "/" + $pathSplit[-2] + "/" + $pathSplit[-1] #
    $parentFolderName = $pathSplit[-3] # here we have the parent folder name
    $pipelineName = $pathSplit[-3] # which we take for the pipeline name
    $pipeObj | Add-Member -MemberType NoteProperty -Name ProjectName -Value $ProjectName
    $pipeObj | Add-Member -MemberType NoteProperty -Name RepositoryName -Value $RepositoryName
    $pipeObj | Add-Member -MemberType NoteProperty -Name BranchName -Value $BranchName
    $pipeObj | Add-Member -MemberType NoteProperty -Name FolderPath -Value $PipelineTargetPath
    $pipeObj | Add-Member -MemberType NoteProperty -Name ymlPath -Value $ymlPath
    $pipeObj | Add-Member -MemberType NoteProperty -Name parentFolderName -Value $parentFolderName
    $pipeObj | Add-Member -MemberType NoteProperty -Name pipelineName -Value $pipelineName

    $pipelinesArray += $pipeObj
  }

  $pipelinesToBeSkipped = $pipelinesArray | Where-Object { $_.pipelineName -in $azurePipelines.name }
  $pipelinesToBeUpdated = $pipelinesArray | Where-Object { $_.pipelineName -notin $azurePipelines.name }

  if ($pipelinesToBeUpdated.Count -gt 0) {
    Write-Verbose "----------------------------------"
    Write-Verbose "$($pipelinesToBeUpdated.Count) Pipeline(s) have been identified to be updated"
    Write-Verbose "$($pipelinesToBeSkipped.Count) Pipeline(s) will be skipped"
  }
  else {
    Write-Verbose "----------------------------------"
    Write-Verbose "No Pipelines have been identified. Exiting."
    exit
  }

  foreach ($pipeline in $pipelinesToBeUpdated) {
    Write-Verbose "----------------------------------"
    Write-Verbose "Create Azure pipeline $($pipeline.pipelineName) ... "
    $pipelineresult = az pipelines create --project "$($pipeline.ProjectName)" `
      --organization "$orgUrl" `
      --repository "$($pipeline.RepositoryName)" `
      --repository-type tfsgit `
      --branch "$($pipeline.BranchName)" `
      --folder-path "$($pipeline.FolderPath)" `
      --name "$($pipeline.pipelineName)" `
      --yml-path "$($pipeline.ymlPath)" `
      --skip-run
    $pipelineobject = $pipelineresult | ConvertFrom-Json
    if ($createBuildValidation) {
      $pathFilter = $pipeline.ymlpath -replace 'pipeline.yml', '*'
      Write-Verbose "----------------------------------"
      Write-Verbose "Configuring Master branch Build Validation for $($pipeline.pipelineName)"
      $buildvalidation = az repos policy build create `
        --blocking true `
        --branch master `
        --build-definition-id $pipelineobject.id `
        --display-name "Check $($pipeline.pipelineName)" `
        --manual-queue-only true `
        --queue-on-source-update-only true `
        --valid-duration 1440 `
        --path-filter $pathFilter `
        --repository-id $pipelineobject.repository.id `
        --enabled true
    }
  }

  Write-Verbose "----------------------------------"
  Write-Verbose "$($pipelinesToBeUpdated.Count) Azure pipeline(s) created!"
  if ($createBuildValidation) {
    Write-Verbose "$($pipelinesToBeUpdated.Count) Pull Request Build Validation(s) created!"
  }
  Write-Verbose "$($pipelinesToBeSkipped.Count) Azure pipeline(s) skipped!"
  $url = $orgUrl + $ProjectName + "/" + "_build?definitionScope=%5C$PipelineTargetPath"
  Write-Verbose "----------------------------------"
  Write-Verbose "Please check your Azure  Pipelines here: $url..."
}
catch {
  Write-Verbose "----------------------------------"
  Write-Warning ("Reason: [{0}]" -f $_.Exception.Message)
}
