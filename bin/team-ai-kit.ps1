#Requires -Version 5.1
<#
.SYNOPSIS
    Team AI Kit CLI -- gentle-ai for teams.
.DESCRIPTION
    One-command setup for your team's AI development environment.
    Installs gentle-ai as base layer, adds team-specific role skills
    and configuration on top.

    Subcommands:
      setup          - First-time configuration (interactive or non-interactive)
      init           - Initialize team-ai-kit in the current project directory
      init-knowledge - Scaffold a Team Knowledge Repo in the current directory
      sync           - Manually sync engram memories (export + import)
      update         - Pull latest team content and merge without overwriting
      status         - Show current configuration and installed skills
      doctor         - Verify prerequisites and installation health
      help           - Show this help message
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
    team-ai-kit init-knowledge
    Scaffold a Team Knowledge Repo in the current directory.
.EXAMPLE
    team-ai-kit init
    Initialize team-ai-kit in the current project (uses global role).
.EXAMPLE
    team-ai-kit init -Role backend-node
    Initialize with a role override for this specific project.
.EXAMPLE
    team-ai-kit init -TeamRepo https://dev.azure.com/equipo/team-knowledge
    Initialize with a per-project team knowledge repo.
.EXAMPLE
    team-ai-kit init -Role frontend -Force
    Re-initialize an already configured project.
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

    [switch]$Update,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -- Kit version ---------------------------------------------------------------
# Single source of truth. Bump this on every release.
$KitVersion = '2.6.3'

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
    Write-Host '    setup           First-time configuration (IDE, role, team repo)'
    Write-Host '    init            Initialize team-ai-kit in the current project'
    Write-Host '    init-knowledge  Scaffold a Team Knowledge Repo in the current directory'
    Write-Host '    sync            Manually sync engram memories (export + import)'
    Write-Host '    update   Pull latest team content + merge without overwriting'
    Write-Host '    status   Show current config and installed skills'
    Write-Host '    doctor   Verify prerequisites and installation health'
    Write-Host '    help     Show this help message'
    Write-Host ''
    Write-Host '  Setup options:' -ForegroundColor Yellow
    Write-Host '    -Ide <vscode|intellij|opencode|cursor>'
    Write-Host '    -Role <frontend|backend-node|devops|python>'
    Write-Host '    -Provider <openai|azure-openai|anthropic|github-copilot>'
    Write-Host '    -TeamRepo <url>          Team content repo URL'
    Write-Host '    -TargetDir <path>        Custom output directory'
    Write-Host '    -SkipPrerequisites       Skip gentle-ai/engram auto-install'
    Write-Host '    -SkipGentleAi            Skip gentle-ai install step'
    Write-Host ''
    Write-Host '  Init options:' -ForegroundColor Yellow
    Write-Host '    -Role <role>             Override global role for this project'
    Write-Host '    -Force                   Re-initialize without asking'
    Write-Host ''
    Write-Host '  Examples:' -ForegroundColor Yellow
    Write-Host '    team-ai-kit setup'
    Write-Host '    team-ai-kit setup -Ide vscode -Role frontend'
    Write-Host '    team-ai-kit setup -Ide vscode -Role frontend -TeamRepo https://dev.azure.com/equipo/team-knowledge'
    Write-Host '    team-ai-kit init'
    Write-Host '    team-ai-kit init -Role backend-node'
    Write-Host '    team-ai-kit init -Role frontend -Force'
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

        Set-TlsProtocol

        # -- gentle-ai --
        if (Test-GentleAiInstalled) {
            if ($Update -and (Test-ScoopInstalled)) {
                Write-Step 'Updating gentle-ai...'
                try { & scoop update gentle-ai }
                catch { Write-Warn "Failed to update gentle-ai: $_" }
            }
            Write-Ok 'gentle-ai available'
        }
        elseif (Test-ScoopInstalled) {
            Write-Step 'Installing gentle-ai via Scoop...'
            try {
                & scoop bucket add team-ai-kit https://github.com/lazarogadiel93/scoop-bucket 2>$null
                & scoop install gentle-ai
                Write-Ok 'gentle-ai installed via Scoop'
            }
            catch {
                Write-Warn "Scoop install failed: $_ -- trying direct download..."
                try {
                    $dlResult = Install-GithubReleaseBinary -Owner 'Gentleman-Programming' -Repo 'gentle-ai' -BinaryName 'gentle-ai'
                    $null = Add-ToUserPath -Directory (Get-DirectDownloadBinDir)
                    Write-Ok "gentle-ai $($dlResult.version) installed via direct download"
                }
                catch {
                    Write-Err "Failed to install gentle-ai: $_"
                    exit 1
                }
            }
        }
        else {
            Write-Step 'Scoop not available -- downloading gentle-ai directly...'
            try {
                $dlResult = Install-GithubReleaseBinary -Owner 'Gentleman-Programming' -Repo 'gentle-ai' -BinaryName 'gentle-ai'
                $null = Add-ToUserPath -Directory (Get-DirectDownloadBinDir)
                Write-Ok "gentle-ai $($dlResult.version) installed via direct download"
            }
            catch {
                Write-Err "Failed to install gentle-ai: $_"
                Write-Err 'Download manually from: https://github.com/Gentleman-Programming/gentle-ai/releases'
                exit 1
            }
        }

        # -- engram --
        if (Test-EngramInstalled) {
            if ($Update -and (Test-ScoopInstalled)) {
                Write-Step 'Updating engram...'
                try { & scoop update engram }
                catch { Write-Warn "Failed to update engram: $_" }
            }
            Write-Ok 'engram available'
        }
        else {
            Write-Step 'Installing engram...'
            if (Test-ScoopInstalled) {
                try {
                    & scoop bucket add team-ai-kit https://github.com/lazarogadiel93/scoop-bucket 2>$null
                    & scoop install engram 2>$null
                    Write-Ok 'engram installed via Scoop'
                }
                catch {
                    Write-Warn "Scoop install failed -- trying direct download..."
                    try {
                        $dlResult = Install-GithubReleaseBinary -Owner 'Gentleman-Programming' -Repo 'engram' -BinaryName 'engram'
                        $null = Add-ToUserPath -Directory (Get-DirectDownloadBinDir)
                        Write-Ok "engram $($dlResult.version) installed via direct download"
                    }
                    catch {
                        Write-Warn "Failed to install engram: $_ -- gentle-ai install will set it up"
                    }
                }
            }
            else {
                try {
                    $dlResult = Install-GithubReleaseBinary -Owner 'Gentleman-Programming' -Repo 'engram' -BinaryName 'engram'
                    $null = Add-ToUserPath -Directory (Get-DirectDownloadBinDir)
                    Write-Ok "engram $($dlResult.version) installed via direct download"
                }
                catch {
                    Write-Warn "Failed to install engram: $_ -- gentle-ai install will set it up"
                }
            }
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
        Write-Host '    4) Cursor'
        Write-Host ''

        do {
            $ideChoice = Read-Host '  Your IDE (1-4)'
        } while ($ideChoice -notin @('1', '2', '3', '4'))

        $script:Ide = switch ($ideChoice) {
            '1' { 'vscode' }
            '2' { 'intellij' }
            '3' { 'opencode' }
            '4' { 'cursor' }
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
        if ($Ide -eq 'vscode' -or $Ide -eq 'intellij' -or $Ide -eq 'cursor') {
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
            $gentleBin = Get-GentleAiBinaryPath
            $installArgs = @('install', '--agent', $gentleAiAgentId, '--preset', 'ecosystem-only', '--persona', 'gentleman')
            & $gentleBin @installArgs
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
        # IDE without gentle-ai adapter -- manual MCP setup
        $ideNames = @{ 'intellij' = 'IntelliJ + Copilot' }
        $ideName = if ($ideNames.ContainsKey($Ide.ToLower())) { $ideNames[$Ide.ToLower()] } else { $Ide }
        Write-Step "$ideName`: no gentle-ai adapter available"
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
                Write-Ok "$($createdTemplates.Count) $ideName config files generated"
            }
            else {
                # Show MCP config for manual setup
                $engramPath = if ($engramBin) { $engramBin } else { '(path-to-engram)' }
                if ($Ide -eq 'intellij') {
                    $mcpJson = New-IntelliJMcpConfig -EngramBinaryPath $engramPath
                }
                else {
                    $mcpJson = New-VsCodeMcpConfig -EngramBinaryPath $engramPath
                }
                Write-Ok "MCP config generated for $ideName"
                Write-Step "Add this to your $ideName MCP settings:"
                Write-Host ''
                Write-Host $mcpJson -ForegroundColor DarkGray
                Write-Host ''
            }
        }
    }

    # -- Step 5: Team Layer ----------------------------------------------------
    Write-Host ''
    Write-Host '  [5/5] Installing team layer...' -ForegroundColor White

    # 5a. Clone team repo if configured
    $hasTeamRepo = $false
    if ($TeamRepo) {
        Write-Step "Cloning team repo: $TeamRepo"
        $cloneOk = Invoke-TeamRepoClone -RepoUrl $TeamRepo
        if ($cloneOk) {
            Write-Ok 'Team repo cloned'
            $hasTeamRepo = $true
        }
        else {
            Write-Warn 'Failed to clone team repo -- continuing with defaults only'
        }
    }

    # 5b. Install kit base skills to global (team-repo skills go to project via init)
    if ($TargetDir) {
        $targetSkillsDir = $TargetDir
    }
    else {
        $targetSkillsDir = Get-IdeSkillsDirectory -Ide $Ide
    }

    Write-Step "Global skills target: $targetSkillsDir"

    $mergeParams = @{
        KitRoot   = $kitRoot
        Role      = $Role
        TargetDir = $targetSkillsDir
    }

    $mergeResults = Install-SkillsWithMerge @mergeParams
    $totalInstalled = $mergeResults.installed.Count
    $totalUpdated = $mergeResults.updated.Count
    $totalSkipped = $mergeResults.skipped.Count
    Write-Ok "$totalInstalled installed, $totalUpdated updated, $totalSkipped unchanged"

    # 5c. Generate project-level instructions (to be committed to repos)
    $packRulesPath = Get-PackRulesPath -KitRoot $kitRoot -Role $Role
    $packRulesContent = ''
    if ($packRulesPath) {
        $packRulesContent = Get-Content -Path $packRulesPath -Raw
    }
    $skipProtocol = Test-GentleAiSupportsIde -Ide $Ide
    $instructions = New-CopilotInstructions -Role $Role -PackRulesContent $packRulesContent -SkipEngramProtocol:$skipProtocol
    Write-Ok "Project instructions generated for role: $Role"
    Write-Step 'Run "team-ai-kit init" in each project to apply instructions'

    # -- Save config -----------------------------------------------------------
    $now = Get-Date -Format 'o'
    $config = @{
        ide         = $Ide
        role        = $Role
        provider    = $Provider
        teamRepo    = $TeamRepo
        installedAt = $now
        lastUpdate  = $now
        version     = $KitVersion
    }
    $configPath = Save-TeamAiKitConfig -Config $config
    Write-Ok "Config saved: $configPath"

    # -- Summary ---------------------------------------------------------------
    Write-Host ''
    $gentleAiStatus = if ($gentleAiAgentId -and -not $SkipGentleAi) { 'configured' } else { 'manual setup' }
    $summary = New-SetupSummary -Ide $Ide -Role $Role -Provider $Provider -SkillsCopied ($totalInstalled + $totalUpdated) -GentleAiStatus $gentleAiStatus
    Write-Host $summary -ForegroundColor Green

    Write-Host ''
    Write-Host '  Next steps:' -ForegroundColor Yellow
    if ($gentleAiAgentId -and -not $SkipGentleAi) {
        Write-Host '    1. Go to your project and run: team-ai-kit init' -ForegroundColor White
        Write-Host '       (configures instructions, team skills, engram sync, and git hooks)' -ForegroundColor DarkGray
        Write-Host '    2. Open your IDE and start working!' -ForegroundColor White
    }
    elseif (-not (Test-GentleAiSupportsIde -Ide $Ide)) {
        Write-Host '    1. Add the MCP config shown above to your IDE settings' -ForegroundColor White
        Write-Host '    2. Go to your project and run: team-ai-kit init' -ForegroundColor White
        Write-Host '       (configures instructions, team skills, engram sync, and git hooks)' -ForegroundColor DarkGray
        Write-Host '    3. Open your IDE and start working!' -ForegroundColor White
    }
    else {
        Write-Host '    1. Run gentle-ai to complete agent configuration' -ForegroundColor White
        Write-Host '    2. Go to your project and run: team-ai-kit init' -ForegroundColor White
        Write-Host '       (configures instructions, team skills, engram sync, and git hooks)' -ForegroundColor DarkGray
        Write-Host '    3. Open your IDE and start working!' -ForegroundColor White
    }
    Write-Host ''
}

# -- Init (project-level) -----------------------------------------------------
function Invoke-InitCommand {
    Show-Banner
    $projectRoot = (Get-Location).Path

    # -- Step 1: Check global config -------------------------------------------
    Write-Host '  [1/4] Checking global configuration...' -ForegroundColor White
    $globalConfig = Get-TeamAiKitConfig
    if (-not $globalConfig.ide) {
        Write-Err 'No global configuration found.'
        Write-Err 'Run "team-ai-kit setup" first to configure your IDE and role.'
        exit 1
    }
    Write-Ok "Global config: IDE=$($globalConfig.ide), Role=$($globalConfig.role)"

    # -- Step 2: Check if already initialized ----------------------------------
    Write-Host ''
    Write-Host '  [2/4] Checking project state...' -ForegroundColor White

    $existingConfig = $null
    if (Test-ProjectInitialized -ProjectRoot $projectRoot) {
        $existingConfig = Get-ProjectConfig -ProjectRoot $projectRoot

        if ($Force) {
            Write-Warn "Already initialized (Role=$($existingConfig.role)). Re-initializing (--Force)."
        }
        elseif (-not $Role -and -not $Ide) {
            # Interactive mode: show config and ask
            Write-Warn 'This project is already initialized:'
            Write-Host "    Role:        $($existingConfig.role)" -ForegroundColor DarkGray
            Write-Host "    IDE:         $($existingConfig.ide)" -ForegroundColor DarkGray
            Write-Host "    Initialized: $($existingConfig.initializedAt)" -ForegroundColor DarkGray
            Write-Host ''
            $answer = Read-Host '  Want to re-initialize? (y/n)'
            if ($answer -notin @('y', 'Y', 'yes', 'Yes')) {
                Write-Step 'Cancelled. Run "team-ai-kit update" to pull latest changes instead.'
                return
            }
        }
        else {
            # Non-interactive: fail with clear message
            Write-Err 'Project already initialized. Use -Force to re-initialize.'
            Write-Host "    Current role: $($existingConfig.role)" -ForegroundColor DarkGray
            exit 1
        }
    }
    else {
        Write-Ok 'New project -- initializing'
    }

    # -- Resolve effective role ------------------------------------------------
    $effectiveRole = if ($Role) { $Role } else { $globalConfig.role }
    $effectiveIde = $globalConfig.ide
    Write-Ok "Role for this project: $effectiveRole"

    # -- Step 3: Generate project files ----------------------------------------
    Write-Host ''
    Write-Host '  [3/4] Generating project files...' -ForegroundColor White

    # 3a. Instructions file
    $instructionsPath = Get-IdeInstructionsPath -Ide $effectiveIde -ProjectRoot $projectRoot
    $instructionsDir = Split-Path $instructionsPath -Parent
    if (-not (Test-Path $instructionsDir)) {
        New-Item -ItemType Directory -Path $instructionsDir -Force | Out-Null
    }

    $packRulesPath = Get-PackRulesPath -KitRoot $kitRoot -Role $effectiveRole
    $packRulesContent = ''
    if ($packRulesPath) {
        $packRulesContent = Get-Content -Path $packRulesPath -Raw
    }

    # Resolve team repo URL: CLI param > project config > global config
    $effectiveTeamRepo = if ($TeamRepo) { $TeamRepo }
        elseif ($existingConfig -and $existingConfig.teamRepo) { $existingConfig.teamRepo }
        else {
            $gc = Get-TeamAiKitConfig
            if ($gc.teamRepo) { $gc.teamRepo } else { '' }
        }

    # Clone/pull team repo if configured
    $teamRulesContent = ''
    if ($effectiveTeamRepo) {
        Write-Step "Team repo: $effectiveTeamRepo"
        if (Test-TeamRepoCloned -RepoUrl $effectiveTeamRepo) {
            $pullOk = Invoke-TeamRepoPull -RepoUrl $effectiveTeamRepo
            if ($pullOk) { Write-Ok 'Team repo updated' }
            else { Write-Warn 'Failed to pull -- using cached version' }
        }
        else {
            $cloneOk = Invoke-TeamRepoClone -RepoUrl $effectiveTeamRepo
            if ($cloneOk) { Write-Ok 'Team repo cloned' }
            else { Write-Warn 'Failed to clone team repo' }
        }
        $teamRulesContent = Get-TeamRepoRulesContent -RepoUrl $effectiveTeamRepo
        if ($teamRulesContent) {
            Write-Ok 'Team rules loaded from knowledge repo'
        }
    }

    $skipProtocol = Test-GentleAiSupportsIde -Ide $effectiveIde
    $instructions = New-CopilotInstructions -Role $effectiveRole -PackRulesContent $packRulesContent -TeamRulesContent $teamRulesContent -SkipEngramProtocol:$skipProtocol
    [System.IO.File]::WriteAllText($instructionsPath, $instructions, [System.Text.Encoding]::UTF8)
    $relInstructionsPath = $instructionsPath.Replace($projectRoot, '').TrimStart('\', '/')
    Write-Ok "Created: $relInstructionsPath"

    # 3b. Install team-repo skills to project-level directory
    if ($effectiveTeamRepo -and (Test-TeamRepoCloned -RepoUrl $effectiveTeamRepo)) {
        $projectSkillsDir = Get-IdeProjectSkillsDirectory -Ide $effectiveIde -ProjectRoot $projectRoot
        Write-Step "Installing team skills to project: $($projectSkillsDir.Replace($projectRoot, '').TrimStart('\', '/'))"

        $projectSkillResults = Install-ProjectSkills -Role $effectiveRole -TeamRepoUrl $effectiveTeamRepo -TargetDir $projectSkillsDir
        $pTotal = $projectSkillResults.installed + $projectSkillResults.updated
        if ($pTotal -gt 0) {
            Write-Ok "$($projectSkillResults.installed) installed, $($projectSkillResults.updated) updated team skills"
        }
        else {
            Write-Step 'No team skills to install (repo has no skills for this role)'
        }
    }

    # -- Step 4: Setup engram sync + git hooks --------------------------------
    Write-Host ''
    Write-Host '  [4/4] Setting up engram sync and git hooks...' -ForegroundColor White

    # Derive project name from directory
    $projectName = Split-Path $projectRoot -Leaf

    # 4a. Run initial engram sync
    $engramResult = Initialize-EngramSync -ProjectRoot $projectRoot -ProjectName $projectName

    if ($engramResult.synced) {
        Write-Ok 'engram sync completed -- .engram/ ready for team sharing'
    }
    elseif (Test-EngramInstalled) {
        Write-Ok 'engram sync attempted -- no memories for this project yet'
    }
    else {
        Write-Ok '.engram/ will be created on first sync'
        Write-Warn 'engram not installed -- sync will work after installing engram'
    }

    # 4b. Install git hooks
    $hookResult = Install-GitHooks -ProjectRoot $projectRoot -ProjectName $projectName

    if ($hookResult.installed.Count -gt 0) {
        Write-Ok "Git hooks installed: $($hookResult.installed -join ', ')"
    }
    if ($hookResult.skipped -contains 'not-a-git-repo') {
        Write-Warn 'Not a git repo -- hooks skipped'
    }
    elseif ($hookResult.skipped.Count -gt 0) {
        Write-Step "Git hooks already present: $($hookResult.skipped -join ', ')"
    }

    # -- Save project config ---------------------------------------------------
    $now = Get-Date -Format 'o'
    $projectConfig = @{
        role          = $effectiveRole
        ide           = $effectiveIde
        teamRepo      = $effectiveTeamRepo
        initializedAt = $now
        lastSync      = $now
        version       = $KitVersion
    }
    $null = Save-ProjectConfig -ProjectRoot $projectRoot -Config $projectConfig
    Write-Ok 'Project config saved: .team-ai-kit.json'

    # -- Summary ---------------------------------------------------------------
    Write-Host ''
    $summary = New-InitSummary -Ide $effectiveIde -Role $effectiveRole -InstructionsPath $relInstructionsPath -EngramSynced $engramResult.synced -HooksInstalled $hookResult.installed.Count
    Write-Host $summary -ForegroundColor Green

    Write-Host ''
    Write-Host '  Next steps:' -ForegroundColor Yellow
    Write-Host "    1. Commit .team-ai-kit.json and $relInstructionsPath to your repo" -ForegroundColor White
    if ($effectiveTeamRepo) {
        $relSkillsDir = (Get-IdeProjectSkillsDirectory -Ide $effectiveIde -ProjectRoot $projectRoot).Replace($projectRoot, '').TrimStart('\', '/')
        Write-Host "    2. Commit $relSkillsDir/ (team skills for this project)" -ForegroundColor White
        Write-Host '    3. Commit .engram/ to share knowledge with your team' -ForegroundColor White
        Write-Host '    4. Start working -- git hooks will sync engram automatically!' -ForegroundColor White
    }
    else {
        Write-Host '    2. Commit .engram/ to share knowledge with your team' -ForegroundColor White
        Write-Host '    3. Start working -- git hooks will sync engram automatically!' -ForegroundColor White
    }
    Write-Host '       (manual sync: team-ai-kit sync)' -ForegroundColor DarkGray
    Write-Host ''
}

# -- Init Knowledge (scaffold team knowledge repo) ----------------------------
function Invoke-InitKnowledgeCommand {
    Show-Banner
    $targetDir = (Get-Location).Path

    Write-Host '  Scaffolding Team Knowledge Repo...' -ForegroundColor White
    Write-Host ''

    $result = Initialize-KnowledgeRepo -TargetDir $targetDir

    if ($result.created.Count -eq 0) {
        Write-Warn 'All directories already exist. Nothing to create.'
    }
    else {
        foreach ($dir in $result.created) {
            Write-Ok "Created: $dir"
        }
    }

    Write-Host ''
    Write-Ok 'Team Knowledge Repo ready!'
    Write-Host ''
    Write-Host '  Structure:' -ForegroundColor Yellow
    Write-Host '    skills/shared/<name>/SKILL.md    Skills for ALL roles' -ForegroundColor White
    Write-Host '    skills/roles/<role>/<name>/SKILL.md    Role-specific skills' -ForegroundColor White
    Write-Host '    rules/            Cross-project rules' -ForegroundColor White
    Write-Host ''
    Write-Host '  Next steps:' -ForegroundColor Yellow
    Write-Host '    1. Add skills as folders: skills/shared/<name>/SKILL.md or skills/roles/<role>/<name>/SKILL.md' -ForegroundColor White
    Write-Host '    2. Add rules to rules/' -ForegroundColor White
    Write-Host '    3. git init && git add . && git commit && git push' -ForegroundColor White
    Write-Host '    4. Share the repo URL with your team:' -ForegroundColor White
    Write-Host '       team-ai-kit setup -TeamRepo <url>' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Docs: https://github.com/lazarogadiel93/team-ai-kit/blob/master/docs/team-knowledge-repo.md' -ForegroundColor DarkGray
    Write-Host ''
}

# -- Sync (manual engram sync) -------------------------------------------------
function Invoke-SyncCommand {
    Show-Banner
    $projectRoot = (Get-Location).Path

    # Check project config for project name
    $projectName = ''
    if (Test-ProjectInitialized -ProjectRoot $projectRoot) {
        $projectName = Split-Path $projectRoot -Leaf
    }

    Write-Host '  Syncing engram memories...' -ForegroundColor White
    Write-Host ''

    # Export
    Write-Step 'Exporting local memories...'
    $exportResult = Invoke-EngramSync -ProjectName $projectName -Operation 'export'
    if ($exportResult.success) {
        Write-Ok $exportResult.message
    }
    else {
        Write-Warn $exportResult.message
    }

    # Import
    Write-Step 'Importing team memories...'
    $importResult = Invoke-EngramSync -Operation 'import'
    if ($importResult.success) {
        Write-Ok $importResult.message
    }
    else {
        Write-Warn $importResult.message
    }

    Write-Host ''
    if ($exportResult.success -or $importResult.success) {
        Write-Ok 'Sync complete'
    }
    else {
        Write-Err 'Sync failed -- is engram installed? Run "team-ai-kit doctor" to check.'
    }
    Write-Host ''
}

# -- Update --------------------------------------------------------------------
function Invoke-UpdateCommand {
    Show-Banner
    $config = Get-TeamAiKitConfig
    if (-not $config.ide) {
        Write-Err 'No configuration found. Run "team-ai-kit setup" first.'
        exit 1
    }

    # Resolve team repo: project config > global config
    $projectRoot = (Get-Location).Path
    $projectConfig = $null
    if (Test-ProjectInitialized -ProjectRoot $projectRoot) {
        $projectConfig = Get-ProjectConfig -ProjectRoot $projectRoot
    }
    $effectiveTeamRepo = if ($projectConfig -and $projectConfig.teamRepo) { $projectConfig.teamRepo }
        elseif ($config.teamRepo) { $config.teamRepo }
        else { '' }

    Write-Host "  Updating for: IDE=$($config.ide), Role=$($config.role)" -ForegroundColor White
    Write-Host ''

    # Step 1: Pull team repo if configured
    $hasTeamRepo = $false
    if ($effectiveTeamRepo) {
        Write-Step "Pulling team repo: $effectiveTeamRepo"
        if (Test-TeamRepoCloned -RepoUrl $effectiveTeamRepo) {
            $pullOk = Invoke-TeamRepoPull -RepoUrl $effectiveTeamRepo
            if ($pullOk) {
                Write-Ok 'Team repo updated'
                $hasTeamRepo = $true
            }
            else {
                Write-Warn 'Failed to pull team repo -- continuing with cached version'
                $hasTeamRepo = $true  # still use cached clone
            }
        }
        else {
            Write-Step 'Team repo not cloned yet -- cloning...'
            $cloneOk = Invoke-TeamRepoClone -RepoUrl $effectiveTeamRepo
            if ($cloneOk) {
                Write-Ok 'Team repo cloned'
                $hasTeamRepo = $true
            }
            else {
                Write-Warn 'Failed to clone team repo -- continuing with defaults only'
            }
        }
        # Safety net: if a cached clone exists from a previous run, use it
        if (-not $hasTeamRepo -and (Test-TeamRepoCloned -RepoUrl $effectiveTeamRepo)) {
            $hasTeamRepo = $true
        }
    }
    else {
        Write-Step 'No team repo configured (use "team-ai-kit setup -TeamRepo <url>" to add one)'
    }

    # Step 2: Merge kit base skills to global (no team-repo layer)
    if ($TargetDir) {
        $targetSkillsDir = $TargetDir
    }
    else {
        $targetSkillsDir = Get-IdeSkillsDirectory -Ide $config.ide
    }

    Write-Step "Merging kit base skills to global: $targetSkillsDir"

    $mergeParams = @{
        KitRoot   = $kitRoot
        Role      = $config.role
        TargetDir = $targetSkillsDir
    }

    $mergeResults = Install-SkillsWithMerge @mergeParams

    Write-Host ''
    Write-Ok "Installed: $($mergeResults.installed.Count) new skills"
    if ($mergeResults.updated.Count -gt 0) {
        Write-Ok "Updated:   $($mergeResults.updated.Count) skills (source changed, yours untouched)"
    }
    if ($mergeResults.skipped.Count -gt 0) {
        Write-Step "Unchanged: $($mergeResults.skipped.Count) skills (already up to date or user-modified)"
    }

    # Step 2b: Install team-repo skills to project-level directory
    if ($hasTeamRepo -and $projectConfig) {
        $effectiveIde = if ($projectConfig.ide) { $projectConfig.ide } else { $config.ide }
        $effectiveRole = if ($projectConfig.role) { $projectConfig.role } else { $config.role }
        $projectSkillsDir = Get-IdeProjectSkillsDirectory -Ide $effectiveIde -ProjectRoot $projectRoot

        Write-Host ''
        Write-Step "Merging team skills to project: $($projectSkillsDir.Replace($projectRoot, '').TrimStart('\', '/'))"

        $projectSkillResults = Install-ProjectSkills -Role $effectiveRole -TeamRepoUrl $effectiveTeamRepo -TargetDir $projectSkillsDir
        if ($projectSkillResults.installed -gt 0) {
            Write-Ok "Installed: $($projectSkillResults.installed) new team skills"
        }
        if ($projectSkillResults.updated -gt 0) {
            Write-Ok "Updated:   $($projectSkillResults.updated) team skills"
        }
        if ($projectSkillResults.skipped -gt 0) {
            Write-Step "Unchanged: $($projectSkillResults.skipped) team skills"
        }
    }

    # Step 3: Auto-update team rules in instructions if project is initialized
    if ($hasTeamRepo -and $projectConfig) {
        $teamRulesContent = Get-TeamRepoRulesContent -RepoUrl $effectiveTeamRepo
        if ($teamRulesContent) {
            $instructionsPath = Get-IdeInstructionsPath -Ide $config.ide -ProjectRoot $projectRoot
            if (Test-Path $instructionsPath) {
                $rulesChanged = Update-InstructionsTeamRules -FilePath $instructionsPath -TeamRulesContent $teamRulesContent
                if ($rulesChanged) {
                    Write-Ok 'Team rules updated in project instructions'
                }
                else {
                    Write-Step 'Team rules unchanged in project instructions'
                }
            }
        }
    }

    # Step 4: Auto-update engram Memory Protocol in instructions
    # Skip for IDEs where gentle-ai handles the protocol globally
    if ($projectConfig) {
        $instructionsPath = Get-IdeInstructionsPath -Ide $config.ide -ProjectRoot $projectRoot
        if (Test-Path $instructionsPath) {
            $skipProtocol = Test-GentleAiSupportsIde -Ide $config.ide
            $protocolChanged = Update-InstructionsEngramProtocol -FilePath $instructionsPath -SkipEngramProtocol:$skipProtocol
            if ($protocolChanged) {
                if ($skipProtocol) {
                    Write-Ok 'Engram Memory Protocol removed from project instructions (gentle-ai handles it)'
                }
                else {
                    Write-Ok 'Engram Memory Protocol updated in project instructions'
                }
            }
            else {
                Write-Step 'Engram Memory Protocol unchanged in project instructions'
            }
        }
    }

    # Step 5: Update config timestamp and version
    $config.lastUpdate = Get-Date -Format 'o'
    $config.version = $KitVersion
    Save-TeamAiKitConfig -Config $config | Out-Null
    Write-Host ''
    Write-Ok 'Update complete'
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
    # Team repo status -- resolve per-project > global
    $projectRoot = (Get-Location).Path
    $effectiveTeamRepo = $config.teamRepo
    if (Test-ProjectInitialized -ProjectRoot $projectRoot) {
        $pc = Get-ProjectConfig -ProjectRoot $projectRoot
        if ($pc.teamRepo) { $effectiveTeamRepo = $pc.teamRepo }
    }

    Write-Host "    Team Repo:   $(if ($effectiveTeamRepo) { $effectiveTeamRepo } else { '(none)' })"
    Write-Host "    Installed:   $($config.installedAt)"
    Write-Host "    Last Update: $($config.lastUpdate)"
    Write-Host "    Version:     $(if ($config.version) { $config.version } else { 'unknown' })"
    Write-Host ''

    # Show installed skills from manifest
    $manifest = Get-SkillManifest
    $fileCount = $manifest.files.Count
    if ($fileCount -gt 0) {
        $defaultCount = @($manifest.files.Values | Where-Object { $_.source -eq 'default' }).Count
        $teamCount = @($manifest.files.Values | Where-Object { $_.source -eq 'team' }).Count
        Write-Host "  Global Skills: $fileCount tracked ($defaultCount default, $teamCount team)" -ForegroundColor White

        # Check for user modifications
        $skillsDir = Get-IdeSkillsDirectory -Ide $config.ide
        $modifiedCount = 0
        foreach ($key in $manifest.files.Keys) {
            $filePath = Join-Path $skillsDir $key
            if (Test-SkillModifiedByUser -FilePath $filePath -ManifestKey $key -Manifest $manifest) {
                $modifiedCount++
            }
        }
        if ($modifiedCount -gt 0) {
            Write-Warn "  $modifiedCount skill(s) modified locally (protected from overwrite)"
        }
    }
    else {
        # Fallback: check directory directly
        $skillsDir = Get-IdeSkillsDirectory -Ide $config.ide
        $teamSkillsDir = Join-Path $skillsDir 'team-skills'
        if (Test-Path $teamSkillsDir) {
            $skillFiles = @(Get-ChildItem -Path $teamSkillsDir -Filter 'SKILL.md' -Recurse)
            Write-Host "  Global Skills: $($skillFiles.Count) (no manifest -- run update to track)" -ForegroundColor White
        }
        else {
            Write-Warn "  Global skills directory not found: $teamSkillsDir"
        }
    }

    # Show project-level skills
    if (Test-ProjectInitialized -ProjectRoot $projectRoot) {
        $pc = Get-ProjectConfig -ProjectRoot $projectRoot
        $projectIde = if ($pc.ide) { $pc.ide } else { $config.ide }
        $projectSkillsDir = Get-IdeProjectSkillsDirectory -Ide $projectIde -ProjectRoot $projectRoot
        $projectTeamDir = Join-Path $projectSkillsDir 'team-skills'
        if (Test-Path $projectTeamDir) {
            $projectSkillFiles = @(Get-ChildItem -Path $projectTeamDir -Filter 'SKILL.md' -Recurse)
            $relDir = $projectSkillsDir.Replace($projectRoot, '').TrimStart('\', '/')
            Write-Host "  Project Skills: $($projectSkillFiles.Count) in $relDir/" -ForegroundColor White
        }
        else {
            Write-Step 'Project skills: none (run "team-ai-kit init" with a team repo)'
        }
    }

    # Team repo status
    if (-not [string]::IsNullOrWhiteSpace($effectiveTeamRepo)) {
        Write-Host ''
        if (Test-TeamRepoCloned -RepoUrl $effectiveTeamRepo) {
            Write-Ok "Team repo: cloned locally"
        }
        else {
            Write-Warn 'Team repo: configured but not cloned (run "team-ai-kit update")'
        }
    }
    Write-Host ''
}

# -- Doctor --------------------------------------------------------------------
function Invoke-DoctorCommand {
    Show-Banner
    Write-Host '  Checking installation health...' -ForegroundColor White
    Write-Host ''

    $allGood = $true

    # team-ai-kit version
    Write-Step 'Checking for updates...'
    $kitLatest = Get-LatestGithubVersion -Owner 'lazarogadiel93' -Repo 'team-ai-kit'
    $kitUpdateAvailable = $false
    if ($kitLatest -and $KitVersion) {
        try { $kitUpdateAvailable = ([System.Version]$KitVersion) -lt ([System.Version]$kitLatest) }
        catch { $kitUpdateAvailable = $kitLatest -ne $KitVersion }
    }
    if ($kitUpdateAvailable) {
        Write-Warn "team-ai-kit: v$KitVersion (update available: v$kitLatest) -- run: scoop update team-ai-kit"
    }
    else {
        Write-Ok "team-ai-kit: v$KitVersion"
    }

    # Scoop (optional)
    if (Test-ScoopInstalled) { Write-Ok 'Scoop: installed' }
    else { Write-Warn 'Scoop: NOT found (optional -- direct download available)' }

    # gentle-ai
    if (Test-GentleAiInstalled) {
        $gentlePath = Get-GentleAiBinaryPath
        $gentleVer = Get-ToolVersionStatus -Tool 'gentle-ai' -Owner 'Gentleman-Programming' -Repo 'gentle-ai'
        $verStr = if ($gentleVer.installed) { "v$($gentleVer.installed)" } else { 'unknown' }
        if ($gentleVer.updateAvailable) {
            Write-Warn "gentle-ai: $verStr (update available: v$($gentleVer.latest)) -- run: scoop update gentle-ai"
        }
        else {
            Write-Ok "gentle-ai: $verStr ($gentlePath)"
        }
    }
    else { Write-Err 'gentle-ai: NOT found'; $allGood = $false }

    # engram
    if (Test-EngramInstalled) {
        $engramPath = Get-EngramBinaryPath
        $engramVer = Get-ToolVersionStatus -Tool 'engram' -Owner 'Gentleman-Programming' -Repo 'engram'
        $verStr = if ($engramVer.installed) { "v$($engramVer.installed)" } else { 'unknown' }
        if ($engramVer.updateAvailable) {
            Write-Warn "engram: $verStr (update available: v$($engramVer.latest)) -- run: scoop update engram"
        }
        else {
            Write-Ok "engram: $verStr ($engramPath)"
        }
    }
    else { Write-Err 'engram: NOT found'; $allGood = $false }

    # Config
    $config = Get-TeamAiKitConfig
    if ($config.ide) {
        Write-Ok "Config: found (IDE=$($config.ide), Role=$($config.role))"
    }
    else {
        Write-Warn 'Config: not configured (run "team-ai-kit setup")'
    }

    # Global skills directory
    if ($config.ide) {
        $skillsDir = Get-IdeSkillsDirectory -Ide $config.ide
        $teamSkillsDir = Join-Path $skillsDir 'team-skills'
        if (Test-Path $teamSkillsDir) {
            $count = @(Get-ChildItem -Path $teamSkillsDir -Filter 'SKILL.md' -Recurse).Count
            Write-Ok "Global skills: $count files in $teamSkillsDir"
        }
        else {
            Write-Warn "Global skills: directory not found ($teamSkillsDir)"
        }
    }

    # Project-level skills & team repo (only inside an initialized project)
    $projectRoot = (Get-Location).Path
    if ($config.ide -and (Test-ProjectInitialized -ProjectRoot $projectRoot)) {
        $pc = Get-ProjectConfig -ProjectRoot $projectRoot
        $projectIde = if ($pc.ide) { $pc.ide } else { $config.ide }
        $projectSkillsDir = Get-IdeProjectSkillsDirectory -Ide $projectIde -ProjectRoot $projectRoot
        $projectTeamDir = Join-Path $projectSkillsDir 'team-skills'
        if (Test-Path $projectTeamDir) {
            $pCount = @(Get-ChildItem -Path $projectTeamDir -Filter 'SKILL.md' -Recurse).Count
            $relDir = $projectSkillsDir.Replace($projectRoot, '').TrimStart('\', '/')
            Write-Ok "Project skills: $pCount files in $relDir/"
        }
        else {
            Write-Step 'Project skills: not installed (run "team-ai-kit init" with a team repo)'
        }

        # Team repo
        $effectiveRepo = if ($pc.teamRepo) { $pc.teamRepo } elseif ($config.teamRepo) { $config.teamRepo } else { '' }
        if ($effectiveRepo) {
            Write-Ok "Team repo: $effectiveRepo"
        }
        else {
            Write-Warn 'Team repo: not configured (use "team-ai-kit init -TeamRepo <url>")'
        }
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
    'setup'          { Invoke-SetupCommand }
    'init'           { Invoke-InitCommand }
    'init-knowledge' { Invoke-InitKnowledgeCommand }
    'sync'           { Invoke-SyncCommand }
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
