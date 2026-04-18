#Requires -Version 5.1
<#
.SYNOPSIS
    Team AI Kit -- Setup wrapper.
.DESCRIPTION
    This script delegates to the CLI entry point (bin/team-ai-kit.ps1 setup).
    For the full CLI experience, install via Scoop and use 'team-ai-kit' directly.

    Kept for backward compatibility with existing workflows.
.EXAMPLE
    .\setup.ps1
    Interactive mode -- prompts for IDE and role.
.EXAMPLE
    .\setup.ps1 -Ide vscode -Role frontend
    Non-interactive mode.
#>

param(
    [ValidateSet('vscode', 'intellij', 'opencode', 'cursor')]
    [string]$Ide,

    [ValidateSet('frontend', 'backend-node', 'devops', 'python')]
    [string]$Role,

    [ValidateSet('openai', 'azure-openai', 'anthropic', 'github-copilot')]
    [string]$Provider,

    [string]$TeamRepo,

    [string]$TargetDir,

    [switch]$SkipPrerequisites,

    [switch]$SkipGentleAi,

    [switch]$Update
)

# Build hashtable for splatting (array splatting treats named params as positional in PS 5.1)
$cliParams = @{ Command = 'setup' }

if ($Ide)               { $cliParams.Ide = $Ide }
if ($Role)              { $cliParams.Role = $Role }
if ($Provider)          { $cliParams.Provider = $Provider }
if ($TeamRepo)          { $cliParams.TeamRepo = $TeamRepo }
if ($TargetDir)         { $cliParams.TargetDir = $TargetDir }
if ($SkipPrerequisites) { $cliParams.SkipPrerequisites = $true }
if ($SkipGentleAi)      { $cliParams.SkipGentleAi = $true }
if ($Update)            { $cliParams.Update = $true }

$cliPath = Join-Path $PSScriptRoot 'bin\team-ai-kit.ps1'
& $cliPath @cliParams
