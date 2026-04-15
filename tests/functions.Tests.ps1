#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Tests for lib/functions.ps1 -- Team AI Kit setup functions.
#>

BeforeAll {
    . "$PSScriptRoot\..\lib\functions.ps1"

    # Kit root is the repo root (parent of tests/)
    $script:kitRoot = (Resolve-Path "$PSScriptRoot\..").Path
}

# -- IDE-to-Agent Mapping ------------------------------------------------------

Describe 'Get-GentleAiAgentId' {
    It 'maps vscode to vscode-copilot' {
        Get-GentleAiAgentId -Ide 'vscode' | Should -Be 'vscode-copilot'
    }

    It 'maps opencode to opencode' {
        Get-GentleAiAgentId -Ide 'opencode' | Should -Be 'opencode'
    }

    It 'returns $null for intellij (no gentle-ai adapter)' {
        Get-GentleAiAgentId -Ide 'intellij' | Should -BeNullOrEmpty
    }

    It 'returns $null for unknown IDEs' {
        Get-GentleAiAgentId -Ide 'vim' | Should -BeNullOrEmpty
    }

    It 'is case-insensitive' {
        Get-GentleAiAgentId -Ide 'VSCode' | Should -Be 'vscode-copilot'
        Get-GentleAiAgentId -Ide 'OPENCODE' | Should -Be 'opencode'
    }
}

Describe 'Test-GentleAiSupportsIde' {
    It 'returns $true for vscode' {
        Test-GentleAiSupportsIde -Ide 'vscode' | Should -BeTrue
    }

    It 'returns $true for opencode' {
        Test-GentleAiSupportsIde -Ide 'opencode' | Should -BeTrue
    }

    It 'returns $false for intellij' {
        Test-GentleAiSupportsIde -Ide 'intellij' | Should -BeFalse
    }

    It 'returns $false for unknown IDEs' {
        Test-GentleAiSupportsIde -Ide 'vim' | Should -BeFalse
    }
}

# -- Validation Functions ------------------------------------------------------

Describe 'Test-ValidIde' {
    It 'returns $true for supported IDEs' {
        Test-ValidIde -Ide 'vscode' | Should -BeTrue
        Test-ValidIde -Ide 'intellij' | Should -BeTrue
        Test-ValidIde -Ide 'opencode' | Should -BeTrue
    }

    It 'is case-insensitive' {
        Test-ValidIde -Ide 'VSCode' | Should -BeTrue
        Test-ValidIde -Ide 'OPENCODE' | Should -BeTrue
    }

    It 'returns $false for unsupported IDEs' {
        Test-ValidIde -Ide 'vim' | Should -BeFalse
        Test-ValidIde -Ide 'notepad' | Should -BeFalse
        Test-ValidIde -Ide '' | Should -BeFalse
    }
}

Describe 'Test-ValidRole' {
    It 'returns $true for supported roles' {
        Test-ValidRole -Role 'frontend' | Should -BeTrue
        Test-ValidRole -Role 'backend-node' | Should -BeTrue
        Test-ValidRole -Role 'devops' | Should -BeTrue
        Test-ValidRole -Role 'python' | Should -BeTrue
    }

    It 'is case-insensitive' {
        Test-ValidRole -Role 'Frontend' | Should -BeTrue
        Test-ValidRole -Role 'DEVOPS' | Should -BeTrue
    }

    It 'returns $false for unsupported roles' {
        Test-ValidRole -Role 'mobile' | Should -BeFalse
        Test-ValidRole -Role 'data-science' | Should -BeFalse
        Test-ValidRole -Role '' | Should -BeFalse
    }
}

Describe 'Test-ValidProvider' {
    It 'returns $true for supported providers' {
        Test-ValidProvider -Provider 'openai' | Should -BeTrue
        Test-ValidProvider -Provider 'azure-openai' | Should -BeTrue
        Test-ValidProvider -Provider 'anthropic' | Should -BeTrue
        Test-ValidProvider -Provider 'github-copilot' | Should -BeTrue
    }

    It 'returns $false for unsupported providers' {
        Test-ValidProvider -Provider 'google' | Should -BeFalse
        Test-ValidProvider -Provider '' | Should -BeFalse
    }
}

# -- Skills Management ---------------------------------------------------------

Describe 'Get-SharedSkillPaths' {
    It 'returns skill files from skills/shared/' {
        $skills = Get-SharedSkillPaths -KitRoot $script:kitRoot
        $skills | Should -Not -BeNullOrEmpty
        $skills | ForEach-Object { $_ | Should -BeLike '*.md' }
    }

    It 'includes architecture skill' {
        $skills = Get-SharedSkillPaths -KitRoot $script:kitRoot
        ($skills | Where-Object { $_ -like '*architecture*' }) | Should -Not -BeNullOrEmpty
    }

    It 'includes code-quality skill' {
        $skills = Get-SharedSkillPaths -KitRoot $script:kitRoot
        ($skills | Where-Object { $_ -like '*code-quality*' }) | Should -Not -BeNullOrEmpty
    }

    It 'includes all 5 shared skills' {
        $skills = Get-SharedSkillPaths -KitRoot $script:kitRoot
        $skills.Count | Should -Be 5
    }

    It 'returns empty array for nonexistent path' {
        $skills = Get-SharedSkillPaths -KitRoot 'C:\nonexistent'
        $skills | Should -BeNullOrEmpty
    }
}

Describe 'Get-RoleSkillPaths' {
    It 'returns frontend skills' {
        $skills = Get-RoleSkillPaths -KitRoot $script:kitRoot -Role 'frontend'
        $skills | Should -Not -BeNullOrEmpty
        $skills.Count | Should -Be 2  # react + nextjs
    }

    It 'returns backend-node skills' {
        $skills = Get-RoleSkillPaths -KitRoot $script:kitRoot -Role 'backend-node'
        $skills | Should -Not -BeNullOrEmpty
        $skills.Count | Should -Be 2  # api-design + testing
    }

    It 'returns devops skills' {
        $skills = Get-RoleSkillPaths -KitRoot $script:kitRoot -Role 'devops'
        $skills | Should -Not -BeNullOrEmpty
        $skills.Count | Should -Be 2  # cicd + monitoring
    }

    It 'returns python skills' {
        $skills = Get-RoleSkillPaths -KitRoot $script:kitRoot -Role 'python'
        $skills | Should -Not -BeNullOrEmpty
        $skills.Count | Should -Be 2  # api-design + testing
    }

    It 'returns empty array for nonexistent role' {
        $skills = Get-RoleSkillPaths -KitRoot $script:kitRoot -Role 'mobile'
        $skills | Should -BeNullOrEmpty
    }
}

Describe 'Get-AllSkillPathsForRole' {
    It 'combines shared + role skills for frontend' {
        $all = Get-AllSkillPathsForRole -KitRoot $script:kitRoot -Role 'frontend'
        $all.Count | Should -Be 7  # 5 shared + 2 frontend
    }

    It 'combines shared + role skills for backend-node' {
        $all = Get-AllSkillPathsForRole -KitRoot $script:kitRoot -Role 'backend-node'
        $all.Count | Should -Be 7  # 5 shared + 2 backend
    }

    It 'combines shared + role skills for devops' {
        $all = Get-AllSkillPathsForRole -KitRoot $script:kitRoot -Role 'devops'
        $all.Count | Should -Be 7  # 5 shared + 2 devops
    }

    It 'combines shared + role skills for python' {
        $all = Get-AllSkillPathsForRole -KitRoot $script:kitRoot -Role 'python'
        $all.Count | Should -Be 7  # 5 shared + 2 python
    }
}

Describe 'Get-PackRulesPath' {
    It 'returns path for existing role packs' {
        foreach ($role in @('frontend', 'backend-node', 'devops', 'python')) {
            $path = Get-PackRulesPath -KitRoot $script:kitRoot -Role $role
            $path | Should -Not -BeNullOrEmpty
            Test-Path $path | Should -BeTrue
        }
    }

    It 'returns $null for nonexistent role' {
        $path = Get-PackRulesPath -KitRoot $script:kitRoot -Role 'mobile'
        $path | Should -BeNullOrEmpty
    }
}

# -- Skills Installation -------------------------------------------------------

Describe 'Install-TeamSkills' {
    BeforeAll {
        $script:tempDir = Join-Path $env:TEMP "team-ai-kit-test-$(Get-Random)"
    }

    AfterAll {
        if (Test-Path $script:tempDir) {
            Remove-Item -Path $script:tempDir -Recurse -Force
        }
    }

    It 'copies skills to target directory' {
        $copied = Install-TeamSkills -KitRoot $script:kitRoot -Role 'frontend' -TargetDir $script:tempDir
        $copied | Should -Not -BeNullOrEmpty
        $copied.Count | Should -Be 7
    }

    It 'creates team-skills subdirectory structure' {
        $teamSkillsDir = Join-Path $script:tempDir 'team-skills'
        Test-Path $teamSkillsDir | Should -BeTrue
    }

    It 'preserves shared skills under team-skills/shared/' {
        $sharedArch = Join-Path $script:tempDir 'team-skills\shared\architecture\SKILL.md'
        Test-Path $sharedArch | Should -BeTrue
    }

    It 'preserves role skills under team-skills/roles/' {
        $roleReact = Join-Path $script:tempDir 'team-skills\roles\frontend\react.skill.md'
        Test-Path $roleReact | Should -BeTrue
    }

    It 'copies actual content (not empty files)' {
        $sharedArch = Join-Path $script:tempDir 'team-skills\shared\architecture\SKILL.md'
        $content = Get-Content $sharedArch -Raw
        $content | Should -Not -BeNullOrEmpty
        $content | Should -BeLike '*architecture*'
    }
}

# -- IDE Config Paths ----------------------------------------------------------

Describe 'Get-IdeSkillsDirectory' {
    It 'returns .copilot/skills path for vscode' {
        $path = Get-IdeSkillsDirectory -Ide 'vscode'
        $path | Should -BeLike '*.copilot?skills*'
    }

    It 'returns .copilot/skills path for intellij' {
        $path = Get-IdeSkillsDirectory -Ide 'intellij'
        $path | Should -BeLike '*.copilot?skills*'
    }

    It 'returns opencode skills path for opencode' {
        $path = Get-IdeSkillsDirectory -Ide 'opencode'
        $path | Should -BeLike '*opencode*skills*'
    }

    It 'throws for unsupported IDE' {
        { Get-IdeSkillsDirectory -Ide 'vim' } | Should -Throw '*Unsupported IDE*'
    }
}

Describe 'Get-IdeInstructionsPath' {
    It 'returns copilot-instructions.md for vscode' {
        $path = Get-IdeInstructionsPath -Ide 'vscode' -ProjectRoot 'C:\project'
        $path | Should -BeLike '*copilot-instructions.md'
    }

    It 'returns copilot-instructions.md for intellij' {
        $path = Get-IdeInstructionsPath -Ide 'intellij' -ProjectRoot 'C:\project'
        $path | Should -BeLike '*copilot-instructions.md'
    }

    It 'returns AGENTS.md for opencode' {
        $path = Get-IdeInstructionsPath -Ide 'opencode' -ProjectRoot 'C:\project'
        $path | Should -BeLike '*AGENTS.md'
    }

    It 'throws for unsupported IDE' {
        { Get-IdeInstructionsPath -Ide 'vim' -ProjectRoot 'C:\project' } | Should -Throw
    }
}

# -- Config Generation ---------------------------------------------------------

Describe 'New-VsCodeMcpConfig' {
    It 'generates valid JSON' {
        $json = New-VsCodeMcpConfig -EngramBinaryPath 'C:\engram.exe'
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'includes engram server config' {
        $json = New-VsCodeMcpConfig -EngramBinaryPath 'C:\engram.exe'
        $config = $json | ConvertFrom-Json
        $config.servers.engram | Should -Not -BeNullOrEmpty
        $config.servers.engram.command | Should -Be 'C:\engram.exe'
    }

    It 'includes context7 server config' {
        $json = New-VsCodeMcpConfig -EngramBinaryPath 'C:\engram.exe'
        $config = $json | ConvertFrom-Json
        $config.servers.context7 | Should -Not -BeNullOrEmpty
        $config.servers.context7.url | Should -BeLike '*context7*'
    }
}

Describe 'New-EngramSyncConfig' {
    It 'returns config with correct defaults' {
        $config = New-EngramSyncConfig -SyncRepoUrl 'https://dev.azure.com/team/repo'
        $config.syncRepo | Should -Be 'https://dev.azure.com/team/repo'
        $config.port | Should -Be 7437
        $config.mode | Should -Be 'local-sync'
    }

    It 'allows custom port' {
        $config = New-EngramSyncConfig -SyncRepoUrl 'https://repo' -Port 8080
        $config.port | Should -Be 8080
    }
}

# -- Instructions Generation ---------------------------------------------------

Describe 'New-CopilotInstructions' {
    It 'includes role in header' {
        $instructions = New-CopilotInstructions -Role 'frontend'
        $instructions | Should -BeLike '*frontend*'
    }

    It 'includes team conventions section' {
        $instructions = New-CopilotInstructions -Role 'backend-node'
        $instructions | Should -BeLike '*Team Conventions*'
    }

    It 'appends pack rules when provided' {
        $rules = "## My Custom Rules`nRule 1: Do this"
        $instructions = New-CopilotInstructions -Role 'frontend' -PackRulesContent $rules
        $instructions | Should -BeLike '*My Custom Rules*'
        $instructions | Should -BeLike '*Rule 1*'
    }

    It 'works without pack rules' {
        $instructions = New-CopilotInstructions -Role 'devops'
        $instructions | Should -Not -BeNullOrEmpty
        $instructions | Should -BeLike '*devops*'
    }
}

# -- Template Engine -----------------------------------------------------------

Describe 'Get-TemplateDirectory' {
    It 'returns intellij-copilot dir for intellij' {
        $dir = Get-TemplateDirectory -KitRoot $script:kitRoot -Ide 'intellij'
        $dir | Should -BeLike '*intellij-copilot*'
        Test-Path $dir | Should -BeTrue
    }

    It 'returns $null for vscode (templates removed -- gentle-ai handles it)' {
        $dir = Get-TemplateDirectory -KitRoot $script:kitRoot -Ide 'vscode'
        $dir | Should -BeNullOrEmpty
    }

    It 'returns $null for opencode (templates removed -- gentle-ai handles it)' {
        $dir = Get-TemplateDirectory -KitRoot $script:kitRoot -Ide 'opencode'
        $dir | Should -BeNullOrEmpty
    }

    It 'throws for unsupported IDE' {
        { Get-TemplateDirectory -KitRoot $script:kitRoot -Ide 'vim' } | Should -Throw '*Unsupported IDE*'
    }
}

Describe 'Get-TemplateFiles' {
    It 'finds .template files for intellij' {
        $dir = Get-TemplateDirectory -KitRoot $script:kitRoot -Ide 'intellij'
        $files = Get-TemplateFiles -TemplateDir $dir
        $files | Should -Not -BeNullOrEmpty
        $files | ForEach-Object { $_.Name | Should -BeLike '*.template' }
    }

    It 'returns empty for nonexistent dir' {
        $files = Get-TemplateFiles -TemplateDir 'C:\nonexistent'
        $files | Should -BeNullOrEmpty
    }
}

Describe 'Expand-Template' {
    It 'replaces single placeholder' {
        $result = Expand-Template -Content 'Hello {{NAME}}!' -Variables @{ NAME = 'World' }
        $result | Should -Be 'Hello World!'
    }

    It 'replaces multiple placeholders' {
        $content = 'IDE: {{IDE}}, Role: {{ROLE}}'
        $result = Expand-Template -Content $content -Variables @{ IDE = 'vscode'; ROLE = 'frontend' }
        $result | Should -Be 'IDE: vscode, Role: frontend'
    }

    It 'leaves unmatched placeholders as-is' {
        $result = Expand-Template -Content '{{KNOWN}} and {{UNKNOWN}}' -Variables @{ KNOWN = 'yes' }
        $result | Should -Be 'yes and {{UNKNOWN}}'
    }

    It 'handles empty variables hashtable' {
        $result = Expand-Template -Content 'No vars {{HERE}}' -Variables @{}
        $result | Should -Be 'No vars {{HERE}}'
    }
}

Describe 'Install-Templates' {
    BeforeAll {
        $script:tplTempDir = Join-Path $env:TEMP "team-ai-kit-tpl-test-$(Get-Random)"
    }

    AfterAll {
        if (Test-Path $script:tplTempDir) {
            Remove-Item -Path $script:tplTempDir -Recurse -Force
        }
    }

    It 'expands and copies IntelliJ templates to target dir' {
        $tplDir = Get-TemplateDirectory -KitRoot $script:kitRoot -Ide 'intellij'
        $vars = @{
            ENGRAM_BINARY_PATH = 'C:\engram.exe'
        }
        $created = Install-Templates -TemplateDir $tplDir -TargetDir $script:tplTempDir -Variables $vars
        $created | Should -Not -BeNullOrEmpty
    }

    It 'creates files without .template extension' {
        $created = Get-ChildItem -Path $script:tplTempDir -Recurse -File
        $created | ForEach-Object { $_.Name | Should -Not -BeLike '*.template' }
    }

    It 'replaces placeholders in expanded files' {
        $mcpFile = Join-Path $script:tplTempDir 'mcp.json'
        if (Test-Path $mcpFile) {
            $content = Get-Content $mcpFile -Raw
            $content | Should -BeLike '*engram.exe*'
            $content | Should -Not -BeLike '*{{ENGRAM_BINARY_PATH}}*'
        }
    }
}

# -- Summary -------------------------------------------------------------------

Describe 'New-SetupSummary' {
    It 'includes all configuration values' {
        $summary = New-SetupSummary -Ide 'vscode' -Role 'frontend' -Provider 'openai' -SkillsCopied 7
        $summary | Should -BeLike '*vscode*'
        $summary | Should -BeLike '*frontend*'
        $summary | Should -BeLike '*openai*'
        $summary | Should -BeLike '*7*'
    }

    It 'includes gentle-ai status' {
        $summary = New-SetupSummary -Ide 'vscode' -Role 'frontend' -Provider 'github-copilot' -SkillsCopied 7 -GentleAiStatus 'configured'
        $summary | Should -BeLike '*configured*'
    }

    It 'shows default gentle-ai status when not specified' {
        $summary = New-SetupSummary -Ide 'intellij' -Role 'backend-node' -Provider 'github-copilot' -SkillsCopied 7
        $summary | Should -BeLike '*n/a*'
    }
}

# -- Config Persistence --------------------------------------------------------

Describe 'Get-TeamAiKitConfigDir' {
    It 'returns a path under USERPROFILE' {
        $dir = Get-TeamAiKitConfigDir
        $dir | Should -BeLike "$env:USERPROFILE*"
    }

    It 'returns a path ending in .team-ai-kit' {
        $dir = Get-TeamAiKitConfigDir
        $dir | Should -BeLike '*.team-ai-kit'
    }
}

Describe 'Get-TeamAiKitConfigPath' {
    It 'returns a path ending in config.json' {
        $path = Get-TeamAiKitConfigPath
        $path | Should -BeLike '*config.json'
    }

    It 'is inside the config dir' {
        $path = Get-TeamAiKitConfigPath
        $dir = Get-TeamAiKitConfigDir
        $path | Should -BeLike "$dir*"
    }
}

Describe 'Get-TeamAiKitConfig' {
    It 'returns a hashtable with expected keys when no config exists' {
        # Use a temp USERPROFILE to avoid touching real config
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-config-test-$(Get-Random)"
        try {
            $config = Get-TeamAiKitConfig
            $config | Should -BeOfType [hashtable]
            $config.ContainsKey('ide') | Should -BeTrue
            $config.ContainsKey('role') | Should -BeTrue
            $config.ContainsKey('provider') | Should -BeTrue
            $config.ContainsKey('teamRepo') | Should -BeTrue
            $config.ContainsKey('installedAt') | Should -BeTrue
            $config.ContainsKey('lastUpdate') | Should -BeTrue
            $config.ContainsKey('version') | Should -BeTrue
            $config.ide | Should -BeNullOrEmpty
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }
}

Describe 'Save-TeamAiKitConfig' {
    BeforeAll {
        $script:configTestDir = Join-Path $env:TEMP "team-ai-kit-config-save-$(Get-Random)"
    }

    AfterAll {
        if (Test-Path $script:configTestDir) {
            Remove-Item -Path $script:configTestDir -Recurse -Force
        }
    }

    It 'creates config directory and file' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = $script:configTestDir
        try {
            $config = @{
                ide         = 'vscode'
                role        = 'frontend'
                provider    = 'github-copilot'
                teamRepo    = $null
                installedAt = '2026-04-14T00:00:00'
                lastUpdate  = '2026-04-14T00:00:00'
                version     = '2.0.0'
            }
            $path = Save-TeamAiKitConfig -Config $config
            Test-Path $path | Should -BeTrue
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }

    It 'saves valid JSON that can be read back' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = $script:configTestDir
        try {
            $configPath = Get-TeamAiKitConfigPath
            $raw = Get-Content $configPath -Raw
            { $raw | ConvertFrom-Json } | Should -Not -Throw
            $parsed = $raw | ConvertFrom-Json
            $parsed.ide | Should -Be 'vscode'
            $parsed.role | Should -Be 'frontend'
            $parsed.provider | Should -Be 'github-copilot'
            $parsed.version | Should -Be '2.0.0'
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }

    It 'config roundtrips through Save + Get' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = $script:configTestDir
        try {
            $readBack = Get-TeamAiKitConfig
            $readBack | Should -BeOfType [hashtable]
            $readBack.ide | Should -Be 'vscode'
            $readBack.role | Should -Be 'frontend'
            $readBack.provider | Should -Be 'github-copilot'
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }
}

Describe 'Test-FirstRun' {
    It 'returns $true when no config exists' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-firstrun-$(Get-Random)"
        try {
            Test-FirstRun | Should -BeTrue
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }

    It 'returns $false when config exists' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-firstrun2-$(Get-Random)"
        try {
            # Create a config
            Save-TeamAiKitConfig -Config @{ ide = 'vscode' } | Out-Null
            Test-FirstRun | Should -BeFalse
        }
        finally {
            $env:USERPROFILE = $originalProfile
            $tempDir = Join-Path $env:TEMP "team-ai-kit-firstrun2-*"
            Get-ChildItem $env:TEMP -Directory -Filter 'team-ai-kit-firstrun2-*' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# -- Command Validation --------------------------------------------------------

Describe 'Test-ValidCommand' {
    It 'returns $true for supported commands' {
        Test-ValidCommand -Command 'setup' | Should -BeTrue
        Test-ValidCommand -Command 'update' | Should -BeTrue
        Test-ValidCommand -Command 'status' | Should -BeTrue
        Test-ValidCommand -Command 'doctor' | Should -BeTrue
        Test-ValidCommand -Command 'help' | Should -BeTrue
    }

    It 'is case-insensitive' {
        Test-ValidCommand -Command 'Setup' | Should -BeTrue
        Test-ValidCommand -Command 'HELP' | Should -BeTrue
    }

    It 'returns $false for unsupported commands' {
        Test-ValidCommand -Command 'install' | Should -BeFalse
        Test-ValidCommand -Command 'run' | Should -BeFalse
        Test-ValidCommand -Command '' | Should -BeFalse
    }
}

# -- Team Repo Management -----------------------------------------------------

Describe 'Get-TeamRepoLocalPath' {
    It 'returns a path under the config dir' {
        $configDir = Get-TeamAiKitConfigDir
        $repoPath = Get-TeamRepoLocalPath
        $repoPath | Should -BeLike "$configDir*"
    }

    It 'returns a path ending in team-content' {
        Get-TeamRepoLocalPath | Should -BeLike '*team-content'
    }
}

Describe 'Test-TeamRepoConfigured' {
    It 'returns $false when no team repo in config' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-teamrepo-$(Get-Random)"
        try {
            Test-TeamRepoConfigured | Should -BeFalse
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }

    It 'returns $true when team repo is configured' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-teamrepo2-$(Get-Random)"
        try {
            Save-TeamAiKitConfig -Config @{ teamRepo = 'https://dev.azure.com/team/knowledge' } | Out-Null
            Test-TeamRepoConfigured | Should -BeTrue
        }
        finally {
            $env:USERPROFILE = $originalProfile
            Get-ChildItem $env:TEMP -Directory -Filter 'team-ai-kit-teamrepo2-*' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Test-TeamRepoCloned' {
    It 'returns $false when team-content dir does not exist' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-cloned-$(Get-Random)"
        try {
            Test-TeamRepoCloned | Should -BeFalse
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }
}

Describe 'Get-TeamRepoSkillPaths' {
    It 'returns empty array when team repo not cloned' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-reposkills-$(Get-Random)"
        try {
            $paths = Get-TeamRepoSkillPaths -Role 'frontend'
            $paths | Should -BeNullOrEmpty
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }

    It 'finds skills in a mock team repo structure' {
        $originalProfile = $env:USERPROFILE
        $tempProfile = Join-Path $env:TEMP "team-ai-kit-reposkills2-$(Get-Random)"
        $env:USERPROFILE = $tempProfile
        try {
            # Create mock team repo structure
            $teamContent = Get-TeamRepoLocalPath
            $sharedSkill = Join-Path $teamContent 'skills\shared\e2e-testing\SKILL.md'
            $roleSkill = Join-Path $teamContent 'skills\roles\frontend\storybook.skill.md'
            New-Item -ItemType Directory -Path (Split-Path $sharedSkill -Parent) -Force | Out-Null
            New-Item -ItemType Directory -Path (Split-Path $roleSkill -Parent) -Force | Out-Null
            Set-Content -Path $sharedSkill -Value '# E2E Testing skill'
            Set-Content -Path $roleSkill -Value '# Storybook skill'

            $paths = Get-TeamRepoSkillPaths -Role 'frontend'
            $paths.Count | Should -Be 2
            ($paths | Where-Object { $_ -like '*e2e-testing*' }) | Should -Not -BeNullOrEmpty
            ($paths | Where-Object { $_ -like '*storybook*' }) | Should -Not -BeNullOrEmpty
        }
        finally {
            $env:USERPROFILE = $originalProfile
            if (Test-Path $tempProfile) { Remove-Item -Recurse -Force $tempProfile -ErrorAction SilentlyContinue }
        }
    }
}

# -- Skill Manifest & Hash Tracking -------------------------------------------

Describe 'Get-SkillManifestPath' {
    It 'returns a path ending in manifest.json' {
        Get-SkillManifestPath | Should -BeLike '*manifest.json'
    }

    It 'is inside the config dir' {
        $configDir = Get-TeamAiKitConfigDir
        Get-SkillManifestPath | Should -BeLike "$configDir*"
    }
}

Describe 'Get-SkillManifest' {
    It 'returns empty manifest when file does not exist' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-manifest-$(Get-Random)"
        try {
            $manifest = Get-SkillManifest
            $manifest | Should -BeOfType [hashtable]
            $manifest.files | Should -BeOfType [hashtable]
            $manifest.files.Count | Should -Be 0
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }
}

Describe 'Save-SkillManifest' {
    BeforeAll {
        $script:manifestTestDir = Join-Path $env:TEMP "team-ai-kit-manifest-save-$(Get-Random)"
    }

    AfterAll {
        if (Test-Path $script:manifestTestDir) {
            Remove-Item -Path $script:manifestTestDir -Recurse -Force
        }
    }

    It 'creates manifest file with tracked files' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = $script:manifestTestDir
        try {
            $manifest = @{
                files = @{
                    'team-skills\shared\architecture\SKILL.md' = @{
                        hash        = 'ABC123'
                        source      = 'default'
                        installedAt = '2026-04-14T00:00:00'
        }
    }
}

# -- Project Init Functions ----------------------------------------------------

Describe 'Get-ProjectConfigPath' {
    It 'returns .team-ai-kit.json in the project root' {
        $path = Get-ProjectConfigPath -ProjectRoot 'C:\projects\my-app'
        $path | Should -Be 'C:\projects\my-app\.team-ai-kit.json'
    }
}

Describe 'Test-ProjectInitialized' {
    BeforeAll {
        $script:initTestDir = Join-Path $TestDrive 'init-test-project'
        New-Item -ItemType Directory -Path $script:initTestDir -Force | Out-Null
    }

    It 'returns $false when .team-ai-kit.json does not exist' {
        Test-ProjectInitialized -ProjectRoot $script:initTestDir | Should -BeFalse
    }

    It 'returns $true when .team-ai-kit.json exists' {
        $configPath = Join-Path $script:initTestDir '.team-ai-kit.json'
        '{"role":"frontend"}' | Set-Content -Path $configPath
        Test-ProjectInitialized -ProjectRoot $script:initTestDir | Should -BeTrue
    }
}

Describe 'Save-ProjectConfig and Get-ProjectConfig' {
    BeforeAll {
        $script:configTestDir = Join-Path $TestDrive 'config-test-project'
        New-Item -ItemType Directory -Path $script:configTestDir -Force | Out-Null
    }

    It 'saves and reads project config correctly' {
        $config = @{
            role          = 'backend-node'
            ide           = 'vscode'
            initializedAt = '2026-04-15T00:00:00Z'
            lastSync      = '2026-04-15T00:00:00Z'
            version       = '2.0.0'
        }
        $savedPath = Save-ProjectConfig -ProjectRoot $script:configTestDir -Config $config
        $savedPath | Should -Not -BeNullOrEmpty
        Test-Path $savedPath | Should -BeTrue

        $loaded = Get-ProjectConfig -ProjectRoot $script:configTestDir
        $loaded.role | Should -Be 'backend-node'
        $loaded.ide | Should -Be 'vscode'
        $loaded.version | Should -Be '2.0.0'
    }

    It 'returns $null when no config exists' {
        $emptyDir = Join-Path $TestDrive 'empty-project'
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        Get-ProjectConfig -ProjectRoot $emptyDir | Should -BeNullOrEmpty
    }
}

Describe 'Initialize-SharedEngram' {
    BeforeAll {
        $script:engramTestDir = Join-Path $TestDrive 'engram-test-project'
        New-Item -ItemType Directory -Path $script:engramTestDir -Force | Out-Null
    }

    It 'creates shared-engram directory' {
        $result = Initialize-SharedEngram -ProjectRoot $script:engramTestDir
        $result.path | Should -Be (Join-Path $script:engramTestDir 'shared-engram')
        Test-Path $result.path | Should -BeTrue
    }

    It 'creates .gitkeep file' {
        $gitkeepPath = Join-Path $script:engramTestDir 'shared-engram\.gitkeep'
        Test-Path $gitkeepPath | Should -BeTrue
    }

    It 'is idempotent (safe to run twice)' {
        $result = Initialize-SharedEngram -ProjectRoot $script:engramTestDir
        $result.path | Should -Not -BeNullOrEmpty
        Test-Path $result.path | Should -BeTrue
    }
}

Describe 'New-InitSummary' {
    It 'generates summary with exported observations' {
        $summary = New-InitSummary -Ide 'vscode' -Role 'frontend' -InstructionsPath '.github/copilot-instructions.md' -EngramExported 5
        $summary | Should -BeLike '*Project Initialized*'
        $summary | Should -BeLike '*vscode*'
        $summary | Should -BeLike '*frontend*'
        $summary | Should -BeLike '*5 observations exported*'
    }

    It 'generates summary with no observations' {
        $summary = New-InitSummary -Ide 'opencode' -Role 'devops'
        $summary | Should -BeLike '*Project Initialized*'
        $summary | Should -BeLike '*no observations yet*'
    }
}

Describe 'Test-ValidCommand includes init' {
    It 'accepts init as valid command' {
        Test-ValidCommand -Command 'init' | Should -BeTrue
    }

    It 'still accepts all original commands' {
        Test-ValidCommand -Command 'setup' | Should -BeTrue
        Test-ValidCommand -Command 'update' | Should -BeTrue
        Test-ValidCommand -Command 'status' | Should -BeTrue
        Test-ValidCommand -Command 'doctor' | Should -BeTrue
        Test-ValidCommand -Command 'help' | Should -BeTrue
    }
}
            $path = Save-SkillManifest -Manifest $manifest
            Test-Path $path | Should -BeTrue
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }

    It 'manifest roundtrips through Save + Get' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = $script:manifestTestDir
        try {
            $readBack = Get-SkillManifest
            $readBack.files.Count | Should -Be 1
            $readBack.files['team-skills\shared\architecture\SKILL.md'].hash | Should -Be 'ABC123'
            $readBack.files['team-skills\shared\architecture\SKILL.md'].source | Should -Be 'default'
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }
}

Describe 'Get-FileContentHash' {
    It 'returns a SHA256 hash for existing file' {
        $tempFile = Join-Path $env:TEMP "team-ai-kit-hash-$(Get-Random).txt"
        try {
            Set-Content -Path $tempFile -Value 'test content'
            $hash = Get-FileContentHash -FilePath $tempFile
            $hash | Should -Not -BeNullOrEmpty
            $hash.Length | Should -Be 64  # SHA256 = 64 hex chars
        }
        finally {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    }

    It 'returns $null for nonexistent file' {
        Get-FileContentHash -FilePath 'C:\nonexistent\file.txt' | Should -BeNullOrEmpty
    }

    It 'returns same hash for same content' {
        $tempFile1 = Join-Path $env:TEMP "team-ai-kit-hash1-$(Get-Random).txt"
        $tempFile2 = Join-Path $env:TEMP "team-ai-kit-hash2-$(Get-Random).txt"
        try {
            Set-Content -Path $tempFile1 -Value 'identical content'
            Set-Content -Path $tempFile2 -Value 'identical content'
            $hash1 = Get-FileContentHash -FilePath $tempFile1
            $hash2 = Get-FileContentHash -FilePath $tempFile2
            $hash1 | Should -Be $hash2
        }
        finally {
            Remove-Item $tempFile1, $tempFile2 -ErrorAction SilentlyContinue
        }
    }

    It 'returns different hash for different content' {
        $tempFile1 = Join-Path $env:TEMP "team-ai-kit-hash3-$(Get-Random).txt"
        $tempFile2 = Join-Path $env:TEMP "team-ai-kit-hash4-$(Get-Random).txt"
        try {
            Set-Content -Path $tempFile1 -Value 'content A'
            Set-Content -Path $tempFile2 -Value 'content B'
            $hash1 = Get-FileContentHash -FilePath $tempFile1
            $hash2 = Get-FileContentHash -FilePath $tempFile2
            $hash1 | Should -Not -Be $hash2
        }
        finally {
            Remove-Item $tempFile1, $tempFile2 -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Test-SkillModifiedByUser' {
    It 'returns $false when file does not exist' {
        $manifest = @{ files = @{} }
        Test-SkillModifiedByUser -FilePath 'C:\nonexistent.md' -ManifestKey 'key' -Manifest $manifest | Should -BeFalse
    }

    It 'returns $true when file exists but not in manifest (user-created)' {
        $tempFile = Join-Path $env:TEMP "team-ai-kit-mod-$(Get-Random).txt"
        try {
            Set-Content -Path $tempFile -Value 'user created'
            $manifest = @{ files = @{} }
            Test-SkillModifiedByUser -FilePath $tempFile -ManifestKey 'key' -Manifest $manifest | Should -BeTrue
        }
        finally {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    }

    It 'returns $false when file hash matches manifest' {
        $tempFile = Join-Path $env:TEMP "team-ai-kit-mod2-$(Get-Random).txt"
        try {
            Set-Content -Path $tempFile -Value 'original content'
            $hash = Get-FileContentHash -FilePath $tempFile
            $manifest = @{
                files = @{
                    'mykey' = @{ hash = $hash; source = 'default'; installedAt = 'now' }
                }
            }
            Test-SkillModifiedByUser -FilePath $tempFile -ManifestKey 'mykey' -Manifest $manifest | Should -BeFalse
        }
        finally {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    }

    It 'returns $true when file hash differs from manifest' {
        $tempFile = Join-Path $env:TEMP "team-ai-kit-mod3-$(Get-Random).txt"
        try {
            Set-Content -Path $tempFile -Value 'modified content'
            $manifest = @{
                files = @{
                    'mykey' = @{ hash = 'OLD_HASH_THAT_NO_LONGER_MATCHES'; source = 'default'; installedAt = 'now' }
                }
            }
            Test-SkillModifiedByUser -FilePath $tempFile -ManifestKey 'mykey' -Manifest $manifest | Should -BeTrue
        }
        finally {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    }
}

# -- Skills Merge (3-layer) ---------------------------------------------------

Describe 'Install-SkillsWithMerge' {
    BeforeAll {
        $script:mergeTestDir = Join-Path $env:TEMP "team-ai-kit-merge-$(Get-Random)"
        $script:mergeTestProfile = Join-Path $env:TEMP "team-ai-kit-merge-profile-$(Get-Random)"
    }

    AfterAll {
        if (Test-Path $script:mergeTestDir) { Remove-Item -Recurse -Force $script:mergeTestDir }
        if (Test-Path $script:mergeTestProfile) { Remove-Item -Recurse -Force $script:mergeTestProfile }
    }

    It 'installs all default skills on first run' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = $script:mergeTestProfile
        try {
            $results = Install-SkillsWithMerge -KitRoot $script:kitRoot -Role 'frontend' -TargetDir $script:mergeTestDir
            $results.installed.Count | Should -Be 7  # 5 shared + 2 frontend
            $results.updated.Count | Should -Be 0
            $results.skipped.Count | Should -Be 0
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }

    It 'creates manifest with tracked files' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = $script:mergeTestProfile
        try {
            $manifest = Get-SkillManifest
            $manifest.files.Count | Should -Be 7
            # All should be source=default
            $manifest.files.Values | ForEach-Object { $_.source | Should -Be 'default' }
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }

    It 'skips all skills on second run (no changes)' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = $script:mergeTestProfile
        try {
            $results = Install-SkillsWithMerge -KitRoot $script:kitRoot -Role 'frontend' -TargetDir $script:mergeTestDir
            $results.installed.Count | Should -Be 0
            $results.updated.Count | Should -Be 0
            $results.skipped.Count | Should -Be 7
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }

    It 'does not overwrite user-modified files' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = $script:mergeTestProfile
        try {
            # Modify one skill file
            $archSkill = Join-Path $script:mergeTestDir 'team-skills\shared\architecture\SKILL.md'
            Set-Content -Path $archSkill -Value '# User customized this skill'

            $results = Install-SkillsWithMerge -KitRoot $script:kitRoot -Role 'frontend' -TargetDir $script:mergeTestDir
            $results.skipped.Count | Should -Be 7  # all skipped, including modified one

            # Verify content was NOT overwritten
            $content = Get-Content $archSkill -Raw
            $content | Should -BeLike '*User customized*'
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }
}
