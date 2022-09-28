# With -Directory for folders and without for files
$WhatIfPreference = 'False'

# $searchprefix = '.git'
$searchprefix = '.pre*'
Get-ChildItem -Path $searchprefix -Recurse -Hidden | ForEach-Object -Process { Remove-Item -Path $_.FullName -Verbose -Recurse -Force}
