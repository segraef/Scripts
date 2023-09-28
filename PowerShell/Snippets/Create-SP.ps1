Param(
   [string]$spRole = "Contributor",
   [string]$spScope = "/subscriptions/$subscriptionId"
)

# PowerShell
$spName = (Get-Random -SetSeed 1234 -Minimum 100000 -Maximum 999999).ToString() + "-sp"
$sp = New-AzADServicePrincipal -DisplayName $spName
New-AzRoleAssignment -RoleDefinitionName $spRole -ServicePrincipalName $sp.ApplicationId -Scope $spScope

# Azure CLI
spName=$(shuf -i 100000-999999 -n 1)-sp
sp=$(az ad sp create-for-rbac --name $spName --role $spRole --scopes $spScope)
echo $sp | jq -r .appId
echo $sp | jq -r .password
echo $sp | jq -r .tenant
