# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- PowerShell scaffolding refresh: `Write-Log` as a real module (`Write-Log.psm1`), updated `_Template.ps1` (PowerShell 7, `SupportsShouldProcess`, parameter validation) and a `PSScriptAnalyzerSettings.psd1` lint/format baseline [@segraef](https://github.com/segraef)
- Bash scaffolding: `_Template.sh` and `log.sh` logging helpers [@segraef](https://github.com/segraef)
- Template Sync workflow to track [segraef/Template](https://github.com/segraef/Template) [@segraef](https://github.com/segraef)
- Repository structure section in the README [@segraef](https://github.com/segraef)

### Changed

- Modernised CI: `actions/checkout@v4`, `super-linter@v7`, latest PSScriptAnalyzer with shared settings, linters run on push and pull request [@segraef](https://github.com/segraef)

### Fixed

- Corrected `segraef/Template` references that pointed away from this repository (README badge, issue links) [@segraef](https://github.com/segraef)
- Expanded `.gitignore` (Python bytecode/venv, Node, logs); removed stray files [@segraef](https://github.com/segraef)

## [1.0.0] - 2021-06-25

### Added

- Initiated repository [@segraef](https://github.com/segraef)