$actions = Get-AzProviderOperation -OperationSearchString '*'
$actions | Where-Object {$_.Operation -like '*read*'} | Select-Object Operation | Export-Csv -Path 'Get-AllActions.csv' -NoTypeInformation -Force
