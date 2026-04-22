#Requires -Version 5.1
<#
.SYNOPSIS
    Team AI Kit -- Reusable functions for setup and configuration.
.DESCRIPTION
    Pure/testable functions used by bin/team-ai-kit.ps1. No interactive prompts here.
#>

Set-StrictMode -Version Latest

# ── Constants ─────────────────────────────────────────────────────────────────

$script:VALID_IDES = @('vscode', 'intellij', 'opencode', 'cursor')
$script:VALID_ROLES = @('frontend', 'backend-node', 'backend-java', 'backend-dotnet', 'devops', 'python', 'mobile', 'data')
$script:VALID_PROVIDERS = @('openai', 'azure-openai', 'anthropic', 'github-copilot')
$script:VALID_COMMANDS = @('setup', 'init', 'init-knowledge', 'sync', 'update', 'status', 'doctor', 'uninstall', 'help')

# ── Config Persistence ───────────────────────────────────────────────────────

function Get-UserHome {
    <#
    .SYNOPSIS
        Returns the user home directory with fallback for non-standard environments.
    .DESCRIPTION
        Tries $env:USERPROFILE (Windows default), then $env:HOME (CI/containers),
        then [Environment]::GetFolderPath('UserProfile'). Throws if all fail.
    #>
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    if ($env:HOME) { return $env:HOME }
    $fp = [Environment]::GetFolderPath('UserProfile')
    if ($fp) { return $fp }
    throw 'Cannot determine user home directory. Set USERPROFILE or HOME environment variable.'
}

function ConvertTo-SafeProjectName {
    <#
    .SYNOPSIS
        Strips unsafe characters from project name to prevent shell injection in git hooks.
    .DESCRIPTION
        Allows only: a-z A-Z 0-9 . _ -
    #>
    param([string]$Name)
    return ($Name -replace '[^a-zA-Z0-9._-]', '')
}

function Get-TeamAiKitConfigDir {
    <#
    .SYNOPSIS
        Returns the path to the team-ai-kit config directory (~/.team-ai-kit).
    #>
    return Join-Path (Get-UserHome) '.team-ai-kit'
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
    foreach ($prop in $raw.PSObject.Properties) { $config[$prop.Name] = $prop.Value }
    return $config
}

function Resolve-TeamRepo {
    <#
    .SYNOPSIS
        Resolves the effective team repo URL using priority: CLI param > project config > global config.
    .OUTPUTS
        The resolved URL string (empty string if none configured).
    #>
    param(
        [string]$ProjectRoot = '',
        [string]$CliParam = ''
    )
    if ($CliParam) { return $CliParam }

    if ($ProjectRoot -and (Test-ProjectInitialized -ProjectRoot $ProjectRoot)) {
        $pc = Get-ProjectConfig -ProjectRoot $ProjectRoot
        if ($pc -and $pc.teamRepo) { return $pc.teamRepo }
    }

    $globalConfig = Get-TeamAiKitConfig
    if ($globalConfig.teamRepo) { return $globalConfig.teamRepo }

    return ''
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

function Ensure-GitAttributes {
    <#
    .SYNOPSIS
        Creates or updates .gitattributes with rules to collapse .engram/ diffs in PRs.
    .DESCRIPTION
        Adds linguist-generated and -diff rules for .engram/ so PR diffs stay clean.
        Idempotent: skips if marker already present.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    $gaPath = Join-Path $ProjectRoot '.gitattributes'
    $marker = '# [team-ai-kit] engram diff rules'
    $block = @(
        $marker
        '.engram/** linguist-generated=true'
        '.engram/** -diff'
    ) -join "`n"

    if (Test-Path $gaPath) {
        $existing = Get-Content $gaPath -Raw -ErrorAction SilentlyContinue
        if ($existing -and $existing.Contains($marker)) {
            return @{ created = $false; updated = $false; path = $gaPath }
        }
        # Append with blank line separator
        $newContent = $existing.TrimEnd() + "`n`n" + $block + "`n"
        $lfContent = $newContent -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($gaPath, $lfContent, [System.Text.UTF8Encoding]::new($false))
        return @{ created = $false; updated = $true; path = $gaPath }
    }
    else {
        $lfContent = ($block + "`n") -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($gaPath, $lfContent, [System.Text.UTF8Encoding]::new($false))
        return @{ created = $true; updated = $false; path = $gaPath }
    }
}

function Remove-GitAttributesBlock {
    <#
    .SYNOPSIS
        Removes team-ai-kit lines from .gitattributes during uninstall.
    .DESCRIPTION
        Deletes the file if only our lines remain.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    $gaPath = Join-Path $ProjectRoot '.gitattributes'
    if (-not (Test-Path $gaPath)) { return }

    $content = Get-Content $gaPath -Raw -ErrorAction SilentlyContinue
    $marker = '# [team-ai-kit] engram diff rules'
    if (-not $content -or -not $content.Contains($marker)) { return }

    $lines = Get-Content $gaPath
    $cleaned = @()
    $skipNext = $false

    foreach ($line in $lines) {
        if ($line.Contains($marker)) {
            $skipNext = $true
            continue
        }
        if ($skipNext -and $line -match '^\.engram/') {
            continue
        }
        $skipNext = $false
        $cleaned += $line
    }

    $cleaned = @($cleaned | Where-Object { $_.Trim() -ne '' })

    if ($cleaned.Count -eq 0) {
        Remove-Item $gaPath -Force
    }
    else {
        $newContent = ($cleaned -join "`n") + "`n"
        $lfContent = $newContent -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($gaPath, $lfContent, [System.Text.UTF8Encoding]::new($false))
    }
}

function Initialize-EngramSync {
    <#
    .SYNOPSIS
        Runs initial engram sync to export project memories to .engram/.
    .DESCRIPTION
        Uses native 'engram sync --project <name>' to create .engram/ with
        compressed chunks for team knowledge sharing via git.
        Returns a hashtable with status and path.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot,
        [string]$ProjectName = ''
    )

    $engramDir = Join-Path $ProjectRoot '.engram'

    $result = @{
        path     = $engramDir
        synced   = $false
    }

    # Run initial sync if engram is available
    if (Test-EngramInstalled) {
        $engramBin = Get-EngramBinaryPath
        if ($engramBin) {
            try {
                $syncArgs = @('sync')
                if ($ProjectName) {
                    $syncArgs += @('--project', $ProjectName)
                }
                else {
                    $syncArgs += '--all'
                }
                $null = & $engramBin @syncArgs 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $result.synced = $true
                }
            }
            catch {
                # Non-fatal: engram sync failed
            }
        }
    }

    return $result
}

function Install-GitHooks {
    <#
    .SYNOPSIS
        Installs pre-commit and post-merge git hooks for automatic engram sync.
    .DESCRIPTION
        Creates git hooks in .git/hooks/ that:
        - pre-commit: runs 'engram sync --project <name>' + 'git add .engram/'
        - post-merge: runs 'engram sync --import'
        Hooks are fail-safe (no-op if engram is not installed).
        Respects existing hooks by appending with a marker comment.
        Returns a hashtable with status.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot,
        [string]$ProjectName = ''
    )

    $gitHooksDir = Join-Path $ProjectRoot '.git\hooks'
    $result = @{
        installed = @()
        skipped   = @()
    }

    if (-not (Test-Path (Join-Path $ProjectRoot '.git'))) {
        $result.skipped += 'not-a-git-repo'
        return $result
    }

    if (-not (Test-Path $gitHooksDir)) {
        New-Item -ItemType Directory -Path $gitHooksDir -Force | Out-Null
    }

    $marker = '# [team-ai-kit] engram sync hook'
    $projectFlag = if ($ProjectName) { "--project `"$ProjectName`"" } else { '--all' }

    # -- pre-commit hook -------------------------------------------------------
    $preCommitPath = Join-Path $gitHooksDir 'pre-commit'
    $preCommitBlock = "`n$marker`nif command -v engram >/dev/null 2>&1; then`n    engram sync $projectFlag 2>/dev/null || true`n    git add .engram/ 2>/dev/null || true`nfi"

    if (Test-Path $preCommitPath) {
        $existingContent = Get-Content $preCommitPath -Raw -ErrorAction SilentlyContinue
        if ($existingContent -and $existingContent.Contains($marker)) {
            $result.skipped += 'pre-commit'
        }
        else {
            $lfContent = ($existingContent + $preCommitBlock) -replace "`r`n", "`n"
            [System.IO.File]::WriteAllText($preCommitPath, $lfContent, [System.Text.Encoding]::ASCII)
            $result.installed += 'pre-commit'
        }
    }
    else {
        $hookContent = "#!/bin/sh`n" + $preCommitBlock
        $lfContent = $hookContent -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($preCommitPath, $lfContent, [System.Text.Encoding]::ASCII)
        $result.installed += 'pre-commit'
    }

    # -- post-merge hook -------------------------------------------------------
    $postMergePath = Join-Path $gitHooksDir 'post-merge'
    $postMergeBlock = "`n$marker`nif command -v engram >/dev/null 2>&1; then`n    engram sync --import 2>/dev/null || true`nfi"

    if (Test-Path $postMergePath) {
        $existingContent = Get-Content $postMergePath -Raw -ErrorAction SilentlyContinue
        if ($existingContent -and $existingContent.Contains($marker)) {
            $result.skipped += 'post-merge'
        }
        else {
            $lfContent = ($existingContent + $postMergeBlock) -replace "`r`n", "`n"
            [System.IO.File]::WriteAllText($postMergePath, $lfContent, [System.Text.Encoding]::ASCII)
            $result.installed += 'post-merge'
        }
    }
    else {
        $hookContent = "#!/bin/sh`n" + $postMergeBlock
        $lfContent = $hookContent -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($postMergePath, $lfContent, [System.Text.Encoding]::ASCII)
        $result.installed += 'post-merge'
    }

    return $result
}

function Invoke-EngramSync {
    <#
    .SYNOPSIS
        Wrapper around 'engram sync' for manual sync operations.
    .DESCRIPTION
        Runs engram sync with project filtering. Supports export, import, and status.
        Returns a hashtable with the operation result.
    #>
    param(
        [string]$ProjectName = '',
        [ValidateSet('export', 'import', 'status')]
        [string]$Operation = 'export'
    )

    $result = @{
        success = $false
        message = ''
    }

    if (-not (Test-EngramInstalled)) {
        $result.message = 'engram is not installed'
        return $result
    }

    $engramBin = Get-EngramBinaryPath
    if (-not $engramBin) {
        $result.message = 'engram binary not found'
        return $result
    }

    try {
        switch ($Operation) {
            'export' {
                $syncArgs = @('sync')
                if ($ProjectName) {
                    $syncArgs += @('--project', $ProjectName)
                }
                else {
                    $syncArgs += '--all'
                }
                $null = & $engramBin @syncArgs 2>$null
            }
            'import' {
                $null = & $engramBin sync --import 2>$null
            }
            'status' {
                $null = & $engramBin sync --status 2>$null
            }
        }

        if ($LASTEXITCODE -eq 0) {
            $result.success = $true
            $result.message = "engram sync $Operation completed"
        }
        else {
            $result.message = "engram sync $Operation failed (exit code: $LASTEXITCODE)"
        }
    }
    catch {
        $result.message = "engram sync $Operation failed: $_"
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
        [bool]$EngramSynced = $false,
        [int]$HooksInstalled = 0
    )
    $engramLine = if ($EngramSynced) { 'synced via engram sync' } else { 'not synced (engram not available)' }
    $hooksLine = if ($HooksInstalled -gt 0) { "$HooksInstalled hook(s) installed" } else { 'no hooks installed' }
    return @"
============================================
  Team AI Kit -- Project Initialized
============================================
  IDE:            $Ide
  Role:           $Role
  Instructions:   $InstructionsPath
  Engram Sync:    $engramLine
  Git Hooks:      $hooksLine
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
        'cursor'   = 'cursor'
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

# ── Direct Download Support ───────────────────────────────────────────────────

function Get-LocalAppData {
    <#
    .SYNOPSIS
        Returns the local app data directory with fallback for non-standard environments.
    .DESCRIPTION
        Tries $env:LOCALAPPDATA (Windows default), then falls back to
        Join-Path (Get-UserHome) 'AppData\Local'. Throws if all fail.
    #>
    if ($env:LOCALAPPDATA) { return $env:LOCALAPPDATA }
    $fallback = Join-Path (Get-UserHome) 'AppData\Local'
    if ($fallback) { return $fallback }
    throw 'Cannot determine local app data directory. Set LOCALAPPDATA environment variable.'
}

function Get-DirectDownloadBinDir {
    <#
    .SYNOPSIS
        Returns the path where directly-downloaded binaries are stored.
        Windows: $env:LOCALAPPDATA\team-ai-kit\bin
    #>
    return Join-Path (Get-LocalAppData) 'team-ai-kit\bin'
}

function Get-PlatformArchitecture {
    <#
    .SYNOPSIS
        Returns OS and architecture for GitHub release asset matching.
    .OUTPUTS
        Hashtable with 'os' and 'arch' keys.
    #>
    $arch = switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { 'amd64' }
        'ARM64' { 'arm64' }
        default { 'amd64' }
    }
    return @{ os = 'windows'; arch = $arch }
}

function Set-TlsProtocol {
    <#
    .SYNOPSIS
        Ensures TLS 1.2 for .NET HTTP requests (safety net for PS 5.1).
    .DESCRIPTION
        Wrapped in try/catch because Constrained Language Mode (CLM) blocks
        .NET property setting. Modern Windows 10+ already defaults to TLS 1.2,
        so this is safe to skip in CLM environments.
    #>
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 }
    catch { <# CLM blocks .NET property access -- safe to continue on Win10+ #> }
}

function Get-GithubLatestReleaseAssetUrl {
    <#
    .SYNOPSIS
        Queries GitHub API for the latest release and returns the matching asset info.
    .OUTPUTS
        Hashtable with url, name, and version keys.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Owner,
        [Parameter(Mandatory)]
        [string]$Repo,
        [Parameter(Mandatory)]
        [string]$AssetPattern
    )
    Set-TlsProtocol
    $apiUrl = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
    $headers = @{ 'User-Agent' = 'team-ai-kit' }
    if ($env:GITHUB_TOKEN) {
        $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
    }
    try {
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        if ($statusCode -eq 403) {
            throw "GitHub API rate limit exceeded for $Owner/$Repo. Set GITHUB_TOKEN environment variable to authenticate."
        }
        throw "Failed to query GitHub API for $Owner/${Repo}: $($_.Exception.Message)"
    }
    $asset = $release.assets | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1
    if (-not $asset) {
        throw "No release asset matching '$AssetPattern' found for $Owner/$Repo"
    }
    return @{
        url     = $asset.browser_download_url
        name    = $asset.name
        version = $release.tag_name
    }
}

function Install-GithubReleaseBinary {
    <#
    .SYNOPSIS
        Downloads and extracts a binary from a GitHub release.
    .DESCRIPTION
        Downloads the latest release asset matching the platform, extracts the zip,
        and places the binary in the direct download bin directory.
    .OUTPUTS
        Hashtable with installed ($true/$false), version, and path keys.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Owner,
        [Parameter(Mandatory)]
        [string]$Repo,
        [Parameter(Mandatory)]
        [string]$BinaryName
    )

    $platform = Get-PlatformArchitecture
    $assetPattern = "${Repo}_*_$($platform.os)_$($platform.arch).zip"

    $release = Get-GithubLatestReleaseAssetUrl -Owner $Owner -Repo $Repo -AssetPattern $assetPattern
    $binDir = Get-DirectDownloadBinDir
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }

    $tempZip = Join-Path $env:TEMP "$Repo-download-$(Get-Random).zip"
    $tempExtract = Join-Path $env:TEMP "$Repo-extract-$(Get-Random)"

    try {
        Invoke-WebRequest -Uri $release.url -OutFile $tempZip -UseBasicParsing

        if (Test-Path $tempExtract) { Remove-Item -Recurse -Force $tempExtract }
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        # Look for the binary (with or without .exe extension)
        $exeFile = Get-ChildItem -Path $tempExtract -Filter "$BinaryName.exe" -Recurse | Select-Object -First 1
        if (-not $exeFile) {
            $exeFile = Get-ChildItem -Path $tempExtract -Filter $BinaryName -Recurse -File | Select-Object -First 1
        }
        if (-not $exeFile) {
            throw "Binary '$BinaryName' not found in extracted archive"
        }

        $destPath = Join-Path $binDir "$BinaryName.exe"
        Copy-Item -Path $exeFile.FullName -Destination $destPath -Force

        return @{
            installed = $true
            version   = $release.version
            path      = $destPath
        }
    }
    finally {
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempExtract) { Remove-Item -Recurse -Force $tempExtract -ErrorAction SilentlyContinue }
    }
}

function Add-ToUserPath {
    <#
    .SYNOPSIS
        Adds a directory to the user PATH (persistent + current session).
    .OUTPUTS
        $true if the directory was added to persistent PATH, $false if already present.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory
    )

    # Add to current session (exact element match, not substring)
    $sessionElements = $env:PATH -split ';' | Where-Object { $_ -ne '' }
    if ($sessionElements -notcontains $Directory) {
        $env:PATH = "$Directory;$env:PATH"
    }

    # Add to persistent user PATH (exact element match, not substring)
    try {
        $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    }
    catch {
        # CLM blocks .NET static methods -- fall back to registry
        $userPath = (Get-ItemProperty -Path 'HKCU:\Environment' -Name Path -ErrorAction SilentlyContinue).Path
    }
    $userElements = if ($userPath) { $userPath -split ';' | Where-Object { $_ -ne '' } } else { @() }
    if (-not $userPath -or $userElements -notcontains $Directory) {
        $newPath = if ($userPath) { "$Directory;$userPath" } else { $Directory }
        try {
            [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
        }
        catch {
            # CLM blocks .NET static methods -- fall back to registry (ExpandString = REG_EXPAND_SZ)
            New-ItemProperty -Path 'HKCU:\Environment' -Name Path -Value $newPath -PropertyType ExpandString -Force | Out-Null
        }
        return $true
    }
    return $false
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
        Returns $true if gentle-ai binary is available in PATH or known locations.
    #>
    try {
        $null = Get-Command gentle-ai -ErrorAction Stop
        return $true
    }
    catch {}

    # Check Scoop shim
    $scoopPath = Join-Path (Get-UserHome) 'scoop\shims\gentle-ai.exe'
    if (Test-Path $scoopPath) { return $true }

    # Check direct download location
    $directPath = Join-Path (Get-DirectDownloadBinDir) 'gentle-ai.exe'
    if (Test-Path $directPath) { return $true }

    return $false
}

function Get-GentleAiBinaryPath {
    <#
    .SYNOPSIS
        Returns the full path to the gentle-ai binary, or $null if not found.
    #>
    try {
        $cmd = Get-Command gentle-ai -ErrorAction Stop
        return $cmd.Source
    }
    catch {}

    $scoopPath = Join-Path (Get-UserHome) 'scoop\shims\gentle-ai.exe'
    if (Test-Path $scoopPath) { return $scoopPath }

    $directPath = Join-Path (Get-DirectDownloadBinDir) 'gentle-ai.exe'
    if (Test-Path $directPath) { return $directPath }

    return $null
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
    $scoopPath = Join-Path (Get-UserHome) 'scoop\shims\engram.exe'
    if (Test-Path $scoopPath) { return $true }

    # Check AppData (gentle-ai installs here)
    $appDataPath = Join-Path (Get-LocalAppData) 'engram\bin\engram.exe'
    if (Test-Path $appDataPath) { return $true }

    # Check direct download location
    $directPath = Join-Path (Get-DirectDownloadBinDir) 'engram.exe'
    if (Test-Path $directPath) { return $true }

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

    $scoopPath = Join-Path (Get-UserHome) 'scoop\shims\engram.exe'
    if (Test-Path $scoopPath) { return $scoopPath }

    $appDataPath = Join-Path (Get-LocalAppData) 'engram\bin\engram.exe'
    if (Test-Path $appDataPath) { return $appDataPath }

    $directPath = Join-Path (Get-DirectDownloadBinDir) 'engram.exe'
    if (Test-Path $directPath) { return $directPath }

    return $null
}

# ── Version Check ─────────────────────────────────────────────────────────────

function Get-InstalledVersion {
    <#
    .SYNOPSIS
        Returns the installed version of a tool (gentle-ai or engram).
    #>
    param([Parameter(Mandatory)][string]$Tool)
    try {
        $output = & $Tool version 2>$null
        if ($output -match '(\d+\.\d+\.\d+)') { return $Matches[1] }
    }
    catch {}
    return $null
}

function Get-LatestGithubVersion {
    <#
    .SYNOPSIS
        Returns the latest release version from a GitHub repo.
    #>
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo
    )
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            $release = gh release view --repo "$Owner/$Repo" --json tagName 2>$null | ConvertFrom-Json
            if ($release.tagName -match '(\d+\.\d+\.\d+)') { return $Matches[1] }
        }
        catch {
            Write-Verbose "gh release view failed for ${Owner}/${Repo}: $_"
        }
    }
    else {
        Write-Verbose 'gh CLI not found -- skipping GitHub API version check'
    }
    # Fallback: scoop info
    if (Test-ScoopInstalled) {
        try {
            $info = & scoop info $Repo 2>$null | Out-String
            if ($info -match 'Version\s*:\s*(\d+\.\d+\.\d+)') { return $Matches[1] }
        }
        catch {
            Write-Verbose "scoop info fallback failed for ${Repo}: $_"
        }
    }
    Write-Verbose "Could not determine latest version for ${Owner}/${Repo}"
    return $null
}

function Get-ToolVersionStatus {
    <#
    .SYNOPSIS
        Returns a hashtable with installed, latest, and updateAvailable for a tool.
    #>
    param(
        [Parameter(Mandatory)][string]$Tool,
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo
    )
    $installed = Get-InstalledVersion -Tool $Tool
    $latest = Get-LatestGithubVersion -Owner $Owner -Repo $Repo
    $updateAvailable = $false
    if ($installed -and $latest) {
        try {
            $updateAvailable = ([System.Version]$installed) -lt ([System.Version]$latest)
        }
        catch {
            Write-Verbose "Version comparison failed for $Tool (installed=$installed, latest=$latest): $_"
            $updateAvailable = $installed -ne $latest
        }
    }
    return @{
        installed       = $installed
        latest          = $latest
        updateAvailable = $updateAvailable
    }
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
    return @(Get-ChildItem -Path $sharedDir -Filter 'SKILL.md' -Recurse | Select-Object -ExpandProperty FullName)
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
    return @(Get-ChildItem -Path $roleDir -Filter 'SKILL.md' -Recurse | Select-Object -ExpandProperty FullName)
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
        Returns the GLOBAL (user-level) directory where kit base skills are installed.
        Uses gentle-ai's native paths for supported IDEs.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Ide
    )
    switch ($Ide.ToLower()) {
        'vscode' {
            # VS Code Copilot: gentle-ai installs skills here
            return Join-Path (Get-UserHome) '.copilot\skills'
        }
        'intellij' {
            # IntelliJ: no gentle-ai adapter, use shared copilot path
            return Join-Path (Get-UserHome) '.copilot\skills'
        }
        'opencode' {
            # OpenCode: gentle-ai installs skills here
            return Join-Path (Get-UserHome) '.config\opencode\skills'
        }
        'cursor' {
            # Cursor: user-level skills directory
            return Join-Path (Get-UserHome) '.cursor\skills'
        }
        default {
            throw "Unsupported IDE: $Ide"
        }
    }
}

function Get-IdeProjectSkillsDirectory {
    <#
    .SYNOPSIS
        Returns the PROJECT-LEVEL directory where team-knowledge repo skills are installed.
        These are committed to the repo so each project has its own team skills.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Ide,
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )
    switch ($Ide.ToLower()) {
        'vscode' {
            return Join-Path $ProjectRoot '.github\skills'
        }
        'intellij' {
            return Join-Path $ProjectRoot '.github\skills'
        }
        'opencode' {
            return Join-Path $ProjectRoot '.agents\skills'
        }
        'cursor' {
            return Join-Path $ProjectRoot '.cursor\skills'
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
        'cursor' {
            return Join-Path $ProjectRoot '.cursor\rules\team-ai-kit.md'
        }
        default {
            throw "Unsupported IDE: $Ide"
        }
    }
}

# ── Team Repo Management ─────────────────────────────────────────────────────

function Get-TeamRepoLocalPath {
    <#
    .SYNOPSIS
        Returns the local path where the team content repo is cloned.
        When RepoUrl is provided, uses a SHA256 hash of the URL for isolation.
        Without RepoUrl, falls back to the legacy single path.
    #>
    param(
        [string]$RepoUrl = ''
    )
    if ($RepoUrl) {
        $hash = (Get-FileContentHash-String -Content $RepoUrl).Substring(0, 12)
        return Join-Path (Get-TeamAiKitConfigDir) "team-content\$hash"
    }
    return Join-Path (Get-TeamAiKitConfigDir) 'team-content'
}

function Get-FileContentHash-String {
    <#
    .SYNOPSIS
        Returns a SHA256 hash of a string (used for URL hashing).
    #>
    param([Parameter(Mandatory)][string]$Content)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash($bytes)
    return ($hashBytes | ForEach-Object { $_.ToString('X2') }) -join ''
}

function Test-TeamRepoCloned {
    <#
    .SYNOPSIS
        Returns $true if the team repo has been cloned locally.
    #>
    param([string]$RepoUrl = '')
    $localPath = Get-TeamRepoLocalPath -RepoUrl $RepoUrl
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
    $localPath = Get-TeamRepoLocalPath -RepoUrl $RepoUrl
    if (Test-TeamRepoCloned -RepoUrl $RepoUrl) {
        return Invoke-TeamRepoPull -RepoUrl $RepoUrl
    }
    $parentDir = Split-Path $localPath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    $null = & git clone $RepoUrl $localPath 2>&1
    return $LASTEXITCODE -eq 0
}

function Invoke-TeamRepoPull {
    <#
    .SYNOPSIS
        Pulls latest changes in the local team repo clone.
    .OUTPUTS
        $true on success, $false on failure.
    #>
    param([string]$RepoUrl = '')
    $localPath = Get-TeamRepoLocalPath -RepoUrl $RepoUrl
    if (-not (Test-TeamRepoCloned -RepoUrl $RepoUrl)) {
        return $false
    }
    Push-Location $localPath
    try {
        $null = & git pull 2>&1
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
        [string]$Role,
        [string]$RepoUrl = ''
    )
    $localPath = Get-TeamRepoLocalPath -RepoUrl $RepoUrl
    if (-not (Test-Path $localPath)) { return @() }

    [string[]]$all = @()

    $sharedDir = Join-Path $localPath (Join-Path 'skills' 'shared')
    if (Test-Path $sharedDir) {
        $all += @(Get-ChildItem -Path $sharedDir -Filter 'SKILL.md' -Recurse | Select-Object -ExpandProperty FullName)
    }

    $roleDir = Join-Path $localPath (Join-Path 'skills' (Join-Path 'roles' $Role))
    if (Test-Path $roleDir) {
        $all += @(Get-ChildItem -Path $roleDir -Filter 'SKILL.md' -Recurse | Select-Object -ExpandProperty FullName)
    }

    return $all
}

function Get-TeamRepoRulesContent {
    <#
    .SYNOPSIS
        Reads and concatenates all rules/*.md files from the team knowledge repo.
    .OUTPUTS
        String with all rules content concatenated, or empty string if none.
    #>
    param([string]$RepoUrl = '')
    $localPath = Get-TeamRepoLocalPath -RepoUrl $RepoUrl
    $rulesDir = Join-Path $localPath 'rules'
    if (-not (Test-Path $rulesDir)) { return '' }

    $rulesFiles = @(Get-ChildItem -Path $rulesDir -Filter '*.md' -Recurse | Sort-Object Name)
    if ($rulesFiles.Count -eq 0) { return '' }

    $content = @()
    foreach ($file in $rulesFiles) {
        $content += Get-Content -Path $file.FullName -Raw
    }
    return ($content -join "`n`n")
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
        [switch]$IncludeTeamRepo,
        [string]$TeamRepoUrl = ''
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
        $teamRepoPath = Get-TeamRepoLocalPath -RepoUrl $TeamRepoUrl
        if (Test-Path $teamRepoPath) {
            $teamSkills = Get-TeamRepoSkillPaths -Role $Role -RepoUrl $TeamRepoUrl
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

function Install-ProjectSkills {
    <#
    .SYNOPSIS
        Installs team-knowledge repo skills into the PROJECT-LEVEL skills directory.
        These are committed to the repo. Tracks last-installed hashes via a local
        manifest so user modifications are not overwritten.
    .OUTPUTS
        Hashtable with keys: installed (int), updated (int), skipped (int).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Role,
        [Parameter(Mandatory)]
        [string]$TeamRepoUrl,
        [Parameter(Mandatory)]
        [string]$TargetDir
    )

    $results = @{
        installed = 0
        updated   = 0
        skipped   = 0
    }

    $teamRepoPath = Get-TeamRepoLocalPath -RepoUrl $TeamRepoUrl
    if (-not (Test-Path $teamRepoPath)) {
        return $results
    }

    $teamSkills = Get-TeamRepoSkillPaths -Role $Role -RepoUrl $TeamRepoUrl
    # Normalize to long path to avoid 8.3 short name mismatches on CI runners
    $teamSkillsBase = [System.IO.Path]::GetFullPath((Join-Path $teamRepoPath 'skills'))

    # Load project-level manifest for tracking installed hashes
    $teamSkillsDir = Join-Path $TargetDir 'team-skills'
    $manifestPath = Join-Path $teamSkillsDir '.team-ai-kit-skills-manifest.json'
    $manifest = @{ files = @{} }
    if (Test-Path $manifestPath) {
        $raw = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if ($raw.files) {
            $raw.files.PSObject.Properties | ForEach-Object {
                $manifest.files[$_.Name] = @{
                    hash = $_.Value.hash
                }
            }
        }
    }

    foreach ($skillPath in $teamSkills) {
        $skillPath = [System.IO.Path]::GetFullPath($skillPath)
        if (-not $skillPath.StartsWith($teamSkillsBase, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Warning "Skill path '$skillPath' is not under expected base '$teamSkillsBase', skipping."
            continue
        }
        $relativePath = $skillPath.Substring($teamSkillsBase.Length).TrimStart('\', '/')
        $destPath = Join-Path $TargetDir (Join-Path 'team-skills' $relativePath)

        $destDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        $sourceHash = Get-FileContentHash -FilePath $skillPath

        if (-not (Test-Path $destPath)) {
            Copy-Item -Path $skillPath -Destination $destPath -Force
            $manifest.files[$relativePath] = @{ hash = $sourceHash }
            $results.installed++
        }
        else {
            $destHash = Get-FileContentHash -FilePath $destPath
            if ($sourceHash -eq $destHash) {
                $manifest.files[$relativePath] = @{ hash = $sourceHash }
                $results.skipped++
            }
            else {
                # Source and dest differ -- check if user modified it
                $lastInstalledHash = $null
                if ($manifest.files.ContainsKey($relativePath)) {
                    $lastInstalledHash = $manifest.files[$relativePath].hash
                }
                if ($lastInstalledHash -and $destHash -ne $lastInstalledHash) {
                    # User modified the file -- skip to preserve their changes
                    $results.skipped++
                }
                else {
                    # File matches last-installed hash or no record -- safe to update
                    Copy-Item -Path $skillPath -Destination $destPath -Force
                    $manifest.files[$relativePath] = @{ hash = $sourceHash }
                    $results.updated++
                }
            }
        }
    }

    # Save updated manifest
    if (-not (Test-Path $teamSkillsDir)) {
        New-Item -ItemType Directory -Path $teamSkillsDir -Force | Out-Null
    }
    $json = $manifest | ConvertTo-Json -Depth 5
    $json | Set-Content -Path $manifestPath -Encoding UTF8

    return $results
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

function Get-EngramProtocolContent {
    <#
    .SYNOPSIS
        Returns the Engram Memory Protocol markdown content from shared template.
        Single source of truth: templates/engram-protocol.md
    #>
    $kitRoot = Split-Path -Parent $PSScriptRoot
    Get-Content (Join-Path $kitRoot 'templates' 'engram-protocol.md') -Raw
}

function Update-InstructionsEngramProtocol {
    <#
    .SYNOPSIS
        Updates the engram-protocol section in an existing instructions file.
        If SkipEngramProtocol is set, removes existing markers instead of updating.
        If markers exist, replaces content between them.
        If no markers exist and not skipping, inserts after the Team Conventions header.
    .OUTPUTS
        $true if the file was changed, $false if content is the same.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [switch]$SkipEngramProtocol
    )

    if (-not (Test-Path $FilePath)) { return $false }

    $existing = Get-Content -Path $FilePath -Raw
    $startMarker = '<!-- team-ai-kit:engram-protocol -->'
    $endMarker = '<!-- /team-ai-kit:engram-protocol -->'

    $startIdx = $existing.IndexOf($startMarker)

    if ($SkipEngramProtocol) {
        # Remove existing engram protocol block if present
        if ($startIdx -ge 0) {
            $endIdx = $existing.IndexOf($endMarker, $startIdx)
            if ($endIdx -ge 0) {
                $endIdx += $endMarker.Length
                $updated = $existing.Substring(0, $startIdx) + $existing.Substring($endIdx)
                $updated = $updated -replace '(\r?\n){3,}', "`r`n`r`n"
                $updated = $updated.TrimEnd() + "`r`n"
                if ($updated -eq $existing) { return $false }
                [System.IO.File]::WriteAllText($FilePath, $updated, [System.Text.Encoding]::UTF8)
                return $true
            }
        }
        return $false
    }

    $protocolContent = Get-EngramProtocolContent
    $newSection = $protocolContent.Trim()
    if ($startIdx -ge 0) {
        $endIdx = $existing.IndexOf($endMarker, $startIdx)
        if ($endIdx -ge 0) {
            $endIdx += $endMarker.Length
            $updated = $existing.Substring(0, $startIdx) + $newSection + $existing.Substring($endIdx)
        }
        else {
            $updated = "$existing`n`n$newSection`n"
        }
    }
    else {
        # Insert after the header section (before pack rules or team rules)
        $updated = "$existing`n`n$newSection`n"
    }

    if ($updated -eq $existing) { return $false }

    [System.IO.File]::WriteAllText($FilePath, $updated, [System.Text.Encoding]::UTF8)
    return $true
}

function New-CopilotInstructions {
    <#
    .SYNOPSIS
        Generates the copilot-instructions.md content with team rules injected.
        Engram protocol is only included for IDEs where gentle-ai does NOT handle it
        (e.g. IntelliJ). For gentle-ai-supported IDEs, gentle-ai injects the protocol
        globally and team-ai-kit skips it to avoid duplication.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Role,
        [string]$PackRulesContent = '',
        [string]$TeamRulesContent = '',
        [switch]$SkipEngramProtocol
    )

    $header = @"
# Team AI Kit -- Copilot Instructions

> Auto-generated by team-ai-kit. Role: $Role
> Do not edit between team-ai-kit markers -- use team-ai-kit update to refresh.

---

## Team Conventions

- Follow the team's established patterns and conventions
- Always explain WHY, not just WHAT, when making decisions

"@

    $result = $header

    if (-not $SkipEngramProtocol) {
        $memoryProtocol = Get-EngramProtocolContent
        $result += $memoryProtocol
    }

    if ($PackRulesContent) {
        $result += "`n$PackRulesContent`n"
    }

    if ($TeamRulesContent) {
        $result += "`n<!-- team-ai-kit:team-rules -->`n"
        $result += $TeamRulesContent
        $result += "`n<!-- /team-ai-kit:team-rules -->`n"
    }

    return $result
}

function Update-InstructionsTeamRules {
    <#
    .SYNOPSIS
        Updates only the team-rules section in an existing instructions file.
        If markers exist, replaces content between them.
        If no markers exist, appends the section.
    .OUTPUTS
        $true if the file was changed, $false if content is the same.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string]$TeamRulesContent
    )

    if (-not (Test-Path $FilePath)) { return $false }

    $existing = Get-Content -Path $FilePath -Raw
    $startMarker = '<!-- team-ai-kit:team-rules -->'
    $endMarker = '<!-- /team-ai-kit:team-rules -->'

    $newSection = "$startMarker`n$TeamRulesContent`n$endMarker"

    $startIdx = $existing.IndexOf($startMarker)
    if ($startIdx -ge 0) {
        $endIdx = $existing.IndexOf($endMarker, $startIdx)
        if ($endIdx -ge 0) {
            $endIdx += $endMarker.Length
            $updated = $existing.Substring(0, $startIdx) + $newSection + $existing.Substring($endIdx)
        }
        else {
            $updated = "$existing`n`n$newSection`n"
        }
    }
    else {
        $updated = "$existing`n`n$newSection`n"
    }

    if ($updated -eq $existing) { return $false }

    [System.IO.File]::WriteAllText($FilePath, $updated, [System.Text.Encoding]::UTF8)
    return $true
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
        'cursor'   = 'cursor'
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

# ── Knowledge Repo ────────────────────────────────────────────────────────────

function Initialize-KnowledgeRepo {
    <#
    .SYNOPSIS
        Scaffolds the directory structure for a Team Knowledge Repo.
    .DESCRIPTION
        Creates skills/shared, skills/roles, and rules directories
        in the specified target directory.
    .OUTPUTS
        Hashtable with 'created' (array of created dirs) and 'path' (root).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TargetDir
    )

    $dirs = @(
        'skills/shared',
        'skills/roles',
        'rules'
    )

    $created = @()
    foreach ($dir in $dirs) {
        $fullPath = Join-Path $TargetDir $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
            $created += $dir
        }
    }

    return @{
        created = $created
        path    = $TargetDir
    }
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

# -- Uninstall -----------------------------------------------------------------

function Get-UninstallTargets {
    <#
    .SYNOPSIS
        Collects all files/dirs that team-ai-kit created in a project.
    .DESCRIPTION
        Returns an array of hashtables with Type (file|dir|hook) and Path.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    $targets = [System.Collections.ArrayList]::new()

    # 1. Project config
    $configPath = Join-Path $ProjectRoot '.team-ai-kit.json'
    if (Test-Path $configPath) {
        [void]$targets.Add(@{ Type = 'file'; Path = $configPath })
    }

    # 2. Instructions file
    $projectConfig = $null
    $projectConfig = Get-ProjectConfig -ProjectRoot $ProjectRoot
    $ide = $null
    if ($projectConfig -is [hashtable] -and $projectConfig.ContainsKey('ide')) {
        $ide = $projectConfig['ide']
    }
    if ($ide) {
        try {
            $instructionsPath = Get-IdeInstructionsPath -Ide $ide -ProjectRoot $ProjectRoot
            if ($instructionsPath -and (Test-Path $instructionsPath)) {
                [void]$targets.Add(@{ Type = 'file'; Path = $instructionsPath })
            }
        } catch { }
    }

    # 3. team-skills directory
    $globalSkillsDir = Join-Path $ProjectRoot 'team-skills'
    if (Test-Path $globalSkillsDir) {
        [void]$targets.Add(@{ Type = 'dir'; Path = $globalSkillsDir })
    }

    # 4. IDE-specific project skills
    if ($ide) {
        try {
            $projectSkillsDir = Get-IdeProjectSkillsDirectory -Ide $ide -ProjectRoot $ProjectRoot
            if ($projectSkillsDir -and (Test-Path $projectSkillsDir) -and $projectSkillsDir -ne $globalSkillsDir) {
                [void]$targets.Add(@{ Type = 'dir'; Path = $projectSkillsDir })
            }
        } catch { }
    }

    # 5. Git hooks
    $marker = '# [team-ai-kit] engram sync hook'
    $hooksDir = Join-Path $ProjectRoot '.git\hooks'
    foreach ($hookName in @('pre-commit', 'post-merge')) {
        $hookPath = Join-Path $hooksDir $hookName
        if (Test-Path $hookPath) {
            $content = Get-Content $hookPath -Raw -ErrorAction SilentlyContinue
            if ($content -and $content.Contains($marker)) {
                [void]$targets.Add(@{ Type = 'hook'; Path = $hookPath })
            }
        }
    }

    # 6. .gitattributes (only if it contains our marker)
    $gaMarker = '# [team-ai-kit] engram diff rules'
    $gaPath = Join-Path $ProjectRoot '.gitattributes'
    if (Test-Path $gaPath) {
        $gaContent = Get-Content $gaPath -Raw -ErrorAction SilentlyContinue
        if ($gaContent -and $gaContent.Contains($gaMarker)) {
            [void]$targets.Add(@{ Type = 'gitattributes'; Path = $gaPath })
        }
    }

    return @($targets)
}

function Remove-HookMarkerBlock {
    <#
    .SYNOPSIS
        Removes the team-ai-kit block from a git hook file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$HookPath
    )

    $marker = '# [team-ai-kit] engram sync hook'
    $lines = Get-Content $HookPath
    $cleaned = @()
    $inBlock = $false

    foreach ($line in $lines) {
        if ($line.Contains($marker)) {
            $inBlock = $true
            continue
        }
        if ($inBlock) {
            if ($line -eq 'fi') {
                $inBlock = $false
                continue
            }
            continue
        }
        $cleaned += $line
    }

    # Strip empty lines
    $cleaned = @($cleaned | Where-Object { $_.Trim() -ne '' })

    if ($cleaned.Count -eq 0 -or ($cleaned.Count -eq 1 -and $cleaned[0] -eq '#!/bin/sh')) {
        Remove-Item $HookPath -Force
    } else {
        $content = ($cleaned -join "`n") + "`n"
        $lfContent = $content -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($HookPath, $lfContent, [System.Text.Encoding]::ASCII)
    }
}

function Invoke-Uninstall {
    <#
    .SYNOPSIS
        Removes all team-ai-kit artifacts from a project.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    $removed = 0
    $targets = Get-UninstallTargets -ProjectRoot $ProjectRoot

    foreach ($target in $targets) {
        switch ($target.Type) {
            'hook' {
                Remove-HookMarkerBlock -HookPath $target.Path
                $removed++
            }
            'gitattributes' {
                Remove-GitAttributesBlock -ProjectRoot $ProjectRoot
                $removed++
            }
            'dir' {
                Remove-Item $target.Path -Recurse -Force
                $removed++
            }
            'file' {
                Remove-Item $target.Path -Force
                $removed++
            }
        }
    }

    # Remove global manifest
    $manifestPath = Get-SkillManifestPath
    if (Test-Path $manifestPath) {
        Remove-Item $manifestPath -Force
        $removed++
    }

    return @{ removed = $removed }
}
