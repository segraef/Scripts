# Start pwsh if not started yet

# pwsh

# Set default directory
$folder = "Git/Azure/bicep-registry-modules" # location of your local clone of bicep-registry-modules

# Dot source functions

. $folder/avm/utilities/tools/Set-AVMModule.ps1
. $folder/avm/utilities/tools/Test-ModuleLocally.ps1

# Variables

$modules = @(
    "dev-center/devcenter"
    # "managed-services/registration-definition"
    # "compute/disk-encryption-set"
    # "compute/disk"
)

# Generate Readme

foreach ($module in $modules) {
    Write-Output "Generating ReadMe for module $module"
    Set-AVMModule -ModuleFolderPath "$folder/avm/res/$module" -Recurse

    # Set up test settings

    $testcases = "waf-aligned", "max", "defaults"

    $TestModuleLocallyInput = @{
        TemplateFilePath           = "$folder/avm/res/$module/main.bicep"
        PesterTest                 = $true
        ValidationTest             = $true
        DeploymentTest             = $false
        ValidateOrDeployParameters = @{
            Location         = 'australiaeast'
            SubscriptionId   = '<subId>'
            RemoveDeployment = $true
        }
        AdditionalTokens           = @{
            namePrefix = '<your-prefix>'
            TenantId   = '<tenantId>'
        }
    }

    # Run tests

    foreach ($testcase in $testcases) {
        Write-Output "Running test case $testcase on module $module"
        $TestModuleLocallyInput.ModuleTestFilePath = "$folder/avm/res/$module/tests/e2e/$testcase/main.test.bicep"

        try {
            Test-ModuleLocally @TestModuleLocallyInput
        }
        catch {
            Write-Output $_.Exception | Format-List -Force
        }
    }
}
