# With -Directory for folders and without for files
$WhatIfPreference = 'False'

$searchprefix = '.terraform'
$a = 'eus'
$b = 'ae'
Get-ChildItem -Path $searchprefix -Recurse | ForEach-Object -Process { Rename-item -Path $_.FullName -NewName ($_.name -replace $a, $b) -Verbose}

# Remove
Get-ChildItem -Recurse -Hidden | Where-Object { $_.FullName -like '*.terraform*' } | ForEach-Object -Process { Remove-Item -Path $_.FullName -Verbose -Force -Recurse}
