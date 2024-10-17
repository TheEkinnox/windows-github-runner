# Ensure commands are run from the scripts base directory
$basePath = (Get-Location).path
Set-Location (split-path -parent $MyInvocation.MyCommand.Definition)

# Load env file
get-content .env | foreach {
    $name, $value = $_.split('=')
    set-content env:\$name $value
}

$owner = $env:GH_OWNER
$repos = $env:GH_REPOSITORY

#Use --with-token to pass in a PAT token on standard input. The minimum required scopes for the token are: "repo", "read:org".
#Alternatively, gh will use the authentication token found in environment variables. See gh help environment for more info.
#To use gh in GitHub Actions, add GH_TOKEN: $ to "env". on Docker run: Docker run -e GH_TOKEN='myPatToken'
gh auth login --with-token $env:GH_TOKEN

#Cleanup#
#Look for any old/stale registrations to clean up
$runnerBaseName = $env:RUNNER_NAME + '_'

foreach ($repo in ($repos -split ',')) {
    $runnerListJson = gh api -H "Accept: application/vnd.github.v3+json" "/repos/$owner/$repo/actions/runners"
    $runnerList = (ConvertFrom-Json -InputObject $runnerListJson).runners

    foreach ($runner in $runnerList) {
        try {
            if (($runner.name -like "$runnerBaseName*") -and ($runner.status -eq "offline")) {
                Write-Host "Unregsitering old stale runner: $($runner.name) from $($repo)"
                gh api --method DELETE -H "Accept: application/vnd.github.v3+json" "/repos/$owner/$repo/actions/runners/$($runner.id)"
            }
        } catch {
            Write-Error $_.Exception.Message
        }
    }
}

#Remove PAT after cleanup
$env:GH_TOKEN = $null

# Go back to the initial path
Set-Location $basePath