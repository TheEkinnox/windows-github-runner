## Description

Utility scripts to setup self-hosted github runners on a windows computer

Note: this voluntarily doesn't start the runners as processes to avoid permission issues and have a better control over the runners' lifetime

## Requirements

- powershell
- git
- GitHub CLI

## How to use

1. Create a `.env` file with the runner settings (see `example.env` for reference)
2. Start the runner by running `setup-runners.ps1` in PowerShell
3. When the runners are not needed anymore, close their terminals and run `cleanup-runners.ps1` to unregister them from your github repositories