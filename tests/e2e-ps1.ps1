# E2E tests for team-ai-kit PowerShell CLI
# Mirrors the bash E2E test suite (tests/e2e-bash.sh)
# Compatible with PS 5.1 (Join-Path 2 args only, Write-Host capture via child process)

$ErrorActionPreference = 'Continue'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitRoot = Split-Path -Parent $ScriptDir
$TestId = [System.Diagnostics.Process]::GetCurrentProcess().Id
$TestDir = Join-Path $env:TEMP "team-ai-kit-e2e-target-$TestId"
$FakeHome = Join-Path $env:TEMP "team-ai-kit-e2e-home-$TestId"
$Pass = 0
$Fail = 0

function Test-Pass { param([string]$Msg) Write-Host "  [PASS] $Msg" -ForegroundColor Green; $script:Pass++ }
function Test-Fail { param([string]$Msg) Write-Host "  [FAIL] $Msg" -ForegroundColor Red; $script:Fail++ }

function Remove-TestDirs {
    @($TestDir, $FakeHome) | ForEach-Object {
        if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Setup
New-Item -ItemType Directory -Path $FakeHome -Force | Out-Null

Write-Host "=== E2E: team-ai-kit PowerShell CLI ===" -ForegroundColor Cyan
Write-Host "KIT_ROOT: $KitRoot"
Write-Host "TEST_DIR: $TestDir"
Write-Host "HOME:     $FakeHome"
Write-Host ""

$KitScript = Join-Path (Join-Path $KitRoot 'bin') 'team-ai-kit.ps1'

# Helper: Run kit script in a child process to capture Write-Host output
# PS 5.1 Write-Host bypasses pipeline, so we must use a subprocess
function Invoke-Kit {
    param(
        [string]$ArgString,
        [string]$WorkDir,
        [hashtable]$EnvVars
    )
    $envSetup = ''
    if ($EnvVars) {
        foreach ($kv in $EnvVars.GetEnumerator()) {
            $envSetup += "`$env:$($kv.Key) = '$($kv.Value)'; "
        }
    }
    $cdCmd = ''
    if ($WorkDir) {
        $cdCmd = "Set-Location '$WorkDir'; "
    }
    $cmd = "${envSetup}${cdCmd}& '$KitScript' $ArgString"
    $result = powershell -ExecutionPolicy Bypass -NoProfile -Command $cmd 2>&1 | Out-String
    return $result
}

$envHash = @{ HOME = $FakeHome; USERPROFILE = $FakeHome }

# -- Test 1: Help ---
Write-Host "--- Test 1: help command ---"
$output = Invoke-Kit -ArgString 'help'
if ($output -match 'Team AI Kit') {
    Test-Pass "help shows banner"
} else {
    Test-Fail "help doesn't show banner"
}

# -- Test 2: Setup non-interactive ---
Write-Host "--- Test 2: setup non-interactive ---"
$output = Invoke-Kit -ArgString "setup -Ide vscode -Role frontend -TargetDir '$TestDir' -SkipPrerequisites -SkipGentleAi" -EnvVars $envHash
if ($output -match 'Setup Complete') {
    Test-Pass "setup completes"
} else {
    Test-Fail "setup didn't complete"
    Write-Host $output
}

# -- Test 3: Skills installed ---
Write-Host "--- Test 3: skills installed ---"
$skillsDir = Join-Path $TestDir 'team-skills'
if (Test-Path $skillsDir) {
    $skillCount = (Get-ChildItem -Path $skillsDir -Filter '*.md' -Recurse -File).Count
    if ($skillCount -eq 9) {
        Test-Pass "9 skills installed"
    } else {
        Test-Fail "expected 9 skills, got $skillCount"
    }
} else {
    Test-Fail "team-skills dir not found"
}

# -- Test 4: Config saved ---
Write-Host "--- Test 4: config saved ---"
$configPath = Join-Path (Join-Path $FakeHome '.team-ai-kit') 'config.json'
if (Test-Path $configPath) {
    Test-Pass "config.json exists"
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    if ($config.ide -eq 'vscode') {
        Test-Pass "config IDE = vscode"
    } else {
        Test-Fail "config IDE = '$($config.ide)'"
    }
} else {
    Test-Fail "config.json not found"
}

# -- Test 5: Manifest ---
Write-Host "--- Test 5: manifest ---"
$manifestPath = Join-Path (Join-Path $FakeHome '.team-ai-kit') 'manifest.json'
if (Test-Path $manifestPath) {
    Test-Pass "manifest.json exists"
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $mcount = ($manifest.files | Get-Member -MemberType NoteProperty).Count
    if ($mcount -eq 9) {
        Test-Pass "manifest tracks 9 files"
    } else {
        Test-Fail "manifest tracks $mcount files"
    }
} else {
    Test-Fail "manifest.json not found"
}

# -- Test 6: Modify + update ---
Write-Host "--- Test 6: user modification preserved ---"
$archSkill = Join-Path (Join-Path (Join-Path (Join-Path $TestDir 'team-skills') 'shared') 'architecture') 'SKILL.md'
if (Test-Path $archSkill) {
    Set-Content -Path $archSkill -Value '# MY CUSTOM ARCHITECTURE RULES'
    Invoke-Kit -ArgString "update -TargetDir '$TestDir'" -EnvVars $envHash | Out-Null
    $content = Get-Content $archSkill -Raw
    if ($content -match 'MY CUSTOM') {
        Test-Pass "user modification preserved"
    } else {
        Test-Fail "modification overwritten"
    }
} else {
    Test-Fail "architecture skill not found at $archSkill"
}

# -- Test 7: Status ---
Write-Host "--- Test 7: status ---"
$output = Invoke-Kit -ArgString 'status' -EnvVars $envHash
if ($output -match 'vscode') {
    Test-Pass "status shows IDE"
} else {
    Test-Fail "status doesn't show IDE"
    Write-Host $output
}

# -- Test 8: Doctor ---
Write-Host "--- Test 8: doctor ---"
$output = Invoke-Kit -ArgString 'doctor' -EnvVars $envHash
if ($output -match 'Doctor|Checking installation') {
    Test-Pass "doctor runs"
} else {
    Test-Fail "doctor didn't run"
    Write-Host $output
}

# -- Test 9: Init with dry-run ---
Write-Host "--- Test 9: init --dry-run ---"
$dryDir = Join-Path $env:TEMP "team-ai-kit-e2e-dry-$TestId"
$dryHome = Join-Path $env:TEMP "team-ai-kit-e2e-dryhome-$TestId"
New-Item -ItemType Directory -Path $dryHome -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $dryDir '.git') -Force | Out-Null
$dryEnv = @{ HOME = $dryHome; USERPROFILE = $dryHome }
Invoke-Kit -ArgString "setup -Ide vscode -Role frontend -TargetDir '$dryDir' -SkipPrerequisites -SkipGentleAi" -EnvVars $dryEnv | Out-Null
$output = Invoke-Kit -ArgString 'init -DryRun' -WorkDir $dryDir -EnvVars $dryEnv
if ($output -match 'DRY-RUN') {
    Test-Pass "init --dry-run shows DRY-RUN output"
} else {
    Test-Fail "init --dry-run should show DRY-RUN prefix"
    Write-Host $output
}
$projectFile = Join-Path $dryDir '.team-ai-kit.json'
if (-not (Test-Path $projectFile)) {
    Test-Pass "init --dry-run did not create .team-ai-kit.json"
} else {
    Test-Fail "init --dry-run should not create .team-ai-kit.json"
}
Remove-Item $dryDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $dryHome -Recurse -Force -ErrorAction SilentlyContinue

# -- Test 10: Uninstall ---
Write-Host "--- Test 10: uninstall ---"
$projectJson = Join-Path $TestDir '.team-ai-kit.json'
if (-not (Test-Path $projectJson)) {
    New-Item -ItemType Directory -Path (Join-Path $TestDir '.git') -Force | Out-Null
    Invoke-Kit -ArgString 'init' -WorkDir $TestDir -EnvVars $envHash | Out-Null
}
if (Test-Path $projectJson) {
    $output = Invoke-Kit -ArgString 'uninstall -Force' -WorkDir $TestDir -EnvVars $envHash
    if ($output -match '(?i)uninstalled') {
        Test-Pass "uninstall reports success"
    } else {
        Test-Fail "uninstall didn't report success"
        Write-Host $output
    }
    if (-not (Test-Path $projectJson)) {
        Test-Pass "uninstall removed .team-ai-kit.json"
    } else {
        Test-Fail "uninstall didn't remove .team-ai-kit.json"
    }
} else {
    Test-Fail "uninstall test: project not initialized"
}

# -- Test 11: Uninstall on non-initialized project ---
Write-Host "--- Test 11: uninstall on non-initialized project ---"
$uninstDir = Join-Path $env:TEMP "team-ai-kit-e2e-uninst-$TestId"
New-Item -ItemType Directory -Path $uninstDir -Force | Out-Null
$output = Invoke-Kit -ArgString 'uninstall -Force' -WorkDir $uninstDir -EnvVars $envHash
if ($output -match '(?i)no team-ai-kit project') {
    Test-Pass "uninstall rejects non-initialized project"
} else {
    Test-Fail "uninstall should reject non-initialized project"
    Write-Host $output
}
Remove-Item $uninstDir -Recurse -Force -ErrorAction SilentlyContinue

# -- Cleanup ---
Remove-TestDirs

# -- Summary ---
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "  PASS: $Pass  FAIL: $Fail" -ForegroundColor $(if ($Fail -eq 0) { 'Green' } else { 'Red' })
Write-Host "================================" -ForegroundColor Cyan
if ($Fail -eq 0) {
    Write-Host "  All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "  Some tests failed." -ForegroundColor Red
    exit 1
}
