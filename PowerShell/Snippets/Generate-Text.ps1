$names = Get-ChildItem
foreach($name in $names) {
    $x = $name.BaseName -replace "(?-i)[A-Z]",'-$&'
    $x = $x.ToLower()
    Write-output """terraform-azurerm$x"","
}
