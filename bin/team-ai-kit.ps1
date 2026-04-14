#Requires -Version 5.1
<#
.SYNOPSIS
    Team AI Kit CLI -- gentle-ai for teams.
.DESCRIPTION
    One-command setup for your team's AI development environment.
    Installs gentle-ai as base layer, adds team-specific role skills
    and configuration on top.

    Subcommands:
      setup   - First-time configuration (interactive or non-interactive)
      update  - Pull latest team content and merge without overwriting
      status  - Show current configuration and installed skills
      doctor  - Verify prerequisites and installation health
      help    - Show this help message
.EXAMPLE
    team-ai-kit setup
    Interactive setup -- prompts for IDE and role.
.EXAMPLE
    team-ai-kit setup -Ide vscode -Role frontend
    Non-interactive setup for VS Code + Frontend.
.EXAMPLE
    team-ai-kit setup -Ide opencode -Role devops -Provider anthropic
    Non-interactive for OpenCode with explicit provider.
.EXAMPLE
    team-ai-kit setup -Ide vscode -Role frontend -TeamRepo https://dev.azure.com/equipo/team-knowledge
    Setup with team content repo (skills and rules shared across projects).
.EXAMPLE
    team-ai-kit update
    Pull latest from team repo + merge without overwriting local changes.
.EXAMPLE
    team-ai-kit status
    Show current config, installed skills, and team repo status.
#>

param(
    [Parameter(Position = 0)]
    [string]$Command = 'help',

    [ValidateSet('vscode', 'intellij', 'opencode')]
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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -- Resolve paths -------------------------------------------------------------
# bin/ is one level down from the kit root
$kitRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $kitRoot 'lib\functions.ps1')

# -- Output helpers ------------------------------------------------------------
function Write-Step { param([string]$Msg) Write-Host "  > $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "  + $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "  ! $Msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$Msg) Write-Host "  x $Msg" -ForegroundColor Red }

# -- Banner --------------------------------------------------------------------
function Show-Banner {
    Write-Host ''
    Write-Host '  +======================================+' -ForegroundColor Magenta
    Write-Host '  |        Team AI Kit -- CLI            |' -ForegroundColor Magenta
    Write-Host '  |  gentle-ai for teams                 |' -ForegroundColor Magenta
    Write-Host '  +======================================+' -ForegroundColor Magenta
    Write-Host ''
}

# -- Help ----------------------------------------------------------------------
function Show-Help {
    Show-Banner
    Write-Host '  Usage: team-ai-kit <command> [options]' -ForegroundColor White
    Write-Host ''
    Write-Host '  Commands:' -ForegroundColor Yellow
    Write-Host '    setup    First-time configuration (IDE, role, team repo)'
    Write-Host '    update   Pull latest team content + merge without overwriting'
    Write-Host '    status   Show current config and installed skills'
    Write-Host '    doctor   Verify prerequisites and installation health'
    Write-Host '    help     Show this help message'
    Write-Host ''
    Write-Host '  Setup options:' -ForegroundColor Yellow
    Write-Host '    -Ide <vscode|intellij|opencode>'
    Write-Host '    -Role <frontend|backend-node|devops|python>'
    Write-Host '    -Provider <openai|azure-openai|anthropic|github-copilot>'
    Write-Host '    -TeamRepo <url>          Team content repo URL'
    Write-Host '    -TargetDir <path>        Custom output directory'
    Write-Host '    -SkipPrerequisites       Skip Scoop/gentle-ai checks'
    Write-Host '    -SkipGentleAi            Skip gentle-ai install step'
    Write-Host ''
    Write-Host '  Examples:' -ForegroundColor Yellow
    Write-Host '    team-ai-kit setup'
    Write-Host '    team-ai-kit setup -Ide vscode -Role frontend'
    Write-Host '    team-ai-kit setup -Ide vscode -Role frontend -TeamRepo https://dev.azure.com/equipo/team-knowledge'
    Write-Host '    team-ai-kit update'
    Write-Host '    team-ai-kit status'
    Write-Host ''
}

# -- Setup ---------------------------------------------------------------------
function Invoke-SetupCommand {
    Show-Banner
    Write-Host '  3 questions. 2 minutes. Full power.' -ForegroundColor DarkGray
    Write-Host ''

    # -- Step 1: Prerequisites -------------------------------------------------
    if (-not $SkipPrerequisites) {
        Write-Host '  [1/5] Checking prerequisites...' -ForegroundColor White

        if (-not (Test-ScoopInstalled)) {
            Write-Step 'Installing Scoop...'
            try {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
                Write-Ok 'Scoop installed'
            }
            catch {
                Write-Err "Failed to install Scoop: $_"
                Write-Err 'Install manually: https://scoop.sh'
                exit 1
            }
        }
        else {
            Write-Ok 'Scoop available'
        }

        if (-not (Test-GentleAiInstalled)) {
            Write-Step 'Installing gentle-ai via Scoop...'
            try {
                & scoop bucket add gentleman https://github.com/Gentleman-Programming/scoop-bucket 2>$null
                & scoop install gentle-ai
                Write-Ok 'gentle-ai installed'
            }
            catch {
                Write-Err "Failed to install gentle-ai: $_"
                exit 1
            }
        }
        else {
            if ($Update) {
                Write-Step 'Updating gentle-ai...'
                & scoop update gentle-ai
            }
            Write-Ok 'gentle-ai available'
        }

        if (-not (Test-EngramInstalled)) {
            Write-Warn 'Engram not found -- gentle-ai install will set it up'
        }
        else {
            Write-Ok 'engram available'
        }
    }
    else {
        Write-Host '  [1/5] Skipping prerequisites (SkipPrerequisites flag)' -ForegroundColor DarkGray
    }

    # -- Step 2: IDE Selection -------------------------------------------------
    Write-Host ''
    Write-Host '  [2/5] IDE Selection' -ForegroundColor White

    if (-not $Ide) {
        Write-Host '    1) VS Code + Copilot'
        Write-Host '    2) IntelliJ + Copilot'
        Write-Host '    3) OpenCode (CLI)'
        Write-Host ''

        do {
            $ideChoice = Read-Host '  Your IDE (1-3)'
        } while ($ideChoice -notin @('1', '2', '3'))

        $script:Ide = switch ($ideChoice) {
            '1' { 'vscode' }
            '2' { 'intellij' }
            '3' { 'opencode' }
        }
    }

    Write-Ok "IDE: $Ide"

    # -- Step 3: Role + Provider -----------------------------------------------
    Write-Host ''
    Write-Host '  [3/5] Role Selection' -ForegroundColor White

    if (-not $Role) {
        Write-Host '    1) Frontend (React / Next.js)'
        Write-Host '    2) Backend (Node.js / Express)'
        Write-Host '    3) DevOps (CI/CD / Docker / Infra)'
        Write-Host '    4) Python (FastAPI / Django)'
        Write-Host ''

        do {
            $roleChoice = Read-Host '  Your role (1-4)'
        } while ($roleChoice -notin @('1', '2', '3', '4'))

        $script:Role = switch ($roleChoice) {
            '1' { 'frontend' }
            '2' { 'backend-node' }
            '3' { 'devops' }
            '4' { 'python' }
        }
    }

    Write-Ok "Role: $Role"

    # Provider: auto-detect for Copilot IDEs, ask only for OpenCode
    if (-not $Provider) {
        if ($Ide -eq 'vscode' -or $Ide -eq 'intellij') {
            $script:Provider = 'github-copilot'
            Write-Ok "Provider: $Provider (auto-detected from IDE)"
        }
        else {
            Write-Host ''
            Write-Host '    AI Provider (OpenCode requires direct API access):' -ForegroundColor White
            Write-Host '    1) OpenAI'
            Write-Host '    2) Azure OpenAI'
            Write-Host '    3) Anthropic'
            Write-Host ''

            do {
                $providerChoice = Read-Host '  Your provider (1-3)'
            } while ($providerChoice -notin @('1', '2', '3'))

            $script:Provider = switch ($providerChoice) {
                '1' { 'openai' }
                '2' { 'azure-openai' }
                '3' { 'anthropic' }
            }
            Write-Ok "Provider: $Provider"
        }
    }
    else {
        Write-Ok "Provider: $Provider"
    }

    # -- Step 4: Base Configuration (gentle-ai) --------------------------------
    Write-Host ''
    Write-Host '  [4/5] Base configuration...' -ForegroundColor White

    $gentleAiAgentId = Get-GentleAiAgentId -Ide $Ide

    if ($gentleAiAgentId -and -not $SkipGentleAi) {
        Write-Step "Running: gentle-ai install --agent $gentleAiAgentId --preset ecosystem-only"
        Write-Step 'This installs: engram, SDD, skills, context7, persona'
        Write-Host ''

        try {
            $installArgs = @('install', '--agent', $gentleAiAgentId, '--preset', 'ecosystem-only', '--persona', 'gentleman')
            & gentle-ai @installArgs
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "gentle-ai configured for $gentleAiAgentId"
            }
            else {
                Write-Warn "gentle-ai install exited with code $LASTEXITCODE"
                Write-Warn 'You may need to run gentle-ai manually later'
            }
        }
        catch {
            Write-Warn "gentle-ai install failed: $_"
            Write-Warn 'Run gentle-ai manually after setup completes'
        }
    }
    elseif ($SkipGentleAi) {
        Write-Step 'Skipping gentle-ai install (SkipGentleAi flag)'
    }
    else {
        # IntelliJ: no gentle-ai adapter
        Write-Step 'IntelliJ + Copilot: no gentle-ai adapter available'
        Write-Step 'Setting up MCP config from template...'

        $templateDir = Get-TemplateDirectory -KitRoot $kitRoot -Ide $Ide
        if ($templateDir) {
            $engramBin = Get-EngramBinaryPath
            $templateVars = @{
                ENGRAM_BINARY_PATH = if ($engramBin) { $engramBin } else { '(not-found -- install engram via scoop)' }
            }

            $templateTargetDir = if ($TargetDir) { Join-Path $TargetDir 'ide-config' } else { $null }
            if ($templateTargetDir) {
                $createdTemplates = @(Install-Templates -TemplateDir $templateDir -TargetDir $templateTargetDir -Variables $templateVars)
                Write-Ok "$($createdTemplates.Count) IntelliJ config files generated"
            }
            else {
                # Show MCP config for manual setup
                $engramPath = if ($engramBin) { $engramBin } else { '(path-to-engram)' }
                $mcpJson = New-VsCodeMcpConfig -EngramBinaryPath $engramPath
                Write-Ok 'MCP config generated for IntelliJ'
                Write-Step 'Add this to your IntelliJ MCP settings:'
                Write-Host ''
                Write-Host $mcpJson -ForegroundColor DarkGray
                Write-Host ''
            }
        }
    }

    # -- Step 5: Team Layer ----------------------------------------------------
    Write-Host ''
    Write-Host '  [5/5] Installing team layer...' -ForegroundColor White

    # 5a. Copy role skills to IDE skills directory
    if ($TargetDir) {
        $targetSkillsDir = $TargetDir
    }
    else {
        $targetSkillsDir = Get-IdeSkillsDirectory -Ide $Ide
    }

    Write-Step "Skills target: $targetSkillsDir"

    $copiedSkills = Install-TeamSkills -KitRoot $kitRoot -Role $Role -TargetDir $targetSkillsDir
    Write-Ok "$($copiedSkills.Count) team skills installed for role: $Role"

    # 5b. Generate project-level instructions (to be committed to repos)
    $packRulesPath = Get-PackRulesPath -KitRoot $kitRoot -Role $Role
    $packRulesContent = ''
    if ($packRulesPath) {
        $packRulesContent = Get-Content -Path $packRulesPath -Raw
    }
    $instructions = New-CopilotInstructions -Role $Role -PackRulesContent $packRulesContent
    Write-Ok "Project instructions generated for role: $Role"
    Write-Step 'Add to each repo: .github/copilot-instructions.md (or AGENTS.md for OpenCode)'

    # -- Save config -----------------------------------------------------------
    $now = Get-Date -Format 'o'
    $config = @{
        ide         = $Ide
        role        = $Role
        provider    = $Provider
        teamRepo    = $TeamRepo
        installedAt = $now
        lastUpdate  = $now
        version     = '2.0.0'
    }
    $configPath = Save-TeamAiKitConfig -Config $config
    Write-Ok "Config saved: $configPath"

    # -- Summary ---------------------------------------------------------------
    Write-Host ''
    $gentleAiStatus = if ($gentleAiAgentId -and -not $SkipGentleAi) { 'configured' } else { 'manual setup' }
    $summary = New-SetupSummary -Ide $Ide -Role $Role -Provider $Provider -SkillsCopied $copiedSkills.Count -GentleAiStatus $gentleAiStatus
    Write-Host $summary -ForegroundColor Green

    Write-Host ''
    Write-Host '  Next steps:' -ForegroundColor Yellow
    if ($gentleAiAgentId -and -not $SkipGentleAi) {
        Write-Host '    1. Configure engram sync to your team repo:' -ForegroundColor White
        Write-Host '       engram sync                  (export after sessions)' -ForegroundColor DarkGray
        Write-Host '       engram sync --import          (import team knowledge)' -ForegroundColor DarkGray
        Write-Host '    2. Add .github/copilot-instructions.md to your project repos' -ForegroundColor White
        Write-Host '    3. Open your IDE and start working!' -ForegroundColor White
    }
    elseif ($Ide -eq 'intellij') {
        Write-Host '    1. Add the MCP config shown above to IntelliJ settings' -ForegroundColor White
        Write-Host '    2. Configure engram sync to your team repo' -ForegroundColor White
        Write-Host '    3. Add .github/copilot-instructions.md to your project repos' -ForegroundColor White
        Write-Host '    4. Open IntelliJ and start working!' -ForegroundColor White
    }
    else {
        Write-Host '    1. Run gentle-ai to complete agent configuration' -ForegroundColor White
        Write-Host '    2. Configure engram sync to your team repo' -ForegroundColor White
        Write-Host '    3. Add .github/copilot-instructions.md to your project repos' -ForegroundColor White
        Write-Host '    4. Open your IDE and start working!' -ForegroundColor White
    }
    Write-Host ''
}

# -- Update (Phase 2 placeholder) ---------------------------------------------
function Invoke-UpdateCommand {
    Show-Banner
    $config = Get-TeamAiKitConfig
    if (-not $config.ide) {
        Write-Err 'No configuration found. Run "team-ai-kit setup" first.'
        exit 1
    }

    Write-Step "Current config: IDE=$($config.ide), Role=$($config.role)"

    if ($config.teamRepo) {
        Write-Step "Team repo: $($config.teamRepo)"
        Write-Warn 'Team repo sync not yet implemented (Phase 2)'
    }
    else {
        Write-Warn 'No team repo configured. Run "team-ai-kit setup -TeamRepo <url>" to add one.'
    }

    # Re-install default skills without overwriting (Phase 2: full merge logic)
    Write-Step 'Re-applying default skills for role...'
    if ($TargetDir) {
        $targetSkillsDir = $TargetDir
    }
    else {
        $targetSkillsDir = Get-IdeSkillsDirectory -Ide $config.ide
    }
    $copiedSkills = Install-TeamSkills -KitRoot $kitRoot -Role $config.role -TargetDir $targetSkillsDir
    Write-Ok "$($copiedSkills.Count) team skills applied for role: $($config.role)"

    # Update timestamp
    $config.lastUpdate = Get-Date -Format 'o'
    Save-TeamAiKitConfig -Config $config | Out-Null
    Write-Ok 'Config updated'
    Write-Host ''
}

# -- Status --------------------------------------------------------------------
function Invoke-StatusCommand {
    Show-Banner
    $config = Get-TeamAiKitConfig

    if (-not $config.ide) {
        Write-Warn 'Not configured yet. Run "team-ai-kit setup" first.'
        Write-Host ''
        return
    }

    Write-Host '  Configuration:' -ForegroundColor White
    Write-Host "    IDE:         $($config.ide)"
    Write-Host "    Role:        $($config.role)"
    Write-Host "    Provider:    $($config.provider)"
    Write-Host "    Team Repo:   $(if ($config.teamRepo) { $config.teamRepo } else { '(none)' })"
    Write-Host "    Installed:   $($config.installedAt)"
    Write-Host "    Last Update: $($config.lastUpdate)"
    Write-Host "    Version:     $(if ($config.version) { $config.version } else { 'unknown' })"
    Write-Host ''

    # Show installed skills
    $skillsDir = Get-IdeSkillsDirectory -Ide $config.ide
    $teamSkillsDir = Join-Path $skillsDir 'team-skills'
    if (Test-Path $teamSkillsDir) {
        $skillFiles = @(Get-ChildItem -Path $teamSkillsDir -Filter '*.md' -Recurse)
        Write-Host "  Installed Skills: $($skillFiles.Count)" -ForegroundColor White
        foreach ($skill in $skillFiles) {
            $relativePath = $skill.FullName.Replace($teamSkillsDir, '').TrimStart('\', '/')
            Write-Host "    - $relativePath" -ForegroundColor DarkGray
        }
    }
    else {
        Write-Warn "  Skills directory not found: $teamSkillsDir"
    }
    Write-Host ''
}

# -- Doctor --------------------------------------------------------------------
function Invoke-DoctorCommand {
    Show-Banner
    Write-Host '  Checking installation health...' -ForegroundColor White
    Write-Host ''

    $allGood = $true

    # Scoop
    if (Test-ScoopInstalled) { Write-Ok 'Scoop: installed' }
    else { Write-Err 'Scoop: NOT found'; $allGood = $false }

    # gentle-ai
    if (Test-GentleAiInstalled) { Write-Ok 'gentle-ai: installed' }
    else { Write-Err 'gentle-ai: NOT found'; $allGood = $false }

    # engram
    if (Test-EngramInstalled) { Write-Ok 'engram: installed' }
    else { Write-Err 'engram: NOT found'; $allGood = $false }

    # Config
    $config = Get-TeamAiKitConfig
    if ($config.ide) {
        Write-Ok "Config: found (IDE=$($config.ide), Role=$($config.role))"
    }
    else {
        Write-Warn 'Config: not configured (run "team-ai-kit setup")'
    }

    # Skills directory
    if ($config.ide) {
        $skillsDir = Get-IdeSkillsDirectory -Ide $config.ide
        $teamSkillsDir = Join-Path $skillsDir 'team-skills'
        if (Test-Path $teamSkillsDir) {
            $count = @(Get-ChildItem -Path $teamSkillsDir -Filter '*.md' -Recurse).Count
            Write-Ok "Team skills: $count files in $teamSkillsDir"
        }
        else {
            Write-Warn "Team skills: directory not found ($teamSkillsDir)"
        }
    }

    # Team repo
    if ($config.teamRepo) {
        Write-Ok "Team repo: $($config.teamRepo)"
    }
    else {
        Write-Warn 'Team repo: not configured'
    }

    Write-Host ''
    if ($allGood) {
        Write-Ok 'All checks passed!'
    }
    else {
        Write-Err 'Some checks failed. Fix the issues above and run doctor again.'
    }
    Write-Host ''
}

# -- Route subcommand ----------------------------------------------------------
switch ($Command.ToLower()) {
    'setup'  { Invoke-SetupCommand }
    'update' { Invoke-UpdateCommand }
    'status' { Invoke-StatusCommand }
    'doctor' { Invoke-DoctorCommand }
    'help'   { Show-Help }
    default  {
        Write-Host "  Unknown command: $Command" -ForegroundColor Red
        Write-Host '  Run "team-ai-kit help" for available commands.' -ForegroundColor Yellow
        Write-Host ''
        exit 1
    }
}
