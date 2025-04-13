# Ensure commands are run from the scripts base directory
$basePath = (Get-Location).path
Set-Location (split-path -parent $MyInvocation.MyCommand.Definition)

# Load env file
Get-Content .env | foreach {
    $name, $value = $_.split('=')
    Set-Content env:\$name $value
}

$owner = $env:GH_OWNER
$repos = $env:GH_REPOSITORY
$runnerVersion = $env:RUNNER_VERSION
$runnerBaseName = $env:RUNNER_NAME + '_'

# Move to a sub folder to avoid poluting the root directory
$runnersBasePath = "./_runners"

if ($env:FORCE_UPDATE -like "true")
{
    if (Test-Path -Path $runnersBasePath)
    {
        Remove-Item -Recurse -Force $runnersBasePath | Out-Null
    }

    & "./cleanup-runners.ps1"
}

if (!(Test-Path -Path $runnersBasePath))
{
    New-Item -Path $runnersBasePath -ItemType Directory | Out-Null
}

Set-Location $runnersBasePath

#Use --with-token to pass in a PAT token on standard input. The minimum required scopes for the token are: "repo", "read:org".
#Alternatively, gh will use the authentication token found in environment variables. See gh help environment for more info.
#To use gh in GitHub Actions, add GH_TOKEN: $ to "env". on Docker run: Docker run -e GH_TOKEN='myPatToken'

$ghPromptBehavior = (gh config get prompt)
gh config set prompt disabled
gh auth login --with-token $env:GH_TOKEN

$reposArray = ($repos -split ',')
$rootDir = Resolve-Path("./")

foreach ($repo in $reposArray)
{
    $runnerPath = Join-Path $rootDir "runner-$repo"

    if (!(Test-Path $runnerPath))
    {
        if (!(Test-Path ".\\actions-runner.zip" -PathType Leaf))
        {
            # Download the specified version of the github actions runner
            Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$runnerVersion/actions-runner-win-x64-$runnerVersion.zip" -OutFile "actions-runner.zip"
        }

        Expand-Archive -Path ".\\actions-runner.zip" -DestinationPath $runnerPath
    }

    #Get Runner registration Token
    $jsonObj = gh api --method POST -H "Accept: application/vnd.github.v3+json" "/repos/$owner/$repo/actions/runners/registration-token"
    $regToken = (ConvertFrom-Json -InputObject $jsonObj).token
    $runnerName = $runnerBaseName + (((New-Guid).Guid).replace("-", "")).substring(0, 5)

    try {
        #Register new runner instance
        Write-Host "Registering GitHub Self Hosted Runner on: $owner/$repo"

        #(Re)start runner
        & "$runnerPath/config.cmd" remove --token $regToken
        & "$runnerPath/config.cmd" --unattended --url "https://github.com/$owner/$repo" --token $regToken --name $runnerName --replace
		cmd /s /c "start ""$owner/$repo"" ""$runnerPath/run.cmd"""
    } catch {
        Write-Error $_.Exception.Message
        & "$runnerPath/config.cmd" remove --token $regToken
    }
}

# Remove PAT token after registering new instance
$env:GH_TOKEN = $null

# Go back to the initial path
Set-Location $basePath

# Reset gh prompt behavior
gh config set prompt $ghPromptBehavior
