# Login to Azure
Connect-AzAccount

<#
Function to fetch RBAC details recursively from Management Group to Resource Groups and export to CSV
0. Create empty array to store RBAC details
1. Fetch Management Group info and RBAC assignments
2. Fetch Subscriptions and RBAC assignments under the Management Group
3. Fetch Resource Groups and RBAC assignments under the Subscription


#>

Function Get-RBACDetails {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ManagementGroup
    )
    $RBACDetails = @()
    $MGInfo = Get-AzManagementGroup -GroupName $ManagementGroup
    $MGRBAC = Get-AzManagementGroupRoleAssignment -GroupId $ManagementGroup
    $MGInfo | Add-Member -MemberType NoteProperty -Name "Type" -Value "Management Group" -Force
    $MGInfo | Add-Member -MemberType NoteProperty -Name "RoleAssignment" -Value $MGRBAC -Force
    $RBACDetails += $MGInfo
    $Subscriptions = Get-AzManagementGroupSubscriptions -GroupId $ManagementGroup
    foreach ($Subscription in $Subscriptions) {
        $SubRBAC = Get-AzRoleAssignment -Scope $Subscription.Id
        $Subscription | Add-Member -MemberType NoteProperty -Name "Type" -Value "Subscription" -Force
        $Subscription | Add-Member -MemberType NoteProperty -Name "RoleAssignment" -Value $SubRBAC -Force
        $RBACDetails += $Subscription
        $ResourceGroups = Get-AzResourceGroup -SubscriptionId $Subscription.Id
        foreach ($ResourceGroup in $ResourceGroups) {
            $RGInfo = Get-AzResourceGroup -Name $ResourceGroup.ResourceGroupName
            $RGRBAC = Get-AzRoleAssignment -Scope $ResourceGroup.ResourceId
            $RGInfo | Add-Member -MemberType NoteProperty -Name "Type" -Value "Resource Group" -Force
            $RGInfo | Add-Member -MemberType NoteProperty -Name "RoleAssignment" -Value $RGRBAC -Force
            $RBACDetails += $RGInfo
        }
    }
    $RBACDetails | Export-Csv -Path "RBACDetails.csv" -NoTypeInformation
}

Get-RBACDetails -ManagementGroup "root"
