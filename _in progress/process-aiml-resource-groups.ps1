#!/usr/bin/env pwsh

# Script to iterate through Azure resource groups starting with "rg-aiml-"
# Date: June 20, 2025

$ErrorActionPreference = "Stop"
$rgPrefix = "rg-aiml-"

# Role assignment parameters
$roleDefinitionName = "Owner"
$objectId = "<objectId>"
$objectType = "Group"

# Note: Azure CLI doesn't support --start-time and --end-time parameters directly
# Time-bound assignments must be done through the Azure Portal or PowerShell Az module

# Function to check if user is authenticated to Azure
function Test-AzureAuth {
    try {
        $account = az account show --query "name" -o tsv 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Already authenticated to Azure as: $account" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ Not authenticated to Azure" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "⚠️ Not authenticated to Azure" -ForegroundColor Yellow
        return $false
    }
}

# Function to authenticate to Azure
function Connect-Azure {
    Write-Host "🔑 Please authenticate to Azure..."
    az login
    if (-not (Test-AzureAuth)) {
        Write-Host "❌ Failed to authenticate to Azure. Exiting script." -ForegroundColor Red
        exit 1
    }

    # List available subscriptions and let user select one if there are multiple
    $subscriptions = az account list --query "[].{Name:name, Id:id, IsDefault:isDefault}" -o json | ConvertFrom-Json
    if ($subscriptions.Count -gt 1) {
        Write-Host "Multiple subscriptions found. Please select one:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $subscriptions.Count; $i++) {
            $defaultMark = if ($subscriptions[$i].IsDefault) { "[DEFAULT]" } else { "" }
            Write-Host "[$i] $($subscriptions[$i].Name) ($($subscriptions[$i].Id)) $defaultMark"
        }

        $selection = Read-Host "Enter the number of the subscription to use (press Enter for default)"
        if ($selection -ne "") {
            $selectedSubscription = $subscriptions[$selection].Id
            Write-Host "Setting subscription to: $($subscriptions[$selection].Name)"
            az account set --subscription $selectedSubscription
        }
    }
}

# Check if authenticated to Azure
if (-not (Test-AzureAuth)) {
    Connect-Azure
}

# Get current subscription details
$currentSubscription = az account show --query "{Name:name, Id:id}" -o json | ConvertFrom-Json
Write-Host "Using subscription: $($currentSubscription.Name) ($($currentSubscription.Id))" -ForegroundColor Blue

# Get all resource groups starting with the prefix
Write-Host "🔍 Searching for resource groups with prefix: $rgPrefix..." -ForegroundColor Blue
$resourceGroups = az group list --query "[?starts_with(name, '$rgPrefix')].{Name:name, Location:location, Tags:tags}" -o json | ConvertFrom-Json

if (-not $resourceGroups -or $resourceGroups.Count -eq 0) {
    Write-Host "❌ No resource groups found matching the prefix: $rgPrefix" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Found $($resourceGroups.Count) resource groups matching the prefix" -ForegroundColor Green

# Process each resource group
foreach ($rg in $resourceGroups) {
    Write-Host "Processing resource group: $($rg.Name) in $($rg.Location)" -ForegroundColor Cyan

    # Get resources in the resource group
    Write-Host "  📋 Listing resources in resource group $($rg.Name)..."
    $resources = az resource list --resource-group $rg.Name --query "[].{Name:name, Type:type, Location:location}" -o json | ConvertFrom-Json

    Write-Host "  📊 Found $($resources.Count) resources in resource group $($rg.Name)" -ForegroundColor Yellow

    # Example: Display resources by type
    $resourceTypes = $resources | Group-Object -Property Type
    foreach ($type in $resourceTypes) {
        Write-Host "    🔹 $($type.Count) resources of type: $($type.Name)" -ForegroundColor Magenta
        foreach ($resource in $type.Group) {
            Write-Host "      - $($resource.Name) ($($resource.Location))"
        }
    }

    # Example: Get detailed information for specific resource types
    # Uncomment and modify as needed
    <#
    $storageAccounts = $resources | Where-Object { $_.Type -eq "Microsoft.Storage/storageAccounts" }
    if ($storageAccounts) {
        Write-Host "  💾 Storage Account details:" -ForegroundColor Green
        foreach ($sa in $storageAccounts) {
            $saDetails = az storage account show --name $sa.Name --resource-group $rg.Name --query "{Name:name, Sku:sku.name, Kind:kind}" -o json | ConvertFrom-Json
            Write-Host "    - $($saDetails.Name) (SKU: $($saDetails.Sku), Kind: $($saDetails.Kind))"
        }
    }
    #>

    # Example: Custom operations for each resource group
    # This is where you can add your specific operations
    Write-Host "  🔧 Performing custom operations for resource group $($rg.Name)..." -ForegroundColor Cyan

    # Assign the external group as Owner to the resource group
    Write-Host "  👥 Assigning external group as Owner to resource group $($rg.Name)..." -ForegroundColor Yellow

    # Get the scope for the resource group
    $scope = "/subscriptions/$($currentSubscription.Id)/resourceGroups/$($rg.Name)"

    # Check if role assignment already exists
    $existingAssignment = az role assignment list --assignee $objectId --role $roleDefinitionName --scope $scope --query "[0]" -o json 2>$null | ConvertFrom-Json

    if ($existingAssignment) {
        Write-Host "  ⚠️ Role assignment already exists for this group on resource group $($rg.Name)" -ForegroundColor Yellow
    }
    else {
        # Create the role assignment (no time-bound options in Azure CLI)
        try {
            $assignmentResult = az role assignment create `
                --role $roleDefinitionName `
                --assignee-object-id $objectId `
                --assignee-principal-type $objectType `
                --scope $scope -o json 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Successfully assigned role 'Owner' to external group for resource group $($rg.Name)" -ForegroundColor Green
            } else {
                Write-Host "  ❌ Failed to assign role: $assignmentResult" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "  ❌ Error assigning role: $_" -ForegroundColor Red
        }
    }

    Write-Host "  ✅ Completed processing resource group: $($rg.Name)" -ForegroundColor Green
    Write-Host ""
}

Write-Host "✅ All resource groups processed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Note: For time-bound role assignments (with start/end dates):" -ForegroundColor Yellow
Write-Host "  Azure CLI doesn't support setting expiration dates directly." -ForegroundColor Yellow
Write-Host "  To create time-bound assignments like shown in the screenshot, use PowerShell Az module instead:" -ForegroundColor Yellow
Write-Host "  New-AzRoleAssignment -ObjectId $objectId -RoleDefinitionName $roleDefinitionName -Scope \$scope -ExpiryOn '2025-12-17T15:29:15Z'" -ForegroundColor Cyan
Write-Host ""
