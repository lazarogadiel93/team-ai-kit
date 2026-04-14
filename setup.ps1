#Requires -Version 5.1
<#
.SYNOPSIS
    Team AI Kit — One-command setup for your team's AI development environment.
.DESCRIPTION
    Installs gentle-ai + engram, configures your IDE, copies team skills based on
    your role, and sets up shared engram sync.
.EXAMPLE
    .\setup.ps1
    .\setup.ps1 --update
#>

param(
    [switch]$Update
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Load functions ────────────────────────────────────────────────────────────
$kitRoot = $PSScriptRoot
. (Join-Path $kitRoot 'lib\functions.ps1')

# ── Colors ────────────────────────────────────────────────────────────────────
function Write-Step { param([string]$Msg) Write-Host "  → $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "  ✓ $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "  ! $Msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$Msg) Write-Host "  ✗ $Msg" -ForegroundColor Red }

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '  ╔══════════════════════════════════════╗' -ForegroundColor Magenta
Write-Host '  ║        Team AI Kit — Setup           ║' -ForegroundColor Magenta
Write-Host '  ║  4 questions. 2 minutes. Full power. ║' -ForegroundColor Magenta
Write-Host '  ╚══════════════════════════════════════╝' -ForegroundColor Magenta
Write-Host ''

# ── Step 1: Prerequisites ────────────────────────────────────────────────────
Write-Host '  [1/6] Checking prerequisites...' -ForegroundColor White

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
    Write-Step 'Installing gentle-ai...'
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
    Write-Step 'Installing engram...'
    try {
        & scoop install engram 2>$null
        if (-not (Test-EngramInstalled)) {
            Write-Warn 'Engram not in Scoop — gentle-ai will manage it'
        }
        else {
            Write-Ok 'engram installed'
        }
    }
    catch {
        Write-Warn 'Engram install via Scoop failed — gentle-ai will manage it'
    }
}
else {
    Write-Ok 'engram available'
}

# ── Step 2: IDE Selection ────────────────────────────────────────────────────
Write-Host ''
Write-Host '  [2/6] IDE Selection' -ForegroundColor White
Write-Host '    1) VS Code + Copilot'
Write-Host '    2) IntelliJ + Copilot'
Write-Host '    3) OpenCode (CLI)'
Write-Host ''

do {
    $ideChoice = Read-Host '  Your IDE (1-3)'
} while ($ideChoice -notin @('1', '2', '3'))

$ide = switch ($ideChoice) {
    '1' { 'vscode' }
    '2' { 'intellij' }
    '3' { 'opencode' }
}

# ── Step 3: Role Selection ───────────────────────────────────────────────────
Write-Host ''
Write-Host '  [3/6] Role Selection' -ForegroundColor White
Write-Host '    1) Frontend (React / Next.js)'
Write-Host '    2) Backend (Node.js / Express)'
Write-Host '    3) DevOps (CI/CD / Docker / Infra)'
Write-Host '    4) Python (FastAPI / Django)'
Write-Host ''

do {
    $roleChoice = Read-Host '  Your role (1-4)'
} while ($roleChoice -notin @('1', '2', '3', '4'))

$role = switch ($roleChoice) {
    '1' { 'frontend' }
    '2' { 'backend-node' }
    '3' { 'devops' }
    '4' { 'python' }
}

# ── Step 4: Provider Selection ───────────────────────────────────────────────
Write-Host ''
Write-Host '  [4/6] AI Provider' -ForegroundColor White
Write-Host '    1) OpenAI'
Write-Host '    2) Azure OpenAI'
Write-Host '    3) Anthropic'
Write-Host ''

do {
    $providerChoice = Read-Host '  Your provider (1-3)'
} while ($providerChoice -notin @('1', '2', '3'))

$provider = switch ($providerChoice) {
    '1' { 'openai' }
    '2' { 'azure-openai' }
    '3' { 'anthropic' }
}

# ── Step 5: Install Skills ──────────────────────────────────────────────────
Write-Host ''
Write-Host '  [5/6] Installing team skills...' -ForegroundColor White

$targetSkillsDir = Get-IdeSkillsDirectory -Ide $ide
Write-Step "Target: $targetSkillsDir"

$copiedSkills = Install-TeamSkills -KitRoot $kitRoot -Role $role -TargetDir $targetSkillsDir
Write-Ok "$($copiedSkills.Count) skills installed for role: $role"

# ── Step 6: Configure Engram + MCP ───────────────────────────────────────────
Write-Host ''
Write-Host '  [6/6] Configuring engram & MCP...' -ForegroundColor White

$engramBin = Get-EngramBinaryPath
if ($engramBin) {
    Write-Ok "Engram binary: $engramBin"

    # Generate MCP config for the selected IDE
    if ($ide -eq 'vscode' -or $ide -eq 'intellij') {
        $mcpJson = New-VsCodeMcpConfig -EngramBinaryPath $engramBin
        Write-Ok 'MCP config generated (engram + context7)'
        Write-Step 'Add this to your project .vscode/mcp.json or IDE MCP settings:'
        Write-Host ''
        Write-Host $mcpJson -ForegroundColor DarkGray
        Write-Host ''
    }
}
else {
    Write-Warn 'Engram binary not found — run gentle-ai to configure it'
}

# Generate instructions with pack rules
$packRulesPath = Get-PackRulesPath -KitRoot $kitRoot -Role $role
$packRulesContent = ''
if ($packRulesPath) {
    $packRulesContent = Get-Content -Path $packRulesPath -Raw
}
$instructions = New-CopilotInstructions -Role $role -PackRulesContent $packRulesContent
Write-Ok "Copilot instructions generated for role: $role"
Write-Step 'Copy the instructions to your project .github/copilot-instructions.md'

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host ''
$summary = New-SetupSummary -Ide $ide -Role $role -Provider $provider -SkillsCopied $copiedSkills.Count
Write-Host $summary -ForegroundColor Green

Write-Host ''
Write-Host '  Next steps:' -ForegroundColor Yellow
Write-Host '    1. Run gentle-ai to complete agent configuration' -ForegroundColor White
Write-Host '    2. Configure engram sync to your Azure DevOps repo' -ForegroundColor White
Write-Host '    3. Open your IDE and start working!' -ForegroundColor White
Write-Host ''
