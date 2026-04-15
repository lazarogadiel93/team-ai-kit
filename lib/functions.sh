#!/usr/bin/env bash
# Team AI Kit -- Reusable functions for setup and configuration (macOS/Linux).
# Pure/testable functions used by the CLI. No interactive prompts here.
#
# Requires: bash 4+, git, jq, sha256sum (Linux) or shasum (macOS)

set -euo pipefail

# -- Constants -----------------------------------------------------------------

VALID_IDES=("vscode" "intellij" "opencode")
VALID_ROLES=("frontend" "backend-node" "devops" "python")
VALID_PROVIDERS=("openai" "azure-openai" "anthropic" "github-copilot")
VALID_COMMANDS=("setup" "init" "update" "status" "doctor" "help")

# -- Helpers -------------------------------------------------------------------

_lowercase() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

_array_contains() {
    local needle="$1"; shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

_sha256() {
    # Cross-platform SHA256: Linux has sha256sum, macOS has shasum
    local file="$1"
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        echo "ERROR: no sha256 tool found" >&2
        return 1
    fi
}

_json_read() {
    # Read a JSON file and extract a value with jq
    # Usage: _json_read file.json '.key'
    local file="$1" query="$2"
    if [[ ! -f "$file" ]]; then
        echo ""
        return 1
    fi
    jq -r "$query // empty" "$file" 2>/dev/null || echo ""
}

_json_write() {
    # Write a full JSON object to a file
    # Usage: echo '{"key":"val"}' | _json_write file.json
    local file="$1"
    local dir
    dir=$(dirname "$file")
    [[ -d "$dir" ]] || mkdir -p "$dir"
    jq '.' > "$file"
}

# -- Config Persistence --------------------------------------------------------

get_config_dir() { echo "$HOME/.team-ai-kit"; }

get_config_path() { echo "$(get_config_dir)/config.json"; }

get_config() {
    # Returns config JSON to stdout. Empty object if no config.
    local config_path
    config_path=$(get_config_path)
    if [[ -f "$config_path" ]]; then
        cat "$config_path"
    else
        echo '{"ide":null,"role":null,"provider":null,"teamRepo":null,"installedAt":null,"lastUpdate":null,"version":null}'
    fi
}

get_config_value() {
    # Usage: get_config_value "ide"
    local key="$1"
    get_config | jq -r ".$key // empty"
}

save_config() {
    # Usage: save_config '{"ide":"vscode","role":"frontend",...}'
    local json="$1"
    local config_path
    config_path=$(get_config_path)
    local config_dir
    config_dir=$(get_config_dir)
    [[ -d "$config_dir" ]] || mkdir -p "$config_dir"
    echo "$json" | jq '.' > "$config_path"
    echo "$config_path"
}

test_first_run() {
    local config_path
    config_path=$(get_config_path)
    [[ ! -f "$config_path" ]]
}

test_valid_command() {
    local cmd
    cmd=$(_lowercase "$1")
    _array_contains "$cmd" "${VALID_COMMANDS[@]}"
}

# -- Project Init --------------------------------------------------------------

get_project_config_path() {
    # Returns path to .team-ai-kit.json in the given project directory.
    local project_root="$1"
    echo "$project_root/.team-ai-kit.json"
}

test_project_initialized() {
    # Returns 0 if project has .team-ai-kit.json
    local project_root="$1"
    [[ -f "$(get_project_config_path "$project_root")" ]]
}

get_project_config() {
    # Returns project config JSON to stdout. Empty string if not initialized.
    local project_root="$1"
    local config_path
    config_path=$(get_project_config_path "$project_root")
    if [[ -f "$config_path" ]]; then
        cat "$config_path"
    else
        echo ""
    fi
}

get_project_config_value() {
    # Usage: get_project_config_value "/path/to/project" "role"
    local project_root="$1" key="$2"
    local config
    config=$(get_project_config "$project_root")
    [[ -z "$config" ]] && return 1
    echo "$config" | jq -r ".$key // empty"
}

save_project_config() {
    # Usage: save_project_config "/path/to/project" '{"role":"frontend",...}'
    local project_root="$1" json="$2"
    local config_path
    config_path=$(get_project_config_path "$project_root")
    echo "$json" | jq '.' > "$config_path"
    echo "$config_path"
}

initialize_shared_engram() {
    # Creates shared-engram/ directory and runs initial export if engram is available.
    # Usage: initialize_shared_engram "/path/to/project" "project-name"
    # Outputs JSON: {"path":"/...","exported":true/false,"count":0}
    local project_root="$1"
    local project_name="${2:-}"
    local engram_dir="$project_root/shared-engram"
    local exported="false"
    local count=0

    # Create directory
    [[ -d "$engram_dir" ]] || mkdir -p "$engram_dir"

    # Create .gitkeep
    [[ -f "$engram_dir/.gitkeep" ]] || touch "$engram_dir/.gitkeep"

    # Run initial export if engram is available
    if test_engram_installed; then
        local engram_bin=""
        engram_bin=$(get_engram_binary_path 2>/dev/null) || true
        if [[ -n "$engram_bin" ]]; then
            local export_file="$engram_dir/observations.json"
            local export_args=("export" "--format" "json" "--output" "$export_file")
            if [[ -n "$project_name" ]]; then
                export_args+=("--project" "$project_name")
            fi
            if "$engram_bin" "${export_args[@]}" 2>/dev/null; then
                exported="true"
                if [[ -f "$export_file" ]]; then
                    count=$(jq 'if type == "array" then length else 0 end' "$export_file" 2>/dev/null || echo 0)
                fi
            fi
        fi
    fi

    jq -n --arg path "$engram_dir" --argjson exported "$exported" --argjson count "$count" \
        '{path:$path, exported:$exported, count:$count}'
}

new_init_summary() {
    # Generates human-readable summary after project initialization.
    # Usage: new_init_summary "vscode" "frontend" ".github/copilot-instructions.md" 5
    local ide="$1" role="$2" instructions_path="${3:-}" engram_exported="${4:-0}"
    local engram_line
    if [[ "$engram_exported" -gt 0 ]]; then
        engram_line="$engram_exported observations exported"
    else
        engram_line="directory created (no observations yet)"
    fi
    cat <<EOF
============================================
  Team AI Kit -- Project Initialized
============================================
  IDE:            $ide
  Role:           $role
  Instructions:   $instructions_path
  Shared Engram:  $engram_line
============================================
EOF
}

# -- IDE-to-Agent Mapping ------------------------------------------------------

get_gentle_ai_agent_id() {
    local ide
    ide=$(_lowercase "$1")
    case "$ide" in
        vscode)   echo "vscode-copilot" ;;
        opencode) echo "opencode" ;;
        *)        return 1 ;;
    esac
}

test_gentle_ai_supports_ide() {
    get_gentle_ai_agent_id "$1" &>/dev/null
}

# -- Prerequisite Checks -------------------------------------------------------

test_brew_installed() { command -v brew &>/dev/null; }

test_jq_installed() { command -v jq &>/dev/null; }

test_gentle_ai_installed() { command -v gentle-ai &>/dev/null; }

test_engram_installed() {
    command -v engram &>/dev/null && return 0
    # Check Homebrew location
    [[ -x "/opt/homebrew/bin/engram" ]] && return 0
    [[ -x "/usr/local/bin/engram" ]] && return 0
    # Check local install
    [[ -x "$HOME/.local/bin/engram" ]] && return 0
    return 1
}

get_engram_binary_path() {
    if command -v engram &>/dev/null; then
        command -v engram
        return 0
    fi
    local paths=("/opt/homebrew/bin/engram" "/usr/local/bin/engram" "$HOME/.local/bin/engram")
    local p
    for p in "${paths[@]}"; do
        [[ -x "$p" ]] && echo "$p" && return 0
    done
    return 1
}

# -- Validation ----------------------------------------------------------------

test_valid_ide() {
    local ide
    ide=$(_lowercase "$1")
    _array_contains "$ide" "${VALID_IDES[@]}"
}

test_valid_role() {
    local role
    role=$(_lowercase "$1")
    _array_contains "$role" "${VALID_ROLES[@]}"
}

test_valid_provider() {
    local provider
    provider=$(_lowercase "$1")
    _array_contains "$provider" "${VALID_PROVIDERS[@]}"
}

# -- Skills Management ---------------------------------------------------------

get_shared_skill_paths() {
    local kit_root="$1"
    local shared_dir="$kit_root/skills/shared"
    [[ -d "$shared_dir" ]] || return 0
    find "$shared_dir" -name '*.md' -type f | sort
}

get_role_skill_paths() {
    local kit_root="$1" role="$2"
    local role_dir="$kit_root/skills/roles/$role"
    [[ -d "$role_dir" ]] || return 0
    find "$role_dir" -name '*.md' -type f | sort
}

get_all_skill_paths_for_role() {
    local kit_root="$1" role="$2"
    get_shared_skill_paths "$kit_root"
    get_role_skill_paths "$kit_root" "$role"
}

get_pack_rules_path() {
    local kit_root="$1" role="$2"
    local rules_path="$kit_root/packs/$role/rules.md"
    [[ -f "$rules_path" ]] && echo "$rules_path" || return 1
}

# -- IDE Config Paths ----------------------------------------------------------

get_ide_skills_directory() {
    local ide
    ide=$(_lowercase "$1")
    case "$ide" in
        vscode)   echo "$HOME/.copilot/skills" ;;
        intellij) echo "$HOME/.copilot/skills" ;;
        opencode) echo "$HOME/.config/opencode/skills" ;;
        *)        echo "ERROR: Unsupported IDE: $1" >&2; return 1 ;;
    esac
}

get_ide_instructions_path() {
    local ide project_root="$2"
    ide=$(_lowercase "$1")
    case "$ide" in
        vscode)   echo "$project_root/.github/copilot-instructions.md" ;;
        intellij) echo "$project_root/.github/copilot-instructions.md" ;;
        opencode) echo "$project_root/AGENTS.md" ;;
        *)        echo "ERROR: Unsupported IDE: $1" >&2; return 1 ;;
    esac
}

# -- Skills Installation (simple copy, no tracking) ----------------------------

install_team_skills() {
    local kit_root="$1" role="$2" target_dir="$3"
    local skills_base="$kit_root/skills"

    while IFS= read -r skill_path; do
        [[ -z "$skill_path" ]] && continue
        local relative_path="${skill_path#"$skills_base"/}"
        local dest_path="$target_dir/team-skills/$relative_path"
        local dest_dir
        dest_dir=$(dirname "$dest_path")
        [[ -d "$dest_dir" ]] || mkdir -p "$dest_dir"
        cp "$skill_path" "$dest_path"
        echo "$dest_path"
    done < <(get_all_skill_paths_for_role "$kit_root" "$role")
}

# -- Team Repo Management -----------------------------------------------------

get_team_repo_local_path() {
    echo "$(get_config_dir)/team-content"
}

test_team_repo_configured() {
    local repo
    repo=$(get_config_value "teamRepo")
    [[ -n "$repo" ]]
}

test_team_repo_cloned() {
    local local_path
    local_path=$(get_team_repo_local_path)
    [[ -d "$local_path/.git" ]]
}

invoke_team_repo_clone() {
    local repo_url="$1"
    local local_path
    local_path=$(get_team_repo_local_path)
    if test_team_repo_cloned; then
        invoke_team_repo_pull
        return $?
    fi
    local parent_dir
    parent_dir=$(dirname "$local_path")
    [[ -d "$parent_dir" ]] || mkdir -p "$parent_dir"
    git clone "$repo_url" "$local_path" &>/dev/null
}

invoke_team_repo_pull() {
    local local_path
    local_path=$(get_team_repo_local_path)
    test_team_repo_cloned || return 1
    git -C "$local_path" pull &>/dev/null
}

get_team_repo_skill_paths() {
    local role="$1"
    local local_path
    local_path=$(get_team_repo_local_path)
    [[ -d "$local_path" ]] || return 0

    local shared_dir="$local_path/skills/shared"
    if [[ -d "$shared_dir" ]]; then
        find "$shared_dir" -name '*.md' -type f | sort
    fi

    local role_dir="$local_path/skills/roles/$role"
    if [[ -d "$role_dir" ]]; then
        find "$role_dir" -name '*.md' -type f | sort
    fi
}

# -- Skill Manifest (hash tracking for no-overwrite) --------------------------

get_skill_manifest_path() {
    echo "$(get_config_dir)/manifest.json"
}

get_skill_manifest() {
    # Returns manifest JSON to stdout
    local manifest_path
    manifest_path=$(get_skill_manifest_path)
    if [[ -f "$manifest_path" ]]; then
        cat "$manifest_path"
    else
        echo '{"files":{}}'
    fi
}

save_skill_manifest() {
    # Usage: echo '{"files":{...}}' | save_skill_manifest
    local manifest_path
    manifest_path=$(get_skill_manifest_path)
    local manifest_dir
    manifest_dir=$(dirname "$manifest_path")
    [[ -d "$manifest_dir" ]] || mkdir -p "$manifest_dir"
    jq '.' > "$manifest_path"
}

get_file_content_hash() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    _sha256 "$file"
}

test_skill_modified_by_user() {
    # Returns 0 (true) if user modified the file, 1 (false) otherwise
    local file_path="$1" manifest_key="$2" manifest_json="$3"
    [[ -f "$file_path" ]] || return 1  # file doesn't exist = not modified

    # Check if key exists in manifest
    local recorded_hash
    recorded_hash=$(echo "$manifest_json" | jq -r ".files[\"$manifest_key\"].hash // empty" 2>/dev/null)
    if [[ -z "$recorded_hash" ]]; then
        # File exists but not in manifest = user-created, don't touch
        return 0
    fi

    local current_hash
    current_hash=$(get_file_content_hash "$file_path") || return 0
    [[ "$current_hash" != "$recorded_hash" ]]
}

# -- Skills Merge (3-layer: defaults + team + user) ----------------------------

install_single_skill_with_tracking() {
    # Installs one skill, returns action via stdout: installed|updated|skipped
    # Updates manifest_json via nameref (bash 4.3+) or temp file approach
    local source_path="$1" dest_path="$2" manifest_key="$3"
    local source="$4" manifest_file="$5" timestamp="$6"

    local dest_dir
    dest_dir=$(dirname "$dest_path")
    [[ -d "$dest_dir" ]] || mkdir -p "$dest_dir"

    local source_hash
    source_hash=$(get_file_content_hash "$source_path") || { echo "skipped"; return; }

    if [[ ! -f "$dest_path" ]]; then
        # File does not exist -> install
        cp "$source_path" "$dest_path"
        # Update manifest file in-place
        local tmp
        tmp=$(jq --arg key "$manifest_key" \
                 --arg hash "$source_hash" \
                 --arg src "$source" \
                 --arg ts "$timestamp" \
                 '.files[$key] = {hash: $hash, source: $src, installedAt: $ts}' \
                 "$manifest_file")
        echo "$tmp" > "$manifest_file"
        echo "installed"
        return
    fi

    # File exists -- check if user modified it
    local manifest_json
    manifest_json=$(cat "$manifest_file")
    if test_skill_modified_by_user "$dest_path" "$manifest_key" "$manifest_json"; then
        echo "skipped"
        return
    fi

    # Not modified -- check if source has changes
    local current_hash
    current_hash=$(get_file_content_hash "$dest_path") || { echo "skipped"; return; }
    if [[ "$current_hash" == "$source_hash" ]]; then
        echo "skipped"
        return
    fi

    # Source changed, user hasn't modified -> update
    cp "$source_path" "$dest_path"
    local tmp
    tmp=$(jq --arg key "$manifest_key" \
             --arg hash "$source_hash" \
             --arg src "$source" \
             --arg ts "$timestamp" \
             '.files[$key] = {hash: $hash, source: $src, installedAt: $ts}' \
             "$manifest_file")
    echo "$tmp" > "$manifest_file"
    echo "updated"
}

install_skills_with_merge() {
    # Usage: install_skills_with_merge kit_root role target_dir [include_team_repo]
    # Outputs: JSON with installed/updated/skipped counts
    local kit_root="$1" role="$2" target_dir="$3"
    local include_team_repo="${4:-false}"

    local manifest_path
    manifest_path=$(get_skill_manifest_path)
    local manifest_dir
    manifest_dir=$(dirname "$manifest_path")
    [[ -d "$manifest_dir" ]] || mkdir -p "$manifest_dir"

    # Initialize manifest file if it doesn't exist
    if [[ ! -f "$manifest_path" ]]; then
        echo '{"files":{}}' > "$manifest_path"
    fi

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local installed=0 updated=0 skipped=0
    local skills_base="$kit_root/skills"

    # Layer 1: Package defaults
    while IFS= read -r skill_path; do
        [[ -z "$skill_path" ]] && continue
        local relative_path="${skill_path#"$skills_base"/}"
        local manifest_key="team-skills/$relative_path"
        local dest_path="$target_dir/$manifest_key"

        local action
        action=$(install_single_skill_with_tracking \
            "$skill_path" "$dest_path" "$manifest_key" \
            "default" "$manifest_path" "$timestamp")

        case "$action" in
            installed) ((installed++)) ;;
            updated)   ((updated++)) ;;
            skipped)   ((skipped++)) ;;
        esac
    done < <(get_all_skill_paths_for_role "$kit_root" "$role")

    # Layer 2: Team repo
    if [[ "$include_team_repo" == "true" ]]; then
        local team_repo_path
        team_repo_path=$(get_team_repo_local_path)
        if [[ -d "$team_repo_path" ]]; then
            local team_skills_base="$team_repo_path/skills"

            while IFS= read -r skill_path; do
                [[ -z "$skill_path" ]] && continue
                local relative_path="${skill_path#"$team_skills_base"/}"
                local manifest_key="team-skills/$relative_path"
                local dest_path="$target_dir/$manifest_key"

                local action
                action=$(install_single_skill_with_tracking \
                    "$skill_path" "$dest_path" "$manifest_key" \
                    "team" "$manifest_path" "$timestamp")

                case "$action" in
                    installed) ((installed++)) ;;
                    updated)   ((updated++)) ;;
                    skipped)   ((skipped++)) ;;
                esac
            done < <(get_team_repo_skill_paths "$role")
        fi
    fi

    echo "{\"installed\":$installed,\"updated\":$updated,\"skipped\":$skipped}"
}

# -- MCP Config Generation ----------------------------------------------------

new_vscode_mcp_config() {
    local engram_path="$1"
    jq -n --arg engram "$engram_path" '{
        servers: {
            engram: {
                command: $engram,
                args: ["mcp", "--tools=agent"]
            },
            context7: {
                type: "sse",
                url: "https://mcp.context7.com/mcp"
            }
        }
    }'
}

# -- Instructions Generation ---------------------------------------------------

new_copilot_instructions() {
    local role="$1"
    local pack_rules_content="${2:-}"

    cat <<EOF
# Team AI Kit -- Copilot Instructions

> Auto-generated by team-ai-kit setup. Role: $role
> Do not edit manually -- re-run setup to update.

---

## Team Conventions

- Follow the team's established patterns and conventions
- Use engram to save decisions, discoveries, and bug fixes
- Search engram before starting work to check for prior knowledge
- Always explain WHY, not just WHAT, when making decisions

EOF

    if [[ -n "$pack_rules_content" ]]; then
        echo "$pack_rules_content"
    fi
}

# -- Template Engine -----------------------------------------------------------

get_template_directory() {
    local kit_root="$1" ide
    ide=$(_lowercase "$2")
    local dir_name
    case "$ide" in
        vscode)   dir_name="vscode-copilot" ;;
        intellij) dir_name="intellij-copilot" ;;
        opencode) dir_name="opencode" ;;
        *)        echo "ERROR: Unsupported IDE: $2" >&2; return 1 ;;
    esac
    local template_dir="$kit_root/templates/$dir_name"
    [[ -d "$template_dir" ]] && echo "$template_dir" || return 1
}

get_template_files() {
    local template_dir="$1"
    [[ -d "$template_dir" ]] || return 0
    find "$template_dir" -name '*.template' -type f | sort
}

expand_template() {
    # Usage: expand_template "content" "KEY1=val1" "KEY2=val2"
    local content="$1"; shift
    for pair in "$@"; do
        local key="${pair%%=*}"
        local val="${pair#*=}"
        content="${content//\{\{$key\}\}/$val}"
    done
    echo "$content"
}

install_templates() {
    local template_dir="$1" target_dir="$2"; shift 2
    # Remaining args are KEY=VALUE pairs

    while IFS= read -r tpl; do
        [[ -z "$tpl" ]] && continue
        local filename
        filename=$(basename "$tpl" .template)
        local dest_path="$target_dir/$filename"
        local dest_dir
        dest_dir=$(dirname "$dest_path")
        [[ -d "$dest_dir" ]] || mkdir -p "$dest_dir"

        local content
        content=$(cat "$tpl")
        content=$(expand_template "$content" "$@")
        printf '%s' "$content" > "$dest_path"
        echo "$dest_path"
    done < <(get_template_files "$template_dir")
}

# -- Summary -------------------------------------------------------------------

new_setup_summary() {
    local ide="$1" role="$2" provider="$3"
    local skills_copied="${4:-0}" gentle_ai_status="${5:-n/a}"

    cat <<EOF
============================================
  Team AI Kit -- Setup Complete
============================================
  IDE:         $ide
  Role:        $role
  Provider:    $provider
  gentle-ai:   $gentle_ai_status
  Team Skills: $skills_copied installed
============================================
EOF
}
