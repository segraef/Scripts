# With -Directory for folders and without for files
$searchprefix = 'nawtasp*'
$a = 'nawtasp'
$b = 'prfx'
Get-ChildItem -Path $searchprefix -Recurse | ForEach-Object -Process { Rename-item -Path $_.FullName -NewName ($_.name -replace $a, $b) -Verbose -whatif}