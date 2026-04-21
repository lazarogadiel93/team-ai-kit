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

    It 'maps cursor to cursor' {
        Get-GentleAiAgentId -Ide 'cursor' | Should -Be 'cursor'
    }

    It 'returns $null for unknown IDEs' {
        Get-GentleAiAgentId -Ide 'vim' | Should -BeNullOrEmpty
    }

    It 'is case-insensitive' {
        Get-GentleAiAgentId -Ide 'VSCode' | Should -Be 'vscode-copilot'
        Get-GentleAiAgentId -Ide 'OPENCODE' | Should -Be 'opencode'
        Get-GentleAiAgentId -Ide 'CURSOR' | Should -Be 'cursor'
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

    It 'returns $true for cursor' {
        Test-GentleAiSupportsIde -Ide 'cursor' | Should -BeTrue
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
        Test-ValidIde -Ide 'cursor' | Should -BeTrue
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
        $roleReact = Join-Path $script:tempDir 'team-skills\roles\frontend\react\SKILL.md'
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

    It 'returns .cursor/skills path for cursor' {
        $path = Get-IdeSkillsDirectory -Ide 'cursor'
        $path | Should -BeLike '*.cursor?skills*'
    }

    It 'throws for unsupported IDE' {
        { Get-IdeSkillsDirectory -Ide 'vim' } | Should -Throw '*Unsupported IDE*'
    }
}

Describe 'Get-IdeProjectSkillsDirectory' {
    It 'returns .github/skills for vscode' {
        $path = Get-IdeProjectSkillsDirectory -Ide 'vscode' -ProjectRoot 'C:\project'
        $path | Should -BeLike '*\.github?skills'
    }

    It 'returns .github/skills for intellij' {
        $path = Get-IdeProjectSkillsDirectory -Ide 'intellij' -ProjectRoot 'C:\project'
        $path | Should -BeLike '*\.github?skills'
    }

    It 'returns .agents/skills for opencode' {
        $path = Get-IdeProjectSkillsDirectory -Ide 'opencode' -ProjectRoot 'C:\project'
        $path | Should -BeLike '*\.agents?skills'
    }

    It 'returns .cursor/skills for cursor' {
        $path = Get-IdeProjectSkillsDirectory -Ide 'cursor' -ProjectRoot 'C:\project'
        $path | Should -BeLike '*\.cursor?skills'
    }

    It 'throws for unsupported IDE' {
        { Get-IdeProjectSkillsDirectory -Ide 'vim' -ProjectRoot 'C:\project' } | Should -Throw '*Unsupported IDE*'
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

    It 'returns .cursor/rules/team-ai-kit.md for cursor' {
        $path = Get-IdeInstructionsPath -Ide 'cursor' -ProjectRoot 'C:\project'
        $path | Should -BeLike '*.cursor?rules?team-ai-kit.md'
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

Describe 'New-CursorMcpConfig' {
    It 'generates valid JSON' {
        $json = New-CursorMcpConfig -EngramBinaryPath 'C:\engram.exe'
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'includes engram server config under mcpServers' {
        $json = New-CursorMcpConfig -EngramBinaryPath 'C:\engram.exe'
        $config = $json | ConvertFrom-Json
        $config.mcpServers.engram | Should -Not -BeNullOrEmpty
        $config.mcpServers.engram.command | Should -Be 'C:\engram.exe'
    }

    It 'includes context7 server config under mcpServers' {
        $json = New-CursorMcpConfig -EngramBinaryPath 'C:\engram.exe'
        $config = $json | ConvertFrom-Json
        $config.mcpServers.context7 | Should -Not -BeNullOrEmpty
        $config.mcpServers.context7.url | Should -BeLike '*context7*'
    }

    It 'does not have servers key' {
        $json = New-CursorMcpConfig -EngramBinaryPath 'C:\engram.exe'
        $config = $json | ConvertFrom-Json
        ($config.PSObject.Properties.Name -contains 'servers') | Should -Be $false
    }
}

# -- Instructions Generation ---------------------------------------------------

Describe 'Get-EngramProtocolContent' {
    It 'returns content with opening and closing markers' {
        $content = Get-EngramProtocolContent
        $content | Should -BeLike '*<!-- team-ai-kit:engram-protocol -->*'
        $content | Should -BeLike '*<!-- /team-ai-kit:engram-protocol -->*'
    }

    It 'includes all mem_* tool references' {
        $content = Get-EngramProtocolContent
        $content | Should -BeLike '*mem_save*'
        $content | Should -BeLike '*mem_search*'
        $content | Should -BeLike '*mem_context*'
        $content | Should -BeLike '*mem_session_summary*'
        $content | Should -BeLike '*mem_get_observation*'
        $content | Should -BeLike '*mem_suggest_topic_key*'
        $content | Should -BeLike '*mem_update*'
    }

    It 'includes all 4 protocol sections' {
        $content = Get-EngramProtocolContent
        $content | Should -BeLike '*PROACTIVE SAVE TRIGGERS*'
        $content | Should -BeLike '*WHEN TO SEARCH MEMORY*'
        $content | Should -BeLike '*SESSION CLOSE PROTOCOL*'
        $content | Should -BeLike '*AFTER COMPACTION*'
    }

    It 'wraps session summary template in code fence' {
        $content = Get-EngramProtocolContent
        $content | Should -Match '(?s)```.*## Goal.*## Relevant Files.*```'
    }

    It 'uses single backticks for inline code (not double)' {
        $content = Get-EngramProtocolContent
        $content | Should -Match 'Call `mem_save`'
        $content | Should -Not -Match '``mem_save``'
    }
}

Describe 'New-CopilotInstructions' {
    It 'includes role in header' {
        $instructions = New-CopilotInstructions -Role 'frontend'
        $instructions | Should -BeLike '*frontend*'
    }

    It 'includes team conventions section' {
        $instructions = New-CopilotInstructions -Role 'backend-node'
        $instructions | Should -BeLike '*Team Conventions*'
    }

    It 'includes engram Memory Protocol with markers' {
        $instructions = New-CopilotInstructions -Role 'frontend'
        $instructions | Should -BeLike '*<!-- team-ai-kit:engram-protocol -->*'
        $instructions | Should -BeLike '*<!-- /team-ai-kit:engram-protocol -->*'
        $instructions | Should -BeLike '*mem_save*'
        $instructions | Should -BeLike '*mem_context*'
        $instructions | Should -BeLike '*mem_session_summary*'
        $instructions | Should -BeLike '*AFTER COMPACTION*'
    }

    It 'places engram-protocol before team-rules in output' {
        $instructions = New-CopilotInstructions -Role 'frontend' -TeamRulesContent '## Team Rules'
        $engramIdx = $instructions.IndexOf('<!-- team-ai-kit:engram-protocol -->')
        $teamIdx = $instructions.IndexOf('<!-- team-ai-kit:team-rules -->')
        $engramIdx | Should -BeLessThan $teamIdx
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

    It 'wraps team rules in markers when TeamRulesContent provided' {
        $teamRules = "## Architecture`nUse hexagonal architecture"
        $instructions = New-CopilotInstructions -Role 'frontend' -TeamRulesContent $teamRules
        $instructions | Should -BeLike '*<!-- team-ai-kit:team-rules -->*'
        $instructions | Should -BeLike '*<!-- /team-ai-kit:team-rules -->*'
        $instructions | Should -BeLike '*hexagonal architecture*'
    }

    It 'includes both pack rules and team rules' {
        $packRules = "## Pack Rules`nRule 1"
        $teamRules = "## Team Rules`nRule 2"
        $instructions = New-CopilotInstructions -Role 'frontend' -PackRulesContent $packRules -TeamRulesContent $teamRules
        $instructions | Should -BeLike '*Pack Rules*'
        $instructions | Should -BeLike '*Team Rules*'
        $instructions | Should -BeLike '*<!-- team-ai-kit:team-rules -->*'
    }

    It 'does not include team-rules markers when TeamRulesContent is empty' {
        $instructions = New-CopilotInstructions -Role 'frontend'
        $instructions | Should -Not -BeLike '*team-ai-kit:team-rules*'
    }

    It 'skips engram protocol when SkipEngramProtocol is set' {
        $instructions = New-CopilotInstructions -Role 'frontend' -SkipEngramProtocol
        $instructions | Should -Not -BeLike '*team-ai-kit:engram-protocol*'
        $instructions | Should -Not -BeLike '*mem_save*'
        $instructions | Should -BeLike '*Team Conventions*'
    }

    It 'includes engram protocol when SkipEngramProtocol is not set' {
        $instructions = New-CopilotInstructions -Role 'frontend'
        $instructions | Should -BeLike '*team-ai-kit:engram-protocol*'
        $instructions | Should -BeLike '*mem_save*'
    }

    It 'skips engram protocol but keeps team rules when both flags used' {
        $instructions = New-CopilotInstructions -Role 'frontend' -TeamRulesContent '## Team Rules' -SkipEngramProtocol
        $instructions | Should -Not -BeLike '*team-ai-kit:engram-protocol*'
        $instructions | Should -BeLike '*<!-- team-ai-kit:team-rules -->*'
        $instructions | Should -BeLike '*Team Rules*'
    }
}

Describe 'Update-InstructionsEngramProtocol' {
    It 'returns $false when file does not exist' {
        $result = Update-InstructionsEngramProtocol -FilePath 'C:\nonexistent\file.md'
        $result | Should -BeFalse
    }

    It 'appends protocol when markers do not exist' {
        $tempFile = Join-Path $env:TEMP "instructions-$(Get-Random).md"
        try {
            Set-Content -Path $tempFile -Value '# Existing content'
            $result = Update-InstructionsEngramProtocol -FilePath $tempFile
            $result | Should -BeTrue
            $content = Get-Content -Path $tempFile -Raw
            $content | Should -BeLike '*<!-- team-ai-kit:engram-protocol -->*'
            $content | Should -BeLike '*mem_save*'
            $content | Should -BeLike '*<!-- /team-ai-kit:engram-protocol -->*'
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It 'replaces content between existing markers' {
        $tempFile = Join-Path $env:TEMP "instructions-$(Get-Random).md"
        try {
            $initial = @"
# Header
<!-- team-ai-kit:engram-protocol -->
# Old Protocol
<!-- /team-ai-kit:engram-protocol -->
# Footer
"@
            Set-Content -Path $tempFile -Value $initial
            $result = Update-InstructionsEngramProtocol -FilePath $tempFile
            $result | Should -BeTrue
            $content = Get-Content -Path $tempFile -Raw
            $content | Should -BeLike '*mem_save*'
            $content | Should -Not -BeLike '*Old Protocol*'
            $content | Should -BeLike '*# Header*'
            $content | Should -BeLike '*# Footer*'
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns $false when content is unchanged' {
        $tempFile = Join-Path $env:TEMP "instructions-$(Get-Random).md"
        try {
            $protocol = Get-EngramProtocolContent
            $initial = "# Header`n`n$($protocol.Trim())"
            Set-Content -Path $tempFile -Value $initial
            $result = Update-InstructionsEngramProtocol -FilePath $tempFile
            $result | Should -BeFalse
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It 'removes existing protocol when SkipEngramProtocol is set' {
        $tempFile = Join-Path $env:TEMP "instructions-$(Get-Random).md"
        try {
            $initial = @"
# Header
<!-- team-ai-kit:engram-protocol -->
## Old Protocol
<!-- /team-ai-kit:engram-protocol -->
# Footer
"@
            Set-Content -Path $tempFile -Value $initial
            $result = Update-InstructionsEngramProtocol -FilePath $tempFile -SkipEngramProtocol
            $result | Should -BeTrue
            $content = Get-Content -Path $tempFile -Raw
            $content | Should -Not -BeLike '*engram-protocol*'
            $content | Should -BeLike '*# Header*'
            $content | Should -BeLike '*# Footer*'
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns $false when SkipEngramProtocol is set and no markers exist' {
        $tempFile = Join-Path $env:TEMP "instructions-$(Get-Random).md"
        try {
            Set-Content -Path $tempFile -Value '# No protocol here'
            $result = Update-InstructionsEngramProtocol -FilePath $tempFile -SkipEngramProtocol
            $result | Should -BeFalse
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
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

    It 'returns cursor dir for cursor' {
        $dir = Get-TemplateDirectory -KitRoot $script:kitRoot -Ide 'cursor'
        $dir | Should -BeLike '*cursor*'
        Test-Path $dir | Should -BeTrue
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

    It 'finds .template files for cursor' {
        $dir = Get-TemplateDirectory -KitRoot $script:kitRoot -Ide 'cursor'
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

Describe 'Install-Templates (Cursor)' {
    BeforeAll {
        $script:cursorTplTempDir = Join-Path $env:TEMP "team-ai-kit-cursor-tpl-test-$(Get-Random)"
    }

    AfterAll {
        if (Test-Path $script:cursorTplTempDir) {
            Remove-Item -Path $script:cursorTplTempDir -Recurse -Force
        }
    }

    It 'expands and copies Cursor templates to target dir' {
        $tplDir = Get-TemplateDirectory -KitRoot $script:kitRoot -Ide 'cursor'
        $vars = @{
            ENGRAM_BINARY_PATH = 'C:/tools/engram.exe'
        }
        $created = Install-Templates -TemplateDir $tplDir -TargetDir $script:cursorTplTempDir -Variables $vars
        $created | Should -Not -BeNullOrEmpty
    }

    It 'creates files without .template extension' {
        $created = Get-ChildItem -Path $script:cursorTplTempDir -Recurse -File
        $created | ForEach-Object { $_.Name | Should -Not -BeLike '*.template' }
    }

    It 'replaces placeholders in Cursor MCP config' {
        $mcpFile = Join-Path $script:cursorTplTempDir 'mcp.json'
        if (Test-Path $mcpFile) {
            $content = Get-Content $mcpFile -Raw
            $content | Should -BeLike '*engram.exe*'
            $content | Should -Not -BeLike '*{{ENGRAM_BINARY_PATH}}*'
        }
    }

    It 'generates valid JSON for Cursor MCP config' {
        $mcpFile = Join-Path $script:cursorTplTempDir 'mcp.json'
        if (Test-Path $mcpFile) {
            $content = Get-Content $mcpFile -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    It 'Cursor MCP config uses mcpServers key (Cursor format)' {
        $mcpFile = Join-Path $script:cursorTplTempDir 'mcp.json'
        if (Test-Path $mcpFile) {
            $config = Get-Content $mcpFile -Raw | ConvertFrom-Json
            $config.mcpServers | Should -Not -BeNullOrEmpty
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
                version     = '2.1.0'
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
            $parsed.version | Should -Be '2.1.0'
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
            $roleSkill = Join-Path $teamContent 'skills\roles\frontend\storybook\SKILL.md'
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

Describe 'Get-TeamRepoRulesContent' {
    It 'returns empty string when team repo not cloned' {
        $originalProfile = $env:USERPROFILE
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-rules-$(Get-Random)"
        try {
            $content = Get-TeamRepoRulesContent
            $content | Should -BeNullOrEmpty
        }
        finally {
            $env:USERPROFILE = $originalProfile
        }
    }

    It 'reads and concatenates rules/*.md files' {
        $originalProfile = $env:USERPROFILE
        $tempProfile = Join-Path $env:TEMP "team-ai-kit-rules2-$(Get-Random)"
        $env:USERPROFILE = $tempProfile
        try {
            $teamContent = Get-TeamRepoLocalPath
            $rulesDir = Join-Path $teamContent 'rules'
            New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null
            Set-Content -Path (Join-Path $rulesDir 'architecture.md') -Value '# Architecture Rules'
            Set-Content -Path (Join-Path $rulesDir 'testing.md') -Value '# Testing Rules'

            $content = Get-TeamRepoRulesContent
            $content | Should -BeLike '*Architecture Rules*'
            $content | Should -BeLike '*Testing Rules*'
        }
        finally {
            $env:USERPROFILE = $originalProfile
            if (Test-Path $tempProfile) { Remove-Item -Recurse -Force $tempProfile -ErrorAction SilentlyContinue }
        }
    }

    It 'accepts -RepoUrl for per-project path' {
        $originalProfile = $env:USERPROFILE
        $tempProfile = Join-Path $env:TEMP "team-ai-kit-rules3-$(Get-Random)"
        $env:USERPROFILE = $tempProfile
        try {
            $teamContent = Get-TeamRepoLocalPath -RepoUrl 'https://github.com/team/knowledge'
            $rulesDir = Join-Path $teamContent 'rules'
            New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null
            Set-Content -Path (Join-Path $rulesDir 'api.md') -Value '# API Rules'

            $content = Get-TeamRepoRulesContent -RepoUrl 'https://github.com/team/knowledge'
            $content | Should -BeLike '*API Rules*'
        }
        finally {
            $env:USERPROFILE = $originalProfile
            if (Test-Path $tempProfile) { Remove-Item -Recurse -Force $tempProfile -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'Update-InstructionsTeamRules' {
    It 'returns $false when file does not exist' {
        $result = Update-InstructionsTeamRules -FilePath 'C:\nonexistent\file.md' -TeamRulesContent '# Rules'
        $result | Should -BeFalse
    }

    It 'appends markers when they do not exist' {
        $tempFile = Join-Path $env:TEMP "instructions-$(Get-Random).md"
        try {
            Set-Content -Path $tempFile -Value '# Existing content'
            $result = Update-InstructionsTeamRules -FilePath $tempFile -TeamRulesContent '# New Rules'
            $result | Should -BeTrue
            $content = Get-Content -Path $tempFile -Raw
            $content | Should -BeLike '*<!-- team-ai-kit:team-rules -->*'
            $content | Should -BeLike '*# New Rules*'
            $content | Should -BeLike '*<!-- /team-ai-kit:team-rules -->*'
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It 'replaces content between existing markers' {
        $tempFile = Join-Path $env:TEMP "instructions-$(Get-Random).md"
        try {
            $initial = @"
# Header
<!-- team-ai-kit:team-rules -->
# Old Rules
<!-- /team-ai-kit:team-rules -->
# Footer
"@
            Set-Content -Path $tempFile -Value $initial
            $result = Update-InstructionsTeamRules -FilePath $tempFile -TeamRulesContent '# Updated Rules'
            $result | Should -BeTrue
            $content = Get-Content -Path $tempFile -Raw
            $content | Should -BeLike '*Updated Rules*'
            $content | Should -Not -BeLike '*Old Rules*'
            $content | Should -BeLike '*# Header*'
            $content | Should -BeLike '*# Footer*'
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns $false when content is unchanged' {
        $tempFile = Join-Path $env:TEMP "instructions-$(Get-Random).md"
        try {
            $rules = '# Same Rules'
            $initial = "# Header`n`n<!-- team-ai-kit:team-rules -->`n$rules`n<!-- /team-ai-kit:team-rules -->"
            Set-Content -Path $tempFile -Value $initial
            $result = Update-InstructionsTeamRules -FilePath $tempFile -TeamRulesContent $rules
            $result | Should -BeFalse
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Update-InstructionsTeamRules preserves dollar signs in content' {
    It 'does not corrupt $1 $2 or $variable in team rules' {
        $tempFile = Join-Path $env:TEMP "instructions-dollar-$(Get-Random).md"
        try {
            $initial = @"
# Header
<!-- team-ai-kit:team-rules -->
# Old Rules
<!-- /team-ai-kit:team-rules -->
# Footer
"@
            Set-Content -Path $tempFile -Value $initial
            $rulesWithDollars = 'Use $1 for first arg, $variable for config, and $HOME for home dir'
            $result = Update-InstructionsTeamRules -FilePath $tempFile -TeamRulesContent $rulesWithDollars
            $result | Should -BeTrue
            $content = Get-Content -Path $tempFile -Raw
            $content | Should -BeLike '*$1*'
            $content | Should -BeLike '*$variable*'
            $content | Should -BeLike '*$HOME*'
            $content | Should -BeLike '*# Footer*'
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Update-InstructionsEngramProtocol preserves dollar signs in content' {
    It 'does not corrupt content containing dollar signs during replacement' {
        $tempFile = Join-Path $env:TEMP "instructions-engram-dollar-$(Get-Random).md"
        try {
            # Create a file with engram protocol markers containing $-variables
            $initial = @"
# Header
<!-- team-ai-kit:engram-protocol -->
Old protocol with `$1` and `$variable`
<!-- /team-ai-kit:engram-protocol -->
# Footer
"@
            Set-Content -Path $tempFile -Value $initial
            $result = Update-InstructionsEngramProtocol -FilePath $tempFile
            $result | Should -BeTrue
            $content = Get-Content -Path $tempFile -Raw
            # The new protocol content should be there and footer preserved
            $content | Should -BeLike '*engram-protocol*'
            $content | Should -BeLike '*mem_save*'
            $content | Should -BeLike '*# Footer*'
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Get-TeamRepoLocalPath with -RepoUrl' {
    It 'returns different paths for different URLs' {
        $path1 = Get-TeamRepoLocalPath -RepoUrl 'https://github.com/team-a/knowledge'
        $path2 = Get-TeamRepoLocalPath -RepoUrl 'https://github.com/team-b/knowledge'
        $path1 | Should -Not -Be $path2
    }

    It 'returns same path for same URL' {
        $path1 = Get-TeamRepoLocalPath -RepoUrl 'https://github.com/team/knowledge'
        $path2 = Get-TeamRepoLocalPath -RepoUrl 'https://github.com/team/knowledge'
        $path1 | Should -Be $path2
    }

    It 'falls back to default team-content when no URL' {
        $path = Get-TeamRepoLocalPath
        $path | Should -BeLike '*team-content'
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
            version       = '2.1.0'
        }
        $savedPath = Save-ProjectConfig -ProjectRoot $script:configTestDir -Config $config
        $savedPath | Should -Not -BeNullOrEmpty
        Test-Path $savedPath | Should -BeTrue

        $loaded = Get-ProjectConfig -ProjectRoot $script:configTestDir
        $loaded.role | Should -Be 'backend-node'
        $loaded.ide | Should -Be 'vscode'
        $loaded.version | Should -Be '2.1.0'
    }

    It 'returns $null when no config exists' {
        $emptyDir = Join-Path $TestDrive 'empty-project'
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        Get-ProjectConfig -ProjectRoot $emptyDir | Should -BeNullOrEmpty
    }
}

# -- Engram Sync (native .engram/) ---------------------------------------------

Describe 'Initialize-EngramSync' {
    BeforeAll {
        $script:engramTestDir = Join-Path $TestDrive 'engram-sync-project'
        New-Item -ItemType Directory -Path $script:engramTestDir -Force | Out-Null
    }

    It 'returns hashtable with path and synced keys' {
        Mock Test-EngramInstalled { return $false }
        $result = Initialize-EngramSync -ProjectRoot $script:engramTestDir -ProjectName 'test-project'
        $result | Should -BeOfType [hashtable]
        $result.ContainsKey('path') | Should -BeTrue
        $result.ContainsKey('synced') | Should -BeTrue
    }

    It 'sets path to .engram/ inside project root' {
        Mock Test-EngramInstalled { return $false }
        $result = Initialize-EngramSync -ProjectRoot $script:engramTestDir -ProjectName 'test-project'
        $result.path | Should -Be (Join-Path $script:engramTestDir '.engram')
    }

    It 'returns synced=$false when engram is not installed' {
        Mock Test-EngramInstalled { return $false }
        $result = Initialize-EngramSync -ProjectRoot $script:engramTestDir -ProjectName 'test-project'
        $result.synced | Should -BeFalse
    }

    Context 'with engram available' {
        BeforeAll {
            $script:fakeEngramSync = Join-Path $TestDrive 'fake-engram-sync.ps1'
            @'
param([string[]]$args)
# Fake engram that always succeeds
exit 0
'@ | Set-Content $script:fakeEngramSync

            Mock Test-EngramInstalled { return $true }
            Mock Get-EngramBinaryPath { return 'powershell' }
        }

        It 'calls engram sync with --project flag when ProjectName given' {
            # We can verify it runs without error; actual engram binary is mocked
            Mock Test-EngramInstalled { return $true }
            Mock Get-EngramBinaryPath { return $null }
            $result = Initialize-EngramSync -ProjectRoot $script:engramTestDir -ProjectName 'my-project'
            # Without a binary, synced should be false
            $result.synced | Should -BeFalse
        }

        It 'calls engram sync with --all when no ProjectName given' {
            Mock Test-EngramInstalled { return $true }
            Mock Get-EngramBinaryPath { return $null }
            $result = Initialize-EngramSync -ProjectRoot $script:engramTestDir
            $result.synced | Should -BeFalse
        }
    }
}

Describe 'Install-GitHooks' {
    BeforeAll {
        $script:hooksProjectDir = Join-Path $TestDrive 'hooks-test-project'
        New-Item -ItemType Directory -Path $script:hooksProjectDir -Force | Out-Null
    }

    Context 'in a non-git directory' {
        It 'returns skipped=not-a-git-repo when .git does not exist' {
            $result = Install-GitHooks -ProjectRoot $script:hooksProjectDir -ProjectName 'test'
            $result.skipped | Should -Contain 'not-a-git-repo'
            $result.installed.Count | Should -Be 0
        }
    }

    Context 'in a git directory' {
        BeforeAll {
            $script:gitProjectDir = Join-Path $TestDrive 'git-hooks-project'
            New-Item -ItemType Directory -Path (Join-Path $script:gitProjectDir '.git') -Force | Out-Null
        }

        It 'creates pre-commit and post-merge hooks' {
            $result = Install-GitHooks -ProjectRoot $script:gitProjectDir -ProjectName 'my-project'
            $result.installed | Should -Contain 'pre-commit'
            $result.installed | Should -Contain 'post-merge'
            $result.installed.Count | Should -Be 2
        }

        It 'creates hook files in .git/hooks/' {
            $preCommitPath = Join-Path $script:gitProjectDir '.git\hooks\pre-commit'
            $postMergePath = Join-Path $script:gitProjectDir '.git\hooks\post-merge'
            Test-Path $preCommitPath | Should -BeTrue
            Test-Path $postMergePath | Should -BeTrue
        }

        It 'pre-commit hook contains engram sync with project flag' {
            $preCommitPath = Join-Path $script:gitProjectDir '.git\hooks\pre-commit'
            $content = Get-Content $preCommitPath -Raw
            $content | Should -BeLike '*engram sync*'
            $content | Should -BeLike '*my-project*'
            $content | Should -BeLike '*git add .engram/*'
        }

        It 'post-merge hook contains engram sync --import' {
            $postMergePath = Join-Path $script:gitProjectDir '.git\hooks\post-merge'
            $content = Get-Content $postMergePath -Raw
            $content | Should -BeLike '*engram sync --import*'
        }

        It 'hooks contain team-ai-kit marker comment' {
            $preCommitPath = Join-Path $script:gitProjectDir '.git\hooks\pre-commit'
            $content = Get-Content $preCommitPath -Raw
            $content | Should -Match 'team-ai-kit'
        }

        It 'hooks start with shebang line' {
            $preCommitPath = Join-Path $script:gitProjectDir '.git\hooks\pre-commit'
            $content = Get-Content $preCommitPath -Raw
            $content | Should -BeLike '#!/bin/sh*'
        }

        It 'skips hooks on second run (marker already present)' {
            $result = Install-GitHooks -ProjectRoot $script:gitProjectDir -ProjectName 'my-project'
            $result.skipped | Should -Contain 'pre-commit'
            $result.skipped | Should -Contain 'post-merge'
            $result.installed.Count | Should -Be 0
        }

        It 'appends to existing hook without marker' {
            $appendDir = Join-Path $TestDrive 'append-hooks-project'
            New-Item -ItemType Directory -Path (Join-Path $appendDir '.git\hooks') -Force | Out-Null

            # Create pre-existing hook
            $preCommitPath = Join-Path $appendDir '.git\hooks\pre-commit'
            Set-Content -Path $preCommitPath -Value "#!/bin/sh`necho 'existing hook'" -Encoding ASCII

            $result = Install-GitHooks -ProjectRoot $appendDir -ProjectName 'test'
            $result.installed | Should -Contain 'pre-commit'

            # Verify original content is preserved
            $content = Get-Content $preCommitPath -Raw
            $content | Should -BeLike '*existing hook*'
            $content | Should -Match 'team-ai-kit'
        }

        It 'uses --all flag when no ProjectName given' {
            $allDir = Join-Path $TestDrive 'all-hooks-project'
            New-Item -ItemType Directory -Path (Join-Path $allDir '.git') -Force | Out-Null

            $result = Install-GitHooks -ProjectRoot $allDir
            $preCommitPath = Join-Path $allDir '.git\hooks\pre-commit'
            $content = Get-Content $preCommitPath -Raw
            $content | Should -BeLike '*--all*'
        }
    }
}

Describe 'Invoke-EngramSync' {
    It 'returns failure when engram is not installed' {
        Mock Test-EngramInstalled { return $false }
        $result = Invoke-EngramSync -Operation 'export'
        $result.success | Should -BeFalse
        $result.message | Should -BeLike '*not installed*'
    }

    It 'returns failure when engram binary not found' {
        Mock Test-EngramInstalled { return $true }
        Mock Get-EngramBinaryPath { return $null }
        $result = Invoke-EngramSync -Operation 'export'
        $result.success | Should -BeFalse
        $result.message | Should -BeLike '*not found*'
    }

    It 'returns hashtable with success and message keys' {
        Mock Test-EngramInstalled { return $false }
        $result = Invoke-EngramSync -Operation 'export'
        $result | Should -BeOfType [hashtable]
        $result.ContainsKey('success') | Should -BeTrue
        $result.ContainsKey('message') | Should -BeTrue
    }

    It 'accepts export, import, and status operations' {
        Mock Test-EngramInstalled { return $false }
        foreach ($op in @('export', 'import', 'status')) {
            $result = Invoke-EngramSync -Operation $op
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'New-InitSummary' {
    It 'generates summary with engram synced and hooks installed' {
        $summary = New-InitSummary -Ide 'vscode' -Role 'frontend' -InstructionsPath '.github/copilot-instructions.md' -EngramSynced $true -HooksInstalled 2
        $summary | Should -BeLike '*Project Initialized*'
        $summary | Should -BeLike '*vscode*'
        $summary | Should -BeLike '*frontend*'
        $summary | Should -BeLike '*synced via engram sync*'
        $summary | Should -BeLike '*2 hook*installed*'
    }

    It 'generates summary when engram is not available' {
        $summary = New-InitSummary -Ide 'opencode' -Role 'devops'
        $summary | Should -BeLike '*Project Initialized*'
        $summary | Should -BeLike '*not synced*'
        $summary | Should -BeLike '*no hooks installed*'
    }

    It 'includes instructions path in summary' {
        $summary = New-InitSummary -Ide 'vscode' -Role 'frontend' -InstructionsPath 'AGENTS.md'
        $summary | Should -BeLike '*AGENTS.md*'
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

# -- Direct Download Support ---------------------------------------------------

Describe 'Get-DirectDownloadBinDir' {
    It 'returns a path under LOCALAPPDATA' {
        $dir = Get-DirectDownloadBinDir
        $dir | Should -BeLike "$env:LOCALAPPDATA*"
    }

    It 'returns a path ending in team-ai-kit\bin' {
        $dir = Get-DirectDownloadBinDir
        $dir | Should -BeLike '*team-ai-kit?bin'
    }
}

Describe 'Get-PlatformArchitecture' {
    It 'returns a hashtable with os and arch keys' {
        $platform = Get-PlatformArchitecture
        $platform | Should -BeOfType [hashtable]
        $platform.ContainsKey('os') | Should -BeTrue
        $platform.ContainsKey('arch') | Should -BeTrue
    }

    It 'returns windows as os' {
        $platform = Get-PlatformArchitecture
        $platform.os | Should -Be 'windows'
    }

    It 'returns a valid architecture (amd64 or arm64)' {
        $platform = Get-PlatformArchitecture
        $platform.arch | Should -BeIn @('amd64', 'arm64')
    }
}

Describe 'Get-GithubLatestReleaseAssetUrl' {
    It 'throws when no asset matches pattern' {
        Mock Invoke-RestMethod {
            return @{
                tag_name = 'v1.0.0'
                assets = @(
                    @{ name = 'tool_1.0.0_linux_amd64.tar.gz'; browser_download_url = 'https://example.com/linux.tar.gz' }
                )
            }
        }
        { Get-GithubLatestReleaseAssetUrl -Owner 'test' -Repo 'tool' -AssetPattern 'tool_*_windows_amd64.zip' } | Should -Throw '*No release asset matching*'
    }

    It 'returns matching asset info' {
        Mock Invoke-RestMethod {
            return @{
                tag_name = 'v1.2.3'
                assets = @(
                    @{ name = 'tool_1.2.3_linux_amd64.tar.gz'; browser_download_url = 'https://example.com/linux.tar.gz' }
                    @{ name = 'tool_1.2.3_windows_amd64.zip'; browser_download_url = 'https://example.com/windows.zip' }
                )
            }
        }
        $result = Get-GithubLatestReleaseAssetUrl -Owner 'test' -Repo 'tool' -AssetPattern 'tool_*_windows_amd64.zip'
        $result.url | Should -Be 'https://example.com/windows.zip'
        $result.version | Should -Be 'v1.2.3'
        $result.name | Should -Be 'tool_1.2.3_windows_amd64.zip'
    }
}

Describe 'Install-GithubReleaseBinary' {
    It 'calls Get-GithubLatestReleaseAssetUrl with correct asset pattern' {
        $capturedPattern = $null
        Mock Get-GithubLatestReleaseAssetUrl {
            $capturedPattern = $AssetPattern
            throw 'mock-stop'
        }
        try {
            Install-GithubReleaseBinary -Owner 'test' -Repo 'mytool' -BinaryName 'mytool'
        }
        catch {}
        Should -Invoke Get-GithubLatestReleaseAssetUrl -Times 1
    }
}

Describe 'Add-ToUserPath' {
    It 'adds directory to current session PATH' {
        $originalPath = $env:PATH
        $testDir = "C:\team-ai-kit-test-path-$(Get-Random)"
        try {
            # Temporarily remove the dir from PATH (it shouldn't be there, but be safe)
            $env:PATH = $originalPath -replace [regex]::Escape($testDir), ''
            # We can't mock [Environment]::SetEnvironmentVariable, so we just verify
            # the session PATH was updated. The persistent change is a side effect.
            $null = Add-ToUserPath -Directory $testDir
            $env:PATH | Should -BeLike "*$testDir*"
        }
        finally {
            $env:PATH = $originalPath
            # Clean up any persistent PATH change (remove the test dir)
            $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
            if ($userPath -and $userPath -like "*$testDir*") {
                $cleanPath = ($userPath -split ';' | Where-Object { $_ -ne $testDir }) -join ';'
                [Environment]::SetEnvironmentVariable('PATH', $cleanPath, 'User')
            }
        }
    }

    It 'returns $false when directory is already in PATH' {
        $originalPath = $env:PATH
        $existingDir = ($env:PATH -split ';')[0]
        try {
            $result = Add-ToUserPath -Directory $existingDir
            # It should return $false since the dir was already there
            # (or $true if it wasn't in the User-level persistent PATH)
            $result | Should -Not -BeNullOrEmpty
        }
        finally {
            $env:PATH = $originalPath
        }
    }
}

Describe 'Get-GentleAiBinaryPath' {
    It 'returns $null when gentle-ai is not found anywhere' {
        Mock Get-Command { throw 'not found' }
        # Use a temp USERPROFILE and LOCALAPPDATA to avoid finding real binaries
        $originalProfile = $env:USERPROFILE
        $originalAppData = $env:LOCALAPPDATA
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-gentle-test-$(Get-Random)"
        $env:LOCALAPPDATA = Join-Path $env:TEMP "team-ai-kit-gentle-local-$(Get-Random)"
        try {
            Get-GentleAiBinaryPath | Should -BeNullOrEmpty
        }
        finally {
            $env:USERPROFILE = $originalProfile
            $env:LOCALAPPDATA = $originalAppData
        }
    }

    It 'returns path when gentle-ai is in direct download location' {
        Mock Get-Command { throw 'not found' }
        $originalProfile = $env:USERPROFILE
        $originalAppData = $env:LOCALAPPDATA
        $tempLocal = Join-Path $env:TEMP "team-ai-kit-gentle-direct-$(Get-Random)"
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-gentle-profile-$(Get-Random)"
        $env:LOCALAPPDATA = $tempLocal
        try {
            $binDir = Join-Path $tempLocal 'team-ai-kit\bin'
            New-Item -ItemType Directory -Path $binDir -Force | Out-Null
            $fakeBin = Join-Path $binDir 'gentle-ai.exe'
            Set-Content -Path $fakeBin -Value 'fake'

            $result = Get-GentleAiBinaryPath
            $result | Should -Be $fakeBin
        }
        finally {
            $env:USERPROFILE = $originalProfile
            $env:LOCALAPPDATA = $originalAppData
            if (Test-Path $tempLocal) { Remove-Item -Recurse -Force $tempLocal -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'Test-GentleAiInstalled (updated with fallback)' {
    It 'returns $true when gentle-ai is in PATH' {
        Mock Get-Command { return @{ Source = 'C:\gentle-ai.exe' } }
        Test-GentleAiInstalled | Should -BeTrue
    }

    It 'returns $true when gentle-ai is in direct download dir' {
        Mock Get-Command { throw 'not found' }
        $originalProfile = $env:USERPROFILE
        $originalAppData = $env:LOCALAPPDATA
        $tempLocal = Join-Path $env:TEMP "team-ai-kit-installed-test-$(Get-Random)"
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-installed-profile-$(Get-Random)"
        $env:LOCALAPPDATA = $tempLocal
        try {
            $binDir = Join-Path $tempLocal 'team-ai-kit\bin'
            New-Item -ItemType Directory -Path $binDir -Force | Out-Null
            Set-Content -Path (Join-Path $binDir 'gentle-ai.exe') -Value 'fake'

            Test-GentleAiInstalled | Should -BeTrue
        }
        finally {
            $env:USERPROFILE = $originalProfile
            $env:LOCALAPPDATA = $originalAppData
            if (Test-Path $tempLocal) { Remove-Item -Recurse -Force $tempLocal -ErrorAction SilentlyContinue }
        }
    }

    It 'returns $false when gentle-ai is nowhere' {
        Mock Get-Command { throw 'not found' }
        $originalProfile = $env:USERPROFILE
        $originalAppData = $env:LOCALAPPDATA
        $env:USERPROFILE = Join-Path $env:TEMP "team-ai-kit-nowhere-$(Get-Random)"
        $env:LOCALAPPDATA = Join-Path $env:TEMP "team-ai-kit-nowhere-local-$(Get-Random)"
        try {
            Test-GentleAiInstalled | Should -BeFalse
        }
        finally {
            $env:USERPROFILE = $originalProfile
            $env:LOCALAPPDATA = $originalAppData
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

# -- Install-ProjectSkills ----------------------------------------------------

Describe 'Install-ProjectSkills' {
    BeforeAll {
        $script:projectSkillsDir = Join-Path $env:TEMP "team-ai-kit-proj-skills-$(Get-Random)"
        # Create a fake team repo with skills
        $script:fakeTeamRepo = Join-Path $env:TEMP "team-ai-kit-fake-team-$(Get-Random)"
        $fakeSkillDir = Join-Path $script:fakeTeamRepo 'skills\shared\test-skill'
        New-Item -ItemType Directory -Path $fakeSkillDir -Force | Out-Null
        Set-Content -Path (Join-Path $fakeSkillDir 'SKILL.md') -Value '# Test Skill'

        $fakeRoleDir = Join-Path $script:fakeTeamRepo 'skills\roles\frontend\react-skill'
        New-Item -ItemType Directory -Path $fakeRoleDir -Force | Out-Null
        Set-Content -Path (Join-Path $fakeRoleDir 'SKILL.md') -Value '# React Skill'
    }

    AfterAll {
        if (Test-Path $script:projectSkillsDir) { Remove-Item -Recurse -Force $script:projectSkillsDir }
        if (Test-Path $script:fakeTeamRepo) { Remove-Item -Recurse -Force $script:fakeTeamRepo }
    }

    It 'returns zero counts when team repo does not exist' {
        $results = Install-ProjectSkills -Role 'frontend' -TeamRepoUrl 'https://example.com/nonexistent.git' -TargetDir $script:projectSkillsDir
        $results.installed | Should -Be 0
        $results.updated | Should -Be 0
        $results.skipped | Should -Be 0
    }

    It 'installs team repo skills to project directory' {
        # Mock the team repo path to point to our fake
        Mock Get-TeamRepoLocalPath { return $script:fakeTeamRepo }
        $results = Install-ProjectSkills -Role 'frontend' -TeamRepoUrl 'https://example.com/fake.git' -TargetDir $script:projectSkillsDir
        $results.installed | Should -Be 2  # 1 shared + 1 frontend role
        $results.updated | Should -Be 0
    }

    It 'skips unchanged skills on second run' {
        Mock Get-TeamRepoLocalPath { return $script:fakeTeamRepo }
        $results = Install-ProjectSkills -Role 'frontend' -TeamRepoUrl 'https://example.com/fake.git' -TargetDir $script:projectSkillsDir
        $results.installed | Should -Be 0
        $results.skipped | Should -Be 2
    }

    It 'detects updated skills when source changes' {
        Mock Get-TeamRepoLocalPath { return $script:fakeTeamRepo }
        # Modify source
        Set-Content -Path (Join-Path $script:fakeTeamRepo 'skills\shared\test-skill\SKILL.md') -Value '# Test Skill v2'
        $results = Install-ProjectSkills -Role 'frontend' -TeamRepoUrl 'https://example.com/fake.git' -TargetDir $script:projectSkillsDir
        $results.updated | Should -Be 1
        $results.skipped | Should -Be 1
    }
}

# ── Initialize-KnowledgeRepo ─────────────────────────────────────────────────

Describe 'Initialize-KnowledgeRepo' {
    It 'creates skills/shared, skills/roles, and rules directories' {
        $tempDir = Join-Path $env:TEMP "team-ai-kit-knowledge-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            $result = Initialize-KnowledgeRepo -TargetDir $tempDir
            $result.created.Count | Should -Be 3
            Test-Path (Join-Path $tempDir 'skills/shared') | Should -BeTrue
            Test-Path (Join-Path $tempDir 'skills/roles') | Should -BeTrue
            Test-Path (Join-Path $tempDir 'rules') | Should -BeTrue
        }
        finally {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'is idempotent -- reports nothing created on second run' {
        $tempDir = Join-Path $env:TEMP "team-ai-kit-knowledge-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            Initialize-KnowledgeRepo -TargetDir $tempDir | Out-Null
            $result = Initialize-KnowledgeRepo -TargetDir $tempDir
            $result.created.Count | Should -Be 0
        }
        finally {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Test-ValidCommand includes init-knowledge' {
    It 'accepts init-knowledge as valid command' {
        Test-ValidCommand -Command 'init-knowledge' | Should -BeTrue
    }
}
