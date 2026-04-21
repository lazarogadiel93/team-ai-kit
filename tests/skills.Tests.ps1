#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Validates skill markdown files for structure, frontmatter, and required sections.
#>

BeforeAll {
    $script:kitRoot = (Resolve-Path "$PSScriptRoot\..").Path
    $script:sharedDir = Join-Path $script:kitRoot 'skills\shared'
    $script:rolesDir = Join-Path $script:kitRoot 'skills\roles'
    $script:packsDir = Join-Path $script:kitRoot 'packs'

    $script:allSkillFiles = @(Get-ChildItem -Path (Join-Path $script:kitRoot 'skills') -Filter '*.md' -Recurse)
    $script:sharedSkillFiles = @(Get-ChildItem -Path $script:sharedDir -Filter '*.md' -Recurse)
    $script:roleNames = @('frontend', 'backend-node', 'backend-java', 'backend-dotnet', 'devops', 'python', 'mobile', 'data')

    function Get-Frontmatter {
        <#
        .SYNOPSIS
            Extracts YAML frontmatter from a markdown file as raw text lines.
        #>
        param([string]$FilePath)
        $lines = Get-Content $FilePath
        if ($lines.Count -lt 2 -or $lines[0] -ne '---') { return $null }

        $endIndex = -1
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -eq '---') {
                $endIndex = $i
                break
            }
        }
        if ($endIndex -lt 0) { return $null }

        return $lines[1..($endIndex - 1)]
    }

    function Get-FrontmatterField {
        <#
        .SYNOPSIS
            Extracts a top-level field value from frontmatter lines.
        #>
        param([string[]]$FrontmatterLines, [string]$Field)
        foreach ($line in $FrontmatterLines) {
            if ($line -match "^${Field}:\s*(.+)$") {
                return $Matches[1].Trim()
            }
            # Handle multi-line values (field: >)
            if ($line -match "^${Field}:\s*>\s*$") {
                return '(multi-line)'
            }
        }
        return $null
    }
}

# ── Skill File Existence ──────────────────────────────────────────────────────

Describe 'Skill file inventory' {
    It 'has exactly 5 shared skills' {
        $script:sharedSkillFiles.Count | Should -Be 5
    }

    It 'has shared skills for: architecture, code-quality, debug, thinking, performance' {
        $expected = @('architecture', 'code-quality', 'debug', 'thinking', 'performance')
        foreach ($name in $expected) {
            $match = $script:sharedSkillFiles | Where-Object { $_.FullName -like "*$name*" }
            $match | Should -Not -BeNullOrEmpty -Because "shared skill '$name' should exist"
        }
    }

    It 'has at least 2 skills per role' {
        foreach ($role in $script:roleNames) {
            $roleDir = Join-Path $script:rolesDir $role
            $files = @(Get-ChildItem -Path $roleDir -Filter '*.md' -Recurse -ErrorAction SilentlyContinue)
            $files.Count | Should -BeGreaterOrEqual 2 -Because "role '$role' should have at least 2 skills"
        }
    }

    It 'has 23 total skill files (5 shared + 18 role)' {
        $script:allSkillFiles.Count | Should -Be 23
    }
}

# ── YAML Frontmatter Validation ───────────────────────────────────────────────

Describe 'Skill frontmatter' {
    It 'every skill file starts with YAML frontmatter (---)' {
        foreach ($file in $script:allSkillFiles) {
            $firstLine = (Get-Content $file.FullName -TotalCount 1)
            $firstLine | Should -Be '---' -Because "$($file.Name) must start with YAML frontmatter"
        }
    }

    It 'every skill file has a closing frontmatter delimiter (---)' {
        foreach ($file in $script:allSkillFiles) {
            $fm = Get-Frontmatter -FilePath $file.FullName
            $fm | Should -Not -BeNullOrEmpty -Because "$($file.Name) must have valid frontmatter"
        }
    }

    It 'every skill has a "name" field' {
        foreach ($file in $script:allSkillFiles) {
            $fm = Get-Frontmatter -FilePath $file.FullName
            $name = Get-FrontmatterField -FrontmatterLines $fm -Field 'name'
            $name | Should -Not -BeNullOrEmpty -Because "$($file.Name) must have a 'name' field"
        }
    }

    It 'every skill has a "description" field' {
        foreach ($file in $script:allSkillFiles) {
            $fm = Get-Frontmatter -FilePath $file.FullName
            $desc = Get-FrontmatterField -FrontmatterLines $fm -Field 'description'
            $desc | Should -Not -BeNullOrEmpty -Because "$($file.Name) must have a 'description' field"
        }
    }

    It 'every skill has "metadata" section' {
        foreach ($file in $script:allSkillFiles) {
            $fm = Get-Frontmatter -FilePath $file.FullName
            $hasMeta = $fm | Where-Object { $_ -match '^metadata:' }
            $hasMeta | Should -Not -BeNullOrEmpty -Because "$($file.Name) must have 'metadata' section"
        }
    }

    It 'every skill has author "team-ai-kit"' {
        foreach ($file in $script:allSkillFiles) {
            $fm = Get-Frontmatter -FilePath $file.FullName
            $author = Get-FrontmatterField -FrontmatterLines $fm -Field '  author'
            $author | Should -Be 'team-ai-kit' -Because "$($file.Name) author must be team-ai-kit"
        }
    }

    It 'every skill has a version field' {
        foreach ($file in $script:allSkillFiles) {
            $fm = Get-Frontmatter -FilePath $file.FullName
            $version = Get-FrontmatterField -FrontmatterLines $fm -Field '  version'
            $version | Should -Not -BeNullOrEmpty -Because "$($file.Name) must have a version"
        }
    }
}

# ── Required Sections ─────────────────────────────────────────────────────────

Describe 'Skill required sections' {
    It 'every skill has "## When to Use" section' {
        foreach ($file in $script:allSkillFiles) {
            $content = Get-Content $file.FullName -Raw
            $content | Should -BeLike '*## When to Use*' -Because "$($file.Name) must have '## When to Use'"
        }
    }

    It 'every skill has "## Critical Patterns" section' {
        foreach ($file in $script:allSkillFiles) {
            $content = Get-Content $file.FullName -Raw
            $content | Should -BeLike '*## Critical Patterns*' -Because "$($file.Name) must have '## Critical Patterns'"
        }
    }
}

# ── Content Quality ───────────────────────────────────────────────────────────

Describe 'Skill content quality' {
    It 'no skill file is empty or trivially short (< 200 chars)' {
        foreach ($file in $script:allSkillFiles) {
            $content = Get-Content $file.FullName -Raw
            $content.Length | Should -BeGreaterThan 200 -Because "$($file.Name) must have meaningful content"
        }
    }

    It 'no skill file contains lazwork references' {
        foreach ($file in $script:allSkillFiles) {
            $content = Get-Content $file.FullName -Raw
            $content | Should -Not -BeLike '*lazwork*' -Because "$($file.Name) must not reference lazwork"
        }
    }

    It 'description field mentions a trigger' {
        foreach ($file in $script:allSkillFiles) {
            $fm = Get-Frontmatter -FilePath $file.FullName
            # Get all frontmatter as single string to check for Trigger
            $fmText = $fm -join "`n"
            $fmText | Should -BeLike '*Trigger*' -Because "$($file.Name) description should mention when to trigger"
        }
    }
}

# ── Pack Rules ────────────────────────────────────────────────────────────────

Describe 'Pack rules files' {
    It 'every role has a pack rules file' {
        foreach ($role in $script:roleNames) {
            $rulesPath = Join-Path $script:packsDir "$role\rules.md"
            Test-Path $rulesPath | Should -BeTrue -Because "role '$role' must have packs/$role/rules.md"
        }
    }

    It 'pack rules files are not empty' {
        foreach ($role in $script:roleNames) {
            $rulesPath = Join-Path $script:packsDir "$role\rules.md"
            $content = Get-Content $rulesPath -Raw
            $content.Length | Should -BeGreaterThan 100 -Because "packs/$role/rules.md must have meaningful content"
        }
    }

    It 'pack rules files do not reference lazwork' {
        foreach ($role in $script:roleNames) {
            $rulesPath = Join-Path $script:packsDir "$role\rules.md"
            $content = Get-Content $rulesPath -Raw
            $content | Should -Not -BeLike '*lazwork*' -Because "packs/$role/rules.md must not reference lazwork"
        }
    }
}
