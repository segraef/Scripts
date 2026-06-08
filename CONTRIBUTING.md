# Contribution

Thanks for considering contributing to this project! We are really glad you are reading this, because we need volunteer developers to help this project come to fruition.

Please note we have a code of conduct, please follow it in all your interactions with the project.

## Issues

If you find any bugs, please file an issue in the [GitHub issues][GitHubIssues] page. Please fill out the provided template with the appropriate information.

If you are taking the time to mention a problem, even a seemingly minor one, it is greatly appreciated, and a totally valid contribution to this project. Thank you!

## Conventions

- **PowerShell** (target 7+): start new scripts from [`PowerShell/_Template.ps1`](PowerShell/_Template.ps1). Comment-based help, `[CmdletBinding()]`, approved verbs, parameter validation, `SupportsShouldProcess` for state-changing operations, and logging via [`Write-Log.psm1`](PowerShell/Write-Log.psm1) (`Import-Module "$PSScriptRoot/Write-Log.psm1"`). Never hardcode tokens, subscription IDs, or account names: take them as parameters (`[securestring]` for secrets).
- **Bash**: start from [`Bash/_Template.sh`](Bash/_Template.sh); `set -euo pipefail`, quote expansions, source [`Bash/log.sh`](Bash/log.sh) for output.
- **Linting**: PowerShell is checked by PSScriptAnalyzer against [`PSScriptAnalyzerSettings.psd1`](PSScriptAnalyzerSettings.psd1); Bash by ShellCheck; everything by Super-Linter. All run on push and pull request. Run `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1` and `shellcheck -x` locally before opening a PR.

<!-- References -->

<!-- Local -->
[GitHubIssues]: <https://github.com/segraef/Scripts/issues>
[Contributing]: CONTRIBUTING.md
