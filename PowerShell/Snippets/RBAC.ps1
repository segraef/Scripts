# Login to Azure
Connect-AzAccount

# Function to fetch RBAC details recursively from Management Group to Resource Groups
function Get-RBACHierarchy {
    param (
        [string]$ManagementGroupId
    )

    # Fetch Management Group info and RBAC assignments
    $mgInfo = Get-AzManagementGroup -GroupId $ManagementGroupId
    $mgRBAC = Get-AzRoleAssignment -Scope "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"

    # Print Management Group and RBAC info
    Write-Host "Management Group: $($mgInfo.DisplayName)"
    foreach ($role in $mgRBAC) {
        Write-Host "`tRole: $($role.RoleDefinitionName) - Assigned to: $($role.SignInName)"
    }

    # Fetch Subscriptions under the Management Group
    $subscriptions = Get-AzSubscription -ManagementGroup $ManagementGroupId

    foreach ($subscription in $subscriptions) {
        # Print Subscription info and fetch its RBAC assignments
        Write-Host "`tSubscription: $($subscription.Name)"
        $subRBAC = Get-AzRoleAssignment -Scope $subscription.Id

        foreach ($role in $subRBAC) {
            Write-Host "`t`tRole: $($role.RoleDefinitionName) - Assigned to: $($role.SignInName)"
        }

        # Fetch Resource Groups under the Subscription
        $resourceGroups = Get-AzResourceGroup -SubscriptionId $subscription.Id
        foreach ($rg in $resourceGroups) {
            # Print Resource Group info and fetch its RBAC assignments
            Write-Host "`t`tResource Group: $($rg.ResourceGroupName)"
            $rgRBAC = Get-AzRoleAssignment -ResourceGroupName $rg.ResourceGroupName

            foreach ($role in $rgRBAC) {
                Write-Host "`t`t`tRole: $($role.RoleDefinitionName) - Assigned to: $($role.SignInName)"
            }
        }
    }
}

# Start fetching from the root management group (replace 'root' with your root management group ID if different)
Get-RBACHierarchy -ManagementGroupId "root"


function Get-RBACDetails {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Scope
    )
    $rbacDetails = @()
    $roleAssignments = Get-AzRoleAssignment -Scope $Scope
    foreach ($roleAssignment in $roleAssignments) {
        $rbacDetails += [PSCustomObject]@{
            "Scope" = $roleAssignment.Scope
            "RoleDefinitionName" = $roleAssignment.RoleDefinitionName
            "PrincipalType" = $roleAssignment.PrincipalType
            "PrincipalId" = $roleAssignment.PrincipalId
            "ObjectId" = $roleAssignment.ObjectId
            "ObjectType" = $roleAssignment.ObjectType
            "CanDelegate" = $roleAssignment.CanDelegate
        }
    }
    $rbacDetails
}
