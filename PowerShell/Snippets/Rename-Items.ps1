# With -Directory for folders and without for files
$WhatIfPreference = 'False'

$searchprefix = '*eus*'
$a = 'eus'
$b = 'ae'
Get-ChildItem -Path $searchprefix -Recurse | ForEach-Object -Process { Rename-item -Path $_.FullName -NewName ($_.name -replace $a, $b) -Verbose}