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
