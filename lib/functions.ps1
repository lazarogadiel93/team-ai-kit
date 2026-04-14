#Requires -Version 5.1
<#
.SYNOPSIS
    Team AI Kit -- Reusable functions for setup and configuration.
.DESCRIPTION
    Pure/testable functions used by setup.ps1. No interactive prompts here.
#>

Set-StrictMode -Version Latest

# ── Constants ─────────────────────────────────────────────────────────────────

$script:VALID_IDES = @('vscode', 'intellij', 'opencode')
$script:VALID_ROLES = @('frontend', 'backend-node', 'devops', 'python')
$script:VALID_PROVIDERS = @('openai', 'azure-openai', 'anthropic', 'github-copilot')
$script:VALID_COMMANDS = @('setup', 'update', 'status', 'doctor', 'help')

# ── Config Persistence ───────────────────────────────────────────────────────

function Get-TeamAiKitConfigDir {
    <#
    .SYNOPSIS
        Returns the path to the team-ai-kit config directory (~/.team-ai-kit).
    #>
    return Join-Path $env:USERPROFILE '.team-ai-kit'
}

function Get-TeamAiKitConfigPath {
    <#
    .SYNOPSIS
        Returns the full path to the config.json file.
    #>
    return Join-Path (Get-TeamAiKitConfigDir) 'config.json'
}

function Get-TeamAiKitConfig {
    <#
    .SYNOPSIS
        Reads and returns the team-ai-kit config as a hashtable.
        Returns default empty config if file does not exist.
    #>
    $configPath = Get-TeamAiKitConfigPath
    if (-not (Test-Path $configPath)) {
        return @{
            ide          = $null
            role         = $null
            provider     = $null
            teamRepo     = $null
            installedAt  = $null
            lastUpdate   = $null
            version      = $null
        }
    }
    $raw = Get-Content $configPath -Raw | ConvertFrom-Json
    $config = @{}
    $raw.PSObject.Properties | ForEach-Object { $config[$_.Name] = $_.Value }
    return $config
}

function Save-TeamAiKitConfig {
    <#
    .SYNOPSIS
        Saves the team-ai-kit config hashtable to config.json.
    .OUTPUTS
        The path to the saved config file.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    $configDir = Get-TeamAiKitConfigDir
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    $configPath = Join-Path $configDir 'config.json'
    $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8
    return $configPath
}

function Test-FirstRun {
    <#
    .SYNOPSIS
        Returns $true if team-ai-kit has never been configured (no config.json).
    #>
    return -not (Test-Path (Get-TeamAiKitConfigPath))
}

function Test-ValidCommand {
    <#
    .SYNOPSIS
        Validates that the given command is a supported CLI subcommand.
    #>
    param([string]$Command)
    return $script:VALID_COMMANDS -contains $Command.ToLower()
}

# ── IDE-to-Agent Mapping ──────────────────────────────────────────────────────

function Get-GentleAiAgentId {
    <#
    .SYNOPSIS
        Maps a team-ai-kit IDE identifier to a gentle-ai agent ID.
        Returns $null for IDEs not supported by gentle-ai (e.g. IntelliJ).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Ide
    )
    $map = @{
        'vscode'   = 'vscode-copilot'
        'opencode' = 'opencode'
    }
    return $map[$Ide.ToLower()]
}

function Test-GentleAiSupportsIde {
    <#
    .SYNOPSIS
        Returns $true if gentle-ai has a native adapter for this IDE.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Ide
    )
    return $null -ne (Get-GentleAiAgentId -Ide $Ide)
}

# ── Prerequisite Checks ──────────────────────────────────────────────────────

function Test-ScoopInstalled {
    <#
    .SYNOPSIS
        Returns $true if Scoop package manager is available in PATH.
    #>
    try {
        $null = Get-Command scoop -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Test-GentleAiInstalled {
    <#
    .SYNOPSIS
        Returns $true if gentle-ai binary is available in PATH.
    #>
    try {
        $null = Get-Command gentle-ai -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Test-EngramInstalled {
    <#
    .SYNOPSIS
        Returns $true if engram binary is available in PATH or in known locations.
    #>
    # Check PATH first
    try {
        $null = Get-Command engram -ErrorAction Stop
        return $true
    }
    catch {}

    # Check known install location (Scoop)
    $scoopPath = Join-Path $env:USERPROFILE 'scoop\shims\engram.exe'
    if (Test-Path $scoopPath) { return $true }

    # Check AppData (gentle-ai installs here)
    $appDataPath = Join-Path $env:LOCALAPPDATA 'engram\bin\engram.exe'
    if (Test-Path $appDataPath) { return $true }

    return $false
}

function Get-EngramBinaryPath {
    <#
    .SYNOPSIS
        Returns the full path to the engram binary, or $null if not found.
    #>
    try {
        $cmd = Get-Command engram -ErrorAction Stop
        return $cmd.Source
    }
    catch {}

    $scoopPath = Join-Path $env:USERPROFILE 'scoop\shims\engram.exe'
    if (Test-Path $scoopPath) { return $scoopPath }

    $appDataPath = Join-Path $env:LOCALAPPDATA 'engram\bin\engram.exe'
    if (Test-Path $appDataPath) { return $appDataPath }

    return $null
}

# ── gentle-ai Install ────────────────────────────────────────────────────────

function Invoke-GentleAiInstall {
    <#
    .SYNOPSIS
        Runs gentle-ai install with the correct flags for the given agent.
    .DESCRIPTION
        Executes `gentle-ai install --agent <id> --preset <preset> --persona <persona>`.
        Returns $true on success, $false on failure.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$AgentId,
        [string]$Preset = 'ecosystem-only',
        [string]$Persona = 'gentleman'
    )

    if (-not (Test-GentleAiInstalled)) {
        throw 'gentle-ai is not installed. Run setup prerequisites first.'
    }

    $args = @('install', '--agent', $AgentId, '--preset', $Preset, '--persona', $Persona)
    try {
        & gentle-ai @args
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# ── Validation ────────────────────────────────────────────────────────────────

function Test-ValidIde {
    <#
    .SYNOPSIS
        Validates that the given IDE identifier is supported.
    #>
    param([string]$Ide)
    return $script:VALID_IDES -contains $Ide.ToLower()
}

function Test-ValidRole {
    <#
    .SYNOPSIS
        Validates that the given role identifier is supported.
    #>
    param([string]$Role)
    return $script:VALID_ROLES -contains $Role.ToLower()
}

function Test-ValidProvider {
    <#
    .SYNOPSIS
        Validates that the given provider identifier is supported.
    #>
    param([string]$Provider)
    return $script:VALID_PROVIDERS -contains $Provider.ToLower()
}

# ── Skills Management ─────────────────────────────────────────────────────────

function Get-SharedSkillPaths {
    <#
    .SYNOPSIS
        Returns all shared skill file paths from the kit root.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$KitRoot
    )
    $sharedDir = Join-Path $KitRoot 'skills\shared'
    if (-not (Test-Path $sharedDir)) { return @() }
    return @(Get-ChildItem -Path $sharedDir -Filter '*.md' -Recurse | Select-Object -ExpandProperty FullName)
}

function Get-RoleSkillPaths {
    <#
    .SYNOPSIS
        Returns skill file paths for a specific role from the kit root.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$KitRoot,
        [Parameter(Mandatory)]
        [string]$Role
    )
    $roleDir = Join-Path $KitRoot "skills\roles\$Role"
    if (-not (Test-Path $roleDir)) { return @() }
    return @(Get-ChildItem -Path $roleDir -Filter '*.md' -Recurse | Select-Object -ExpandProperty FullName)
}

function Get-AllSkillPathsForRole {
    <#
    .SYNOPSIS
        Returns combined shared + role-specific skill file paths.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$KitRoot,
        [Parameter(Mandatory)]
        [string]$Role
    )
    # NOTE: Must use += to avoid PS5.1 array concat gotcha where
    # @($arrayA) + @($arrayB) can collapse $arrayB into a single string.
    [string[]]$all = @()
    $all += @(Get-SharedSkillPaths -KitRoot $KitRoot)
    $all += @(Get-RoleSkillPaths -KitRoot $KitRoot -Role $Role)
    return $all
}

function Get-PackRulesPath {
    <#
    .SYNOPSIS
        Returns the pack rules file path for a given role.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$KitRoot,
        [Parameter(Mandatory)]
        [string]$Role
    )
    $rulesPath = Join-Path $KitRoot "packs\$Role\rules.md"
    if (Test-Path $rulesPath) { return $rulesPath }
    return $null
}

# ── IDE Config Paths ──────────────────────────────────────────────────────────

function Get-IdeSkillsDirectory {
    <#
    .SYNOPSIS
        Returns the target directory where skills should be copied for the given IDE.
        Uses gentle-ai's native paths for supported IDEs.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Ide
    )
    switch ($Ide.ToLower()) {
        'vscode' {
            # VS Code Copilot: gentle-ai installs skills here
            return Join-Path $env:USERPROFILE '.copilot\skills'
        }
        'intellij' {
            # IntelliJ: no gentle-ai adapter, use shared copilot path
            return Join-Path $env:USERPROFILE '.copilot\skills'
        }
        'opencode' {
            # OpenCode: gentle-ai installs skills here
            return Join-Path $env:USERPROFILE '.config\opencode\skills'
        }
        default {
            throw "Unsupported IDE: $Ide"
        }
    }
}

function Get-IdeInstructionsPath {
    <#
    .SYNOPSIS
        Returns the target path for IDE instructions file (copilot-instructions.md or AGENTS.md).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Ide,
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )
    switch ($Ide.ToLower()) {
        'vscode' {
            return Join-Path $ProjectRoot '.github\copilot-instructions.md'
        }
        'intellij' {
            return Join-Path $ProjectRoot '.github\copilot-instructions.md'
        }
        'opencode' {
            return Join-Path $ProjectRoot 'AGENTS.md'
        }
        default {
            throw "Unsupported IDE: $Ide"
        }
    }
}

# ── Skills Installation ───────────────────────────────────────────────────────

function Install-TeamSkills {
    <#
    .SYNOPSIS
        Copies shared + role-specific skills to the IDE's skill directory.
    .OUTPUTS
        Array of copied file paths (destination).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$KitRoot,
        [Parameter(Mandatory)]
        [string]$Role,
        [Parameter(Mandatory)]
        [string]$TargetDir
    )

    $skills = Get-AllSkillPathsForRole -KitRoot $KitRoot -Role $Role
    $copied = @()

    foreach ($skillPath in $skills) {
        # Preserve relative structure: skills/shared/arch/SKILL.md → team-skills/shared/arch/SKILL.md
        $skillsBase = Join-Path $KitRoot 'skills'
        $relativePath = $skillPath.Replace($skillsBase, '').TrimStart('\', '/')
        $destPath = Join-Path $TargetDir "team-skills\$relativePath"
        $destDir = Split-Path $destPath -Parent

        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        Copy-Item -Path $skillPath -Destination $destPath -Force
        $copied += $destPath
    }

    return $copied
}

# ── Engram Sync Config ────────────────────────────────────────────────────────

function New-EngramSyncConfig {
    <#
    .SYNOPSIS
        Generates the engram sync configuration object.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SyncRepoUrl,
        [int]$Port = 7437
    )
    return @{
        syncRepo = $SyncRepoUrl
        port     = $Port
        mode     = 'local-sync'
    }
}

# ── MCP Config Generation ────────────────────────────────────────────────────

function New-VsCodeMcpConfig {
    <#
    .SYNOPSIS
        Generates the MCP config JSON for VS Code (.vscode/mcp.json).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$EngramBinaryPath
    )
    $config = @{
        servers = @{
            engram = @{
                command = $EngramBinaryPath
                args    = @('mcp', '--tools=agent')
            }
            context7 = @{
                type = 'sse'
                url  = 'https://mcp.context7.com/mcp'
            }
        }
    }
    return $config | ConvertTo-Json -Depth 5
}

function New-IntelliJMcpConfig {
    <#
    .SYNOPSIS
        Generates the MCP config JSON for IntelliJ.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$EngramBinaryPath
    )
    # IntelliJ uses the same MCP JSON format
    return New-VsCodeMcpConfig -EngramBinaryPath $EngramBinaryPath
}

# ── Instructions Generation ───────────────────────────────────────────────────

function New-CopilotInstructions {
    <#
    .SYNOPSIS
        Generates the copilot-instructions.md content with team rules injected.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Role,
        [string]$PackRulesContent = ''
    )

    $header = @"
# Team AI Kit -- Copilot Instructions

> Auto-generated by team-ai-kit setup. Role: $Role
> Do not edit manually -- re-run setup.ps1 to update.

---

## Team Conventions

- Follow the team's established patterns and conventions
- Use engram to save decisions, discoveries, and bug fixes
- Search engram before starting work to check for prior knowledge
- Always explain WHY, not just WHAT, when making decisions

"@

    if ($PackRulesContent) {
        return "$header`n$PackRulesContent"
    }
    return $header
}

# ── Template Engine ────────────────────────────────────────────────────────────

function Get-TemplateDirectory {
    <#
    .SYNOPSIS
        Returns the template directory path for the given IDE.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$KitRoot,
        [Parameter(Mandatory)]
        [string]$Ide
    )
    $ideDirMap = @{
        'vscode'   = 'vscode-copilot'
        'intellij' = 'intellij-copilot'
        'opencode' = 'opencode'
    }
    $dirName = $ideDirMap[$Ide.ToLower()]
    if (-not $dirName) { throw "Unsupported IDE: $Ide" }

    $templateDir = Join-Path $KitRoot "templates\$dirName"
    if (-not (Test-Path $templateDir)) { return $null }
    return $templateDir
}

function Get-TemplateFiles {
    <#
    .SYNOPSIS
        Returns all .template files in the IDE template directory.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TemplateDir
    )
    if (-not (Test-Path $TemplateDir)) { return @() }
    return @(Get-ChildItem -Path $TemplateDir -Filter '*.template' -Recurse)
}

function Expand-Template {
    <#
    .SYNOPSIS
        Replaces {{PLACEHOLDER}} tokens in template content with actual values.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Content,
        [Parameter(Mandatory)]
        [hashtable]$Variables
    )
    $result = $Content
    foreach ($key in $Variables.Keys) {
        $result = $result.Replace("{{$key}}", $Variables[$key])
    }
    return $result
}

function Install-Templates {
    <#
    .SYNOPSIS
        Copies and expands templates to the target project directory.
    .OUTPUTS
        Array of created file paths (destination).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TemplateDir,
        [Parameter(Mandatory)]
        [string]$TargetDir,
        [Parameter(Mandatory)]
        [hashtable]$Variables
    )

    $templates = Get-TemplateFiles -TemplateDir $TemplateDir
    $created = @()

    foreach ($tpl in $templates) {
        # Remove .template extension for the destination filename
        $destFileName = $tpl.Name -replace '\.template$', ''
        $destPath = Join-Path $TargetDir $destFileName
        $destDir = Split-Path $destPath -Parent

        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        $content = Get-Content $tpl.FullName -Raw
        $expanded = Expand-Template -Content $content -Variables $Variables
        Set-Content -Path $destPath -Value $expanded -NoNewline

        $created += $destPath
    }

    return $created
}

# ── Summary ───────────────────────────────────────────────────────────────────

function New-SetupSummary {
    <#
    .SYNOPSIS
        Generates a human-readable summary of the setup configuration.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Ide,
        [Parameter(Mandatory)]
        [string]$Role,
        [Parameter(Mandatory)]
        [string]$Provider,
        [int]$SkillsCopied = 0,
        [string]$GentleAiStatus = 'n/a'
    )
    return @"
============================================
  Team AI Kit -- Setup Complete
============================================
  IDE:         $Ide
  Role:        $Role
  Provider:    $Provider
  gentle-ai:   $GentleAiStatus
  Team Skills: $SkillsCopied installed
============================================
"@
}
