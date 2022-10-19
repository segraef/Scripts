$endTime = $(get-date).adddays(0.2)
$ip = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
$JitPolicyVm1 = (@{
    id="/subscriptions/<subID>/resourceGroups/vm-rg/providers/Microsoft.Compute/virtualMachines/cpc";
    ports=(@{
       number=3389;
       endTimeUtc="$endTime";
       allowedSourceAddressPrefix=@("$ip")})})

$JitPolicyArr=@($JitPolicyVm1)

Start-AzJitNetworkAccessPolicy -ResourceId "/subscriptions/<subID>/resourceGroups/vm-rg/providers/Microsoft.Security/locations/australiaeast/jitNetworkAccessPolicies/default" -VirtualMachine $JitPolicyArr


$modules = Get-ChildItem | select BaseName
foreach($module in $modules) {
    $module = $($module.BaseName)
    Write-output "bla import azuredevops_git_repository.$module Modules/$module"
    terraform import azuredevops_git_repository.$module Modules/$module
}
