# AVM Module Tester Script
# Before running this script, make sure to:
# 1. Replace '<subId>' with your actual Azure subscription ID
# 2. Replace '<your-prefix>' with your desired naming prefix
# 3. Replace '<tenantId>' with your Azure AD tenant ID
# 4. Ensure you have the required Azure PowerShell modules installed

# Start pwsh if not started yet

# pwsh

# Set default directory
$folder = "Git/GitHub/Azure/bicep-registry-modules" # location of your local clone of bicep-registry-modules

# Ensure Azure PowerShell authentication
if (-not (Get-AzContext)) {
    Write-Output "No Azure context found. Please authenticate..."
    Connect-AzAccount
}

# Set the subscription context (update with your actual subscription ID)
$subscriptionId = '<subId>' # Replace with your actual subscription ID
if ($subscriptionId -ne '<subId>') {
    Set-AzContext -SubscriptionId $subscriptionId
}

# Dot source functions
. $folder/utilities/tools/Set-AVMModule.ps1
. $folder/utilities/tools/Test-ModuleLocally.ps1

# Variables

$modules = @(
    "web/site" # 5599
    # "communication/communication-service" # 5598
)

# Generate Readme

foreach ($module in $modules) {
    Write-Output "Generating ReadMe for module $module"
    Set-AVMModule -ModuleFolderPath "$folder/avm/res/$module" -Recurse

    # Set up test settings

    $testcases = "functionApp.defaults", "webApp.max" #, "waf-aligned", "max", "defaults"
    # $testcase = "all"

    $TestModuleLocallyInput = @{
        TemplateFilePath           = "$folder/avm/res/$module/main.bicep"
        PesterTest                 = $true
        ValidationTest             = $true
        DeploymentTest             = $true
        ValidateOrDeployParameters = @{
            Location         = 'australiaeast'
            SubscriptionId   = $subscriptionId
            RemoveDeployment = $true
        }
        AdditionalTokens           = @{
            namePrefix = 'asf3re' # Replace with your prefix
            TenantId   = '<tenantId>'    # Replace with your tenant ID
        }
    }

    # Run tests
    # if testcase is 'all' browse all folders in tests/e2e
    if ($testcase -eq "all") {
        $testcases = Get-ChildItem -Path "$folder/avm/res/$module/tests/e2e" -Directory | ForEach-Object { $_.Name }
    }
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
