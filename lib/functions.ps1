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
$script:VALID_COMMANDS = @('setup', 'init', 'update', 'status', 'doctor', 'help')

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

# ── Project Init ──────────────────────────────────────────────────────────────

function Get-ProjectConfigPath {
    <#
    .SYNOPSIS
        Returns the path to .team-ai-kit.json in the given project directory.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )
    return Join-Path $ProjectRoot '.team-ai-kit.json'
}

function Test-ProjectInitialized {
    <#
    .SYNOPSIS
        Returns $true if the project has been initialized (.team-ai-kit.json exists).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )
    return Test-Path (Get-ProjectConfigPath -ProjectRoot $ProjectRoot)
}

function Get-ProjectConfig {
    <#
    .SYNOPSIS
        Reads and returns the project-level config as a hashtable.
        Returns $null if not initialized.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )
    $configPath = Get-ProjectConfigPath -ProjectRoot $ProjectRoot
    if (-not (Test-Path $configPath)) { return $null }
    $raw = Get-Content $configPath -Raw | ConvertFrom-Json
    $config = @{}
    $raw.PSObject.Properties | ForEach-Object { $config[$_.Name] = $_.Value }
    return $config
}

function Save-ProjectConfig {
    <#
    .SYNOPSIS
        Saves project-level config to .team-ai-kit.json in the project root.
    .OUTPUTS
        The path to the saved config file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot,
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    $configPath = Get-ProjectConfigPath -ProjectRoot $ProjectRoot
    $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8
    return $configPath
}

function Initialize-SharedEngram {
    <#
    .SYNOPSIS
        Creates the shared-engram directory in the project and runs initial export.
    .DESCRIPTION
        Sets up shared-engram/ for team knowledge sharing.
        If engram is installed, exports current project observations.
        Returns a hashtable with status and path.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot,
        [string]$ProjectName = ''
    )

    $engramDir = Join-Path $ProjectRoot 'shared-engram'

    # Create directory if missing
    if (-not (Test-Path $engramDir)) {
        New-Item -ItemType Directory -Path $engramDir -Force | Out-Null
    }

    # Create .gitkeep so the dir is tracked even when empty
    $gitkeepPath = Join-Path $engramDir '.gitkeep'
    if (-not (Test-Path $gitkeepPath)) {
        Set-Content -Path $gitkeepPath -Value '' -NoNewline
    }

    $result = @{
        path     = $engramDir
        exported = $false
        count    = 0
    }

    # Run initial export if engram is available
    if (Test-EngramInstalled) {
        $engramBin = Get-EngramBinaryPath
        if ($engramBin) {
            try {
                $exportFile = Join-Path $engramDir 'observations.json'
                $null = & $engramBin export $exportFile 2>$null
                if ($LASTEXITCODE -eq 0 -and (Test-Path $exportFile)) {
                    $result.exported = $true
                    # Count exported observations
                    $content = Get-Content $exportFile -Raw | ConvertFrom-Json
                    if ($content.observations -is [array]) {
                        $result.count = $content.observations.Count
                    }
                }
            }
            catch {
                # Non-fatal: engram export failed, directory still created
            }
        }
    }

    return $result
}

function New-InitSummary {
    <#
    .SYNOPSIS
        Generates a human-readable summary after project initialization.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Ide,
        [Parameter(Mandatory)]
        [string]$Role,
        [string]$InstructionsPath = '',
        [int]$EngramExported = 0
    )
    $engramLine = if ($EngramExported -gt 0) { "$EngramExported observations exported" } else { 'directory created (no observations yet)' }
    return @"
============================================
  Team AI Kit -- Project Initialized
============================================
  IDE:            $Ide
  Role:           $Role
  Instructions:   $InstructionsPath
  Shared Engram:  $engramLine
============================================
"@
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

# ── Team Repo Management ─────────────────────────────────────────────────────

function Get-TeamRepoLocalPath {
    <#
    .SYNOPSIS
        Returns the local path where the team content repo is cloned (~/.team-ai-kit/team-content).
    #>
    return Join-Path (Get-TeamAiKitConfigDir) 'team-content'
}

function Test-TeamRepoConfigured {
    <#
    .SYNOPSIS
        Returns $true if a team repo URL is set in the config.
    #>
    $config = Get-TeamAiKitConfig
    return -not [string]::IsNullOrWhiteSpace($config.teamRepo)
}

function Test-TeamRepoCloned {
    <#
    .SYNOPSIS
        Returns $true if the team repo has been cloned locally.
    #>
    $localPath = Get-TeamRepoLocalPath
    return Test-Path (Join-Path $localPath '.git')
}

function Invoke-TeamRepoClone {
    <#
    .SYNOPSIS
        Clones the team content repo to the local cache. If already cloned, pulls instead.
    .OUTPUTS
        $true on success, $false on failure.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RepoUrl
    )
    $localPath = Get-TeamRepoLocalPath
    if (Test-TeamRepoCloned) {
        return Invoke-TeamRepoPull
    }
    $parentDir = Split-Path $localPath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    & git clone $RepoUrl $localPath 2>&1 | Out-Null
    return $LASTEXITCODE -eq 0
}

function Invoke-TeamRepoPull {
    <#
    .SYNOPSIS
        Pulls latest changes in the local team repo clone.
    .OUTPUTS
        $true on success, $false on failure.
    #>
    $localPath = Get-TeamRepoLocalPath
    if (-not (Test-TeamRepoCloned)) {
        return $false
    }
    Push-Location $localPath
    try {
        & git pull 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    }
    finally {
        Pop-Location
    }
}

function Get-TeamRepoSkillPaths {
    <#
    .SYNOPSIS
        Returns skill file paths from the local team repo clone for the given role.
        Includes both shared and role-specific skills from the team repo.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Role
    )
    $localPath = Get-TeamRepoLocalPath
    if (-not (Test-Path $localPath)) { return @() }

    [string[]]$all = @()

    $sharedDir = Join-Path $localPath 'skills\shared'
    if (Test-Path $sharedDir) {
        $all += @(Get-ChildItem -Path $sharedDir -Filter '*.md' -Recurse | Select-Object -ExpandProperty FullName)
    }

    $roleDir = Join-Path $localPath "skills\roles\$Role"
    if (Test-Path $roleDir) {
        $all += @(Get-ChildItem -Path $roleDir -Filter '*.md' -Recurse | Select-Object -ExpandProperty FullName)
    }

    return $all
}

# ── Skill Manifest (hash tracking for no-overwrite) ─────────────────────────

function Get-SkillManifestPath {
    <#
    .SYNOPSIS
        Returns the path to the skill manifest file (~/.team-ai-kit/manifest.json).
    #>
    return Join-Path (Get-TeamAiKitConfigDir) 'manifest.json'
}

function Get-SkillManifest {
    <#
    .SYNOPSIS
        Reads the skill manifest. Returns a hashtable with a 'files' key containing
        per-file tracking info (hash, source, installedAt).
    #>
    $path = Get-SkillManifestPath
    if (-not (Test-Path $path)) {
        return @{ files = @{} }
    }
    $raw = Get-Content $path -Raw | ConvertFrom-Json
    $manifest = @{ files = @{} }
    if ($raw.files) {
        $raw.files.PSObject.Properties | ForEach-Object {
            $manifest.files[$_.Name] = @{
                hash        = $_.Value.hash
                source      = $_.Value.source
                installedAt = $_.Value.installedAt
            }
        }
    }
    return $manifest
}

function Save-SkillManifest {
    <#
    .SYNOPSIS
        Saves the skill manifest hashtable to manifest.json.
    .OUTPUTS
        The path to the saved manifest file.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest
    )
    $path = Get-SkillManifestPath
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $Manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
    return $path
}

function Get-FileContentHash {
    <#
    .SYNOPSIS
        Returns the SHA256 hash of a file's content, or $null if file does not exist.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    if (-not (Test-Path $FilePath)) { return $null }
    return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
}

function Test-SkillModifiedByUser {
    <#
    .SYNOPSIS
        Returns $true if a skill file exists AND has been modified since it was installed
        (i.e. its current hash differs from the hash recorded in the manifest).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string]$ManifestKey,
        [Parameter(Mandatory)]
        [hashtable]$Manifest
    )
    if (-not (Test-Path $FilePath)) { return $false }
    if (-not $Manifest.files.ContainsKey($ManifestKey)) {
        # File exists but not in manifest -- treat as user-created, don't touch
        return $true
    }
    $currentHash = Get-FileContentHash -FilePath $FilePath
    $recordedHash = $Manifest.files[$ManifestKey].hash
    return $currentHash -ne $recordedHash
}

# ── Skills Merge (3-layer: defaults + team + user) ───────────────────────────

function Install-SingleSkillWithTracking {
    <#
    .SYNOPSIS
        Installs a single skill file with manifest tracking.
        Returns a hashtable with 'action' key: installed, updated, or skipped.
    .DESCRIPTION
        - File does not exist: INSTALL and record hash.
        - File exists, user modified (hash differs from manifest): SKIP.
        - File exists, not modified, source has changes: UPDATE and record new hash.
        - File exists, not modified, source unchanged: SKIP (no-op).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        [Parameter(Mandatory)]
        [string]$DestPath,
        [Parameter(Mandatory)]
        [string]$ManifestKey,
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [hashtable]$Manifest,
        [Parameter(Mandatory)]
        [string]$Timestamp
    )

    $destDir = Split-Path $DestPath -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $sourceHash = Get-FileContentHash -FilePath $SourcePath

    if (-not (Test-Path $DestPath)) {
        # File does not exist -> install
        Copy-Item -Path $SourcePath -Destination $DestPath -Force
        $Manifest.files[$ManifestKey] = @{
            hash        = $sourceHash
            source      = $Source
            installedAt = $Timestamp
        }
        return @{ action = 'installed' }
    }

    # File exists -- check if user modified it
    if (Test-SkillModifiedByUser -FilePath $DestPath -ManifestKey $ManifestKey -Manifest $Manifest) {
        return @{ action = 'skipped' }
    }

    # Not modified -- check if source has changes
    $currentHash = Get-FileContentHash -FilePath $DestPath
    if ($currentHash -eq $sourceHash) {
        return @{ action = 'skipped' }
    }

    # Source changed, user hasn't modified -> update
    Copy-Item -Path $SourcePath -Destination $DestPath -Force
    $Manifest.files[$ManifestKey] = @{
        hash        = $sourceHash
        source      = $Source
        installedAt = $Timestamp
    }
    return @{ action = 'updated' }
}

function Install-SkillsWithMerge {
    <#
    .SYNOPSIS
        Installs skills using 3-layer merge: package defaults + team repo + user modifications.
        User modifications are NEVER overwritten.
    .OUTPUTS
        Hashtable with keys: installed (array), updated (array), skipped (array).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$KitRoot,
        [Parameter(Mandatory)]
        [string]$Role,
        [Parameter(Mandatory)]
        [string]$TargetDir,
        [switch]$IncludeTeamRepo
    )

    $manifest = Get-SkillManifest
    $now = Get-Date -Format 'o'
    $results = @{
        installed = @()
        updated   = @()
        skipped   = @()
    }

    # Layer 1: Package defaults
    $defaultSkills = Get-AllSkillPathsForRole -KitRoot $KitRoot -Role $Role
    $skillsBase = Join-Path $KitRoot 'skills'

    foreach ($skillPath in $defaultSkills) {
        $relativePath = $skillPath.Replace($skillsBase, '').TrimStart('\', '/')
        $manifestKey = "team-skills\$relativePath"
        $destPath = Join-Path $TargetDir $manifestKey

        $result = Install-SingleSkillWithTracking `
            -SourcePath $skillPath `
            -DestPath $destPath `
            -ManifestKey $manifestKey `
            -Source 'default' `
            -Manifest $manifest `
            -Timestamp $now

        $results[$result.action] += $destPath
    }

    # Layer 2: Team repo (overlays on top of defaults -- same key = team wins)
    if ($IncludeTeamRepo) {
        $teamRepoPath = Get-TeamRepoLocalPath
        if (Test-Path $teamRepoPath) {
            $teamSkills = Get-TeamRepoSkillPaths -Role $Role
            $teamSkillsBase = Join-Path $teamRepoPath 'skills'

            foreach ($skillPath in $teamSkills) {
                $relativePath = $skillPath.Replace($teamSkillsBase, '').TrimStart('\', '/')
                $manifestKey = "team-skills\$relativePath"
                $destPath = Join-Path $TargetDir $manifestKey

                $result = Install-SingleSkillWithTracking `
                    -SourcePath $skillPath `
                    -DestPath $destPath `
                    -ManifestKey $manifestKey `
                    -Source 'team' `
                    -Manifest $manifest `
                    -Timestamp $now

                $results[$result.action] += $destPath
            }
        }
    }

    # Persist manifest (suppress return value to avoid pipeline pollution)
    $null = Save-SkillManifest -Manifest $manifest

    return $results
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
