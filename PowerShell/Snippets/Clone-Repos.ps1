Param(
    [string]$destinationFolder = ".",
    [string]$org = "123",
    [array]$projects = (
        "Modules")

    # Make sure you have the Azure CLI installed (az extension add --name azure-devops) and logged in via az login or az devops login
    # If you face /_apis authentication issues make sure to login via az login --allow-no-subscriptions

    az devops configure --defaults organization=https://dev.azure.com/$org
    # $projects = az devops project list --organization=https://dev.azure.com/$org | ConvertFrom-Json

    foreach ($project in $projects) {
        $repos = az repos list --project $project | ConvertFrom-Json
        foreach ($repo in $repos) {
            Write-Output "Repository [$($repo.name)] in project [$($project)]"
            If (!(test-path -PathType container $destinationFolder)) {
                New-Item -ItemType Directory -Path $destinationFolder
            }
            git clone $($repo.remoteUrl) $destinationFolder/$($project)/$($repo.name)
        }
    }

    # clone repos in github

    $destinationFolder = "."

    $tfrepos = gh repo list azure -L 5000 --json name --jq '.[].name' | Select-String -Pattern "terraform-azurerm-avm"
    $org = 'Azure'

    foreach ($repo in $tfrepos) {
        If (!(test-path -PathType container $destinationFolder/$($org)/$($repo))) {
            New-Item -ItemType Directory -Path $destinationFolder/$($org)/$($repo)
        }
        Write-Output "https://github.com/$org/$repo.git into $destinationFolder/$($org)/$($repo)"
        git clone "https://github.com/$org/$repo.git" $destinationFolder/$($org)/$($repo)
    }
