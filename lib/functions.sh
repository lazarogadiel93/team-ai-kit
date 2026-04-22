#!/usr/bin/env bash
# Team AI Kit -- Reusable functions for setup and configuration (macOS/Linux).
# Pure/testable functions used by the CLI. No interactive prompts here.
#
# Requires: bash 4+, git, jq, sha256sum (Linux) or shasum (macOS)

set -euo pipefail

# -- Constants -----------------------------------------------------------------

VALID_IDES=("vscode" "intellij" "opencode" "cursor")
VALID_ROLES=("frontend" "backend-node" "backend-java" "backend-dotnet" "devops" "python" "mobile" "data")
VALID_PROVIDERS=("openai" "azure-openai" "anthropic" "github-copilot")
VALID_COMMANDS=("setup" "init" "init-knowledge" "sync" "update" "uninstall" "status" "doctor" "help")

# -- Helpers -------------------------------------------------------------------

_lowercase() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

_require_jq() {
    # Validates that jq is installed before commands that depend on it.
    if ! command -v jq &>/dev/null; then
        echo "Error: 'jq' is required but not installed. Install it: brew install jq (macOS) or apt install jq (Linux)." >&2
        return 1
    fi
}

_sanitize_project_name() {
    # Strips unsafe characters from project name to prevent shell injection in git hooks.
    # Allows only: a-z A-Z 0-9 . _ -
    echo "$1" | tr -cd 'a-zA-Z0-9._-'
}

_resolve_team_repo() {
    # Resolves the effective team repo URL using priority: CLI param > project config > global config.
    # Usage: _resolve_team_repo "$project_root" "$cli_param"
    # Echoes the resolved URL (empty string if none configured).
    local project_root="$1"
    local cli_param="${2:-}"
    local result=""

    if [[ -n "$cli_param" ]]; then
        result="$cli_param"
    elif [[ -n "$project_root" ]] && test_project_initialized "$project_root" 2>/dev/null; then
        result=$(get_project_config_value "$project_root" "teamRepo" 2>/dev/null) || true
    fi
    if [[ -z "$result" ]]; then
        result=$(get_config_value "teamRepo" 2>/dev/null) || true
    fi
    echo "$result"
}

_get_installed_version() {
    # Returns the installed semver of a tool (gentle-ai or engram) by running `<tool> version`.
    # Echoes the version string (e.g. "1.2.3") or empty string if not found.
    local tool="$1"
    local output=""
    output=$("$tool" version 2>/dev/null) || true
    if [[ "$output" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

_get_latest_github_version() {
    # Returns the latest release version from a GitHub repo.
    # Usage: _get_latest_github_version "owner" "repo"
    # Echoes the version string (e.g. "1.2.3") or empty string if unavailable.
    local owner="$1" repo="$2"
    local tag=""

    # Try gh CLI first (most reliable)
    if command -v gh &>/dev/null; then
        tag=$(gh release view --repo "$owner/$repo" --json tagName -q '.tagName' 2>/dev/null) || true
    fi

    # Fallback: curl GitHub API
    if [[ -z "$tag" ]] && command -v curl &>/dev/null; then
        tag=$(curl -fsSL "https://api.github.com/repos/$owner/$repo/releases/latest" 2>/dev/null \
            | jq -r '.tag_name // empty' 2>/dev/null) || true
    fi

    if [[ "$tag" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

_version_lt() {
    # Returns 0 (true) if version $1 < $2, 1 (false) otherwise.
    # Simple semver comparison using sort -V.
    local v1="$1" v2="$2"
    if [[ "$v1" == "$v2" ]]; then return 1; fi
    local lowest
    lowest=$(printf '%s\n%s' "$v1" "$v2" | sort -V | head -n1)
    [[ "$lowest" == "$v1" ]]
}

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
    # Normalized to UPPERCASE for cross-platform consistency (PowerShell outputs uppercase)
    local file="$1"
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | awk '{print toupper($1)}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | awk '{print toupper($1)}'
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

ensure_gitattributes() {
    # Creates or updates .gitattributes with rules to collapse .engram/ diffs in PRs.
    # Uses linguist-generated to hide diffs on GitHub and -diff to hide locally.
    # Idempotent: skips if marker already present.
    # Usage: ensure_gitattributes "/path/to/project"
    # Outputs JSON: {"created":bool, "updated":bool, "path":"..."}
    local project_root="$1"
    local ga_path="$project_root/.gitattributes"
    local marker='# [team-ai-kit] engram diff rules'
    local block
    block=$(printf '%s\n%s\n%s' \
        "$marker" \
        '.engram/** linguist-generated=true' \
        '.engram/** -diff')

    if [[ -f "$ga_path" ]]; then
        if grep -qF "$marker" "$ga_path" 2>/dev/null; then
            jq -n --arg path "$ga_path" '{created:false, updated:false, path:$path}'
            return
        fi
        # Append with a blank line separator
        printf '\n%s\n' "$block" >> "$ga_path"
        jq -n --arg path "$ga_path" '{created:false, updated:true, path:$path}'
    else
        printf '%s\n' "$block" > "$ga_path"
        jq -n --arg path "$ga_path" '{created:true, updated:false, path:$path}'
    fi
}

remove_gitattributes_block() {
    # Removes team-ai-kit lines from .gitattributes during uninstall.
    # Deletes the file if only our lines remain.
    # Usage: remove_gitattributes_block "/path/to/project"
    local project_root="$1"
    local ga_path="$project_root/.gitattributes"
    local marker='# [team-ai-kit] engram diff rules'

    [[ -f "$ga_path" ]] || return 0
    grep -qF "$marker" "$ga_path" 2>/dev/null || return 0

    local cleaned=""
    local skip_next=false
    while IFS= read -r line; do
        if [[ "$line" == *"$marker"* ]]; then
            skip_next=true
            continue
        fi
        if [[ "$skip_next" == true ]]; then
            # Skip the two rule lines that follow the marker
            if [[ "$line" == .engram/* ]]; then
                continue
            fi
            skip_next=false
        fi
        cleaned+="$line"$'\n'
    done < "$ga_path"

    # Remove trailing blank lines
    cleaned=$(printf '%s' "$cleaned" | sed -e :a -e '/^[[:space:]]*$/{ $d; N; ba; }')

    if [[ -z "$cleaned" || "$cleaned" =~ ^[[:space:]]*$ ]]; then
        rm -f "$ga_path"
    else
        printf '%s\n' "$cleaned" > "$ga_path"
    fi
}

initialize_engram_sync() {
    # Runs initial engram sync to export project memories to .engram/.
    # Uses native 'engram sync --project <name>' for team knowledge sharing via git.
    # Usage: initialize_engram_sync "/path/to/project" "project-name"
    # Outputs JSON: {"path":"/...","synced":true/false}
    local project_root="$1"
    local project_name="${2:-}"
    local engram_dir="$project_root/.engram"
    local synced="false"

    # Run initial sync if engram is available
    if test_engram_installed; then
        local engram_bin=""
        engram_bin=$(get_engram_binary_path 2>/dev/null) || true
        if [[ -n "$engram_bin" ]]; then
            local sync_args=("sync")
            if [[ -n "$project_name" ]]; then
                sync_args+=("--project" "$project_name")
            else
                sync_args+=("--all")
            fi
            if "$engram_bin" "${sync_args[@]}" 2>/dev/null; then
                synced="true"
            fi
        fi
    fi

    jq -n --arg path "$engram_dir" --argjson synced "$synced" \
        '{path:$path, synced:$synced}'
}

install_git_hooks() {
    # Installs pre-commit and post-merge git hooks for automatic engram sync.
    # Hooks are fail-safe (no-op if engram is not installed).
    # Respects existing hooks by appending with a marker comment.
    # Usage: install_git_hooks "/path/to/project" "project-name"
    # Outputs JSON: {"installed":["pre-commit","post-merge"],"skipped":[]}
    local project_root="$1"
    local project_name="${2:-}"
    local git_hooks_dir="$project_root/.git/hooks"
    local installed=()
    local skipped=()
    local marker='# [team-ai-kit] engram sync hook'

    if [[ ! -d "$project_root/.git" ]]; then
        jq -n '{installed:[], skipped:["not-a-git-repo"]}'
        return
    fi

    [[ -d "$git_hooks_dir" ]] || mkdir -p "$git_hooks_dir"

    local project_flag
    if [[ -n "$project_name" ]]; then
        project_flag="--project \"$project_name\""
    else
        project_flag="--all"
    fi

    # -- pre-commit hook -------------------------------------------------------
    local pre_commit_path="$git_hooks_dir/pre-commit"
    local pre_commit_block
    pre_commit_block=$(cat <<HOOKEOF

$marker
if command -v engram >/dev/null 2>&1; then
    engram sync $project_flag 2>/dev/null || true
    git add .engram/ 2>/dev/null || true
fi
HOOKEOF
)

    if [[ -f "$pre_commit_path" ]]; then
        if grep -qF "$marker" "$pre_commit_path" 2>/dev/null; then
            skipped+=("pre-commit")
        else
            echo "$pre_commit_block" >> "$pre_commit_path"
            installed+=("pre-commit")
        fi
    else
        printf '#!/bin/sh\n%s\n' "$pre_commit_block" > "$pre_commit_path"
        chmod +x "$pre_commit_path"
        installed+=("pre-commit")
    fi

    # -- post-merge hook -------------------------------------------------------
    local post_merge_path="$git_hooks_dir/post-merge"
    local post_merge_block
    post_merge_block=$(cat <<HOOKEOF

$marker
if command -v engram >/dev/null 2>&1; then
    engram sync --import 2>/dev/null || true
fi
HOOKEOF
)

    if [[ -f "$post_merge_path" ]]; then
        if grep -qF "$marker" "$post_merge_path" 2>/dev/null; then
            skipped+=("post-merge")
        else
            echo "$post_merge_block" >> "$post_merge_path"
            installed+=("post-merge")
        fi
    else
        printf '#!/bin/sh\n%s\n' "$post_merge_block" > "$post_merge_path"
        chmod +x "$post_merge_path"
        installed+=("post-merge")
    fi

    # Output JSON result
    local inst_json skip_json
    if [[ ${#installed[@]} -gt 0 ]]; then
        inst_json=$(printf '%s\n' "${installed[@]}" | jq -R . | jq -s .)
    else
        inst_json='[]'
    fi
    if [[ ${#skipped[@]} -gt 0 ]]; then
        skip_json=$(printf '%s\n' "${skipped[@]}" | jq -R . | jq -s .)
    else
        skip_json='[]'
    fi
    jq -n --argjson installed "$inst_json" --argjson skipped "$skip_json" \
        '{installed:$installed, skipped:$skipped}'
}

invoke_engram_sync() {
    # Wrapper around 'engram sync' for manual sync operations.
    # Usage: invoke_engram_sync "project-name" "export|import|status"
    # Outputs JSON: {"success":true/false,"message":"..."}
    local project_name="${1:-}"
    local operation="${2:-export}"

    if ! test_engram_installed; then
        jq -n '{success:false, message:"engram is not installed"}'
        return
    fi

    local engram_bin=""
    engram_bin=$(get_engram_binary_path 2>/dev/null) || true
    if [[ -z "$engram_bin" ]]; then
        jq -n '{success:false, message:"engram binary not found"}'
        return
    fi

    local exit_code=0
    case "$operation" in
        export)
            local sync_args=("sync")
            if [[ -n "$project_name" ]]; then
                sync_args+=("--project" "$project_name")
            else
                sync_args+=("--all")
            fi
            "$engram_bin" "${sync_args[@]}" 2>/dev/null || exit_code=$?
            ;;
        import)
            "$engram_bin" sync --import 2>/dev/null || exit_code=$?
            ;;
        status)
            "$engram_bin" sync --status 2>/dev/null || exit_code=$?
            ;;
    esac

    if [[ "$exit_code" -eq 0 ]]; then
        jq -n --arg op "$operation" '{success:true, message:("engram sync " + $op + " completed")}'
    else
        jq -n --arg op "$operation" --arg code "$exit_code" \
            '{success:false, message:("engram sync " + $op + " failed (exit code: " + $code + ")")}'
    fi
}

new_init_summary() {
    # Generates human-readable summary after project initialization.
    # Usage: new_init_summary "vscode" "frontend" ".github/copilot-instructions.md" "true" 2
    local ide="$1" role="$2" instructions_path="${3:-}" engram_synced="${4:-false}" hooks_installed="${5:-0}"
    local engram_line hooks_line
    if [[ "$engram_synced" == "true" ]]; then
        engram_line="synced via engram sync"
    else
        engram_line="not synced (engram not available)"
    fi
    if [[ "$hooks_installed" -gt 0 ]]; then
        hooks_line="$hooks_installed hook(s) installed"
    else
        hooks_line="no hooks installed"
    fi
    cat <<EOF
============================================
  Team AI Kit -- Project Initialized
============================================
  IDE:            $ide
  Role:           $role
  Instructions:   $instructions_path
  Engram Sync:    $engram_line
  Git Hooks:      $hooks_line
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
        cursor)   echo "cursor" ;;
        *)        return 1 ;;
    esac
}

test_gentle_ai_supports_ide() {
    get_gentle_ai_agent_id "$1" &>/dev/null
}

# -- Prerequisite Checks -------------------------------------------------------

test_brew_installed() { command -v brew &>/dev/null; }

test_jq_installed() { command -v jq &>/dev/null; }

test_curl_installed() { command -v curl &>/dev/null; }

# -- Direct Download Support ---------------------------------------------------

get_direct_download_bin_dir() {
    # Returns ~/.local/bin (standard user bin for Linux/macOS)
    echo "$HOME/.local/bin"
}

get_platform_architecture() {
    # Returns os_arch string for GitHub release asset matching (e.g. linux_amd64, darwin_arm64)
    local os arch
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$os" in
        darwin) os="darwin" ;;
        linux)  os="linux" ;;
        *)      echo "ERROR: Unsupported OS: $os" >&2; return 1 ;;
    esac
    arch=$(uname -m)
    case "$arch" in
        x86_64)        arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)             echo "ERROR: Unsupported architecture: $arch" >&2; return 1 ;;
    esac
    echo "${os}_${arch}"
}

get_github_latest_release_asset_url() {
    # Queries GitHub API for the latest release asset matching a regex pattern.
    # Usage: get_github_latest_release_asset_url owner repo "asset_regex_pattern"
    # Outputs JSON: {"url":"...","version":"v1.2.3"}
    local owner="$1" repo="$2" asset_pattern="$3"
    local api_url="https://api.github.com/repos/$owner/$repo/releases/latest"
    local curl_auth_args=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        curl_auth_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi
    local tmp_file release_json http_code
    tmp_file=$(mktemp /tmp/tak_release_XXXXXX.json)
    http_code=$(curl -sSL -w '%{http_code}' -o "$tmp_file" "${curl_auth_args[@]}" "$api_url") || true
    if [[ -z "$http_code" ]]; then
        echo "ERROR: Network request to GitHub API failed for $owner/$repo (check connectivity)" >&2
        rm -f "$tmp_file"
        return 1
    elif [[ "$http_code" == "403" ]]; then
        echo "ERROR: GitHub API rate limit exceeded for $owner/$repo. Set GITHUB_TOKEN environment variable to authenticate." >&2
        rm -f "$tmp_file"
        return 1
    elif [[ "$http_code" != "200" ]]; then
        echo "ERROR: Failed to query GitHub API for $owner/$repo (HTTP $http_code)" >&2
        rm -f "$tmp_file"
        return 1
    fi
    release_json=$(cat "$tmp_file")
    rm -f "$tmp_file"

    local asset_url
    asset_url=$(echo "$release_json" | jq -r ".assets[] | select(.name | test(\"$asset_pattern\")) | .browser_download_url" | head -1)
    local version
    version=$(echo "$release_json" | jq -r '.tag_name')

    if [[ -z "$asset_url" || "$asset_url" == "null" ]]; then
        echo "ERROR: No asset matching pattern '$asset_pattern' for $owner/$repo" >&2
        return 1
    fi
    jq -n --arg url "$asset_url" --arg version "$version" '{url:$url, version:$version}'
}

install_github_release_binary() {
    # Downloads and installs a binary from a GitHub release.
    # Usage: install_github_release_binary owner repo binary_name
    # Outputs JSON: {"installed":true,"version":"v1.2.3","path":"/path/to/binary"}
    local owner="$1" repo="$2" binary_name="$3"

    local platform
    platform=$(get_platform_architecture) || return 1

    local asset_pattern="${repo}_.*_${platform}\\.tar\\.gz"

    local release_info
    release_info=$(get_github_latest_release_asset_url "$owner" "$repo" "$asset_pattern") || return 1
    local url version
    url=$(echo "$release_info" | jq -r '.url')
    version=$(echo "$release_info" | jq -r '.version')

    local bin_dir
    bin_dir=$(get_direct_download_bin_dir)
    [[ -d "$bin_dir" ]] || mkdir -p "$bin_dir"

    local temp_dir
    temp_dir=$(mktemp -d)

    if ! (
        set -e
        cd "$temp_dir" || exit 1
        local curl_dl_args=()
        if [[ -n "${GITHUB_TOKEN:-}" ]]; then
            curl_dl_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
        fi
        curl -sSLf "${curl_dl_args[@]}" "$url" -o "archive.tar.gz" || {
            echo "ERROR: Failed to download release archive from $url" >&2
            exit 1
        }
        tar xzf "archive.tar.gz"
        local found_binary
        found_binary=$(find . -name "$binary_name" -type f | head -1)
        if [[ -z "$found_binary" ]]; then
            echo "ERROR: Binary '$binary_name' not found in archive" >&2
            exit 1
        fi
        chmod +x "$found_binary"
        cp "$found_binary" "$bin_dir/$binary_name"
    ); then
        rm -rf "$temp_dir"
        return 1
    fi

    rm -rf "$temp_dir"
    jq -n --arg version "$version" --arg path "$bin_dir/$binary_name" \
        '{installed:true, version:$version, path:$path}'
}

add_to_path_if_needed() {
    # Adds directory to current session PATH and appends to shell profiles if needed.
    # Usage: add_to_path_if_needed "/path/to/dir"
    # Returns "true" if added to at least one profile, "false" otherwise.
    local dir="$1"

    # Add to current session
    case ":$PATH:" in
        *":$dir:"*) ;;
        *) export PATH="$dir:$PATH" ;;
    esac

    # Add to shell profiles for persistence
    local added="false"
    local marker="# Added by team-ai-kit"

    # If no profile files exist, create one for the user's current shell
    local has_profile="false"
    for p in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        [[ -f "$p" ]] && has_profile="true" && break
    done
    if [[ "$has_profile" == "false" ]]; then
        local shell_name
        shell_name=$(basename "${SHELL:-/bin/bash}")
        case "$shell_name" in
            zsh)  touch "$HOME/.zshrc" ;;
            bash) touch "$HOME/.bashrc" ;;
            *)    touch "$HOME/.profile" ;;
        esac
    fi

    for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [[ -f "$profile" ]] && ! grep -qxF "export PATH=\"$dir:\$PATH\"" "$profile" 2>/dev/null; then
            printf '\n%s\nexport PATH="%s:$PATH"\n' "$marker" "$dir" >> "$profile"
            added="true"
        fi
    done
    echo "$added"
}

test_gentle_ai_installed() {
    command -v gentle-ai &>/dev/null && return 0
    # Check Homebrew locations
    [[ -x "/opt/homebrew/bin/gentle-ai" ]] && return 0
    [[ -x "/usr/local/bin/gentle-ai" ]] && return 0
    # Check direct download location
    local direct_path
    direct_path="$(get_direct_download_bin_dir)/gentle-ai"
    [[ -x "$direct_path" ]] && return 0
    return 1
}

get_gentle_ai_binary_path() {
    if command -v gentle-ai &>/dev/null; then
        command -v gentle-ai
        return 0
    fi
    local paths=("/opt/homebrew/bin/gentle-ai" "/usr/local/bin/gentle-ai" "$(get_direct_download_bin_dir)/gentle-ai")
    local p
    for p in "${paths[@]}"; do
        [[ -x "$p" ]] && echo "$p" && return 0
    done
    return 1
}

test_engram_installed() {
    command -v engram &>/dev/null && return 0
    # Check Homebrew location
    [[ -x "/opt/homebrew/bin/engram" ]] && return 0
    [[ -x "/usr/local/bin/engram" ]] && return 0
    # Check local install / direct download
    [[ -x "$(get_direct_download_bin_dir)/engram" ]] && return 0
    return 1
}

get_engram_binary_path() {
    if command -v engram &>/dev/null; then
        command -v engram
        return 0
    fi
    local paths=("/opt/homebrew/bin/engram" "/usr/local/bin/engram" "$(get_direct_download_bin_dir)/engram")
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
    find "$shared_dir" -name 'SKILL.md' -type f | sort
}

get_role_skill_paths() {
    local kit_root="$1" role="$2"
    local role_dir="$kit_root/skills/roles/$role"
    [[ -d "$role_dir" ]] || return 0
    find "$role_dir" -name 'SKILL.md' -type f | sort
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
        cursor)   echo "$HOME/.cursor/skills" ;;
        *)        echo "ERROR: Unsupported IDE: $1" >&2; return 1 ;;
    esac
}

get_ide_project_skills_directory() {
    # Returns the project-level skills directory for the given IDE.
    # Usage: get_ide_project_skills_directory ide project_root
    local ide project_root="$2"
    ide=$(_lowercase "$1")
    case "$ide" in
        vscode)   echo "$project_root/.github/skills" ;;
        intellij) echo "$project_root/.github/skills" ;;
        opencode) echo "$project_root/.agents/skills" ;;
        cursor)   echo "$project_root/.cursor/skills" ;;
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
        cursor)   echo "$project_root/.cursor/rules/team-ai-kit.md" ;;
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
    local repo_url="${1:-}"
    if [[ -n "$repo_url" ]]; then
        local hash
        hash=$(echo -n "$repo_url" | { sha256sum 2>/dev/null || shasum -a 256; } | cut -c1-12)
        echo "$(get_config_dir)/team-content/$hash"
    else
        echo "$(get_config_dir)/team-content"
    fi
}

test_team_repo_configured() {
    local repo
    repo=$(get_config_value "teamRepo")
    [[ -n "$repo" ]]
}

test_team_repo_cloned() {
    local repo_url="${1:-}"
    local local_path
    local_path=$(get_team_repo_local_path "$repo_url")
    [[ -d "$local_path/.git" ]]
}

invoke_team_repo_clone() {
    local repo_url="$1"
    local local_path
    local_path=$(get_team_repo_local_path "$repo_url")
    if test_team_repo_cloned "$repo_url"; then
        invoke_team_repo_pull "$repo_url"
        return $?
    fi
    local parent_dir
    parent_dir=$(dirname "$local_path")
    [[ -d "$parent_dir" ]] || mkdir -p "$parent_dir"
    git clone "$repo_url" "$local_path" &>/dev/null
}

invoke_team_repo_pull() {
    local repo_url="${1:-}"
    local local_path
    local_path=$(get_team_repo_local_path "$repo_url")
    test_team_repo_cloned "$repo_url" || return 1
    git -C "$local_path" pull &>/dev/null
}

get_team_repo_skill_paths() {
    local role="$1"
    local repo_url="${2:-}"
    local local_path
    local_path=$(get_team_repo_local_path "$repo_url")
    [[ -d "$local_path" ]] || return 0

    local shared_dir="$local_path/skills/shared"
    if [[ -d "$shared_dir" ]]; then
        find "$shared_dir" -name 'SKILL.md' -type f | sort
    fi

    local role_dir="$local_path/skills/roles/$role"
    if [[ -d "$role_dir" ]]; then
        find "$role_dir" -name 'SKILL.md' -type f | sort
    fi
}

get_team_repo_rules_content() {
    local repo_url="${1:-}"
    local local_path
    local_path=$(get_team_repo_local_path "$repo_url")
    local rules_dir="$local_path/rules"
    [[ -d "$rules_dir" ]] || return 0

    local found=false
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if $found; then echo ""; echo ""; fi
        cat "$file"
        found=true
    done < <(find "$rules_dir" -name '*.md' -type f | sort)
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
    # Installs one skill. Returns "action\nmanifest_json" via stdout.
    # Caller is responsible for writing manifest to disk once at the end.
    # Usage: install_single_skill_with_tracking source dest key source_label manifest_json timestamp
    local source_path="$1" dest_path="$2" manifest_key="$3"
    local source="$4" manifest_json="$5" timestamp="$6"

    local dest_dir
    dest_dir=$(dirname "$dest_path")
    [[ -d "$dest_dir" ]] || mkdir -p "$dest_dir"

    local source_hash
    source_hash=$(get_file_content_hash "$source_path") || { printf 'skipped\n%s' "$manifest_json"; return; }

    _update_manifest_entry() {
        echo "$manifest_json" | jq --arg key "$manifest_key" \
             --arg hash "$source_hash" \
             --arg src "$source" \
             --arg ts "$timestamp" \
             '.files[$key] = {hash: $hash, source: $src, installedAt: $ts}'
    }

    if [[ ! -f "$dest_path" ]]; then
        cp "$source_path" "$dest_path"
        printf 'installed\n%s' "$(_update_manifest_entry)"
        return
    fi

    # File exists -- check if user modified it
    if test_skill_modified_by_user "$dest_path" "$manifest_key" "$manifest_json"; then
        printf 'skipped\n%s' "$manifest_json"
        return
    fi

    # Not modified -- check if source has changes
    local current_hash
    current_hash=$(get_file_content_hash "$dest_path") || { printf 'skipped\n%s' "$manifest_json"; return; }
    if [[ "$current_hash" == "$source_hash" ]]; then
        printf 'skipped\n%s' "$manifest_json"
        return
    fi

    # Source changed, user hasn't modified -> update
    cp "$source_path" "$dest_path"
    printf 'updated\n%s' "$(_update_manifest_entry)"
}

# shellcheck disable=SC2178,SC2128
install_skills_with_merge() {
    # Usage: install_skills_with_merge kit_root role target_dir [include_team_repo] [team_repo_url]
    # Outputs: JSON with installed/updated/skipped counts
    local kit_root="$1" role="$2" target_dir="$3"
    local include_team_repo="${4:-false}"
    local team_repo_url="${5:-}"

    local manifest_path
    manifest_path=$(get_skill_manifest_path)
    local manifest_dir
    manifest_dir=$(dirname "$manifest_path")
    [[ -d "$manifest_dir" ]] || mkdir -p "$manifest_dir"

    # Load manifest once into memory
    local manifest_json='{"files":{}}'
    if [[ -f "$manifest_path" ]]; then
        manifest_json=$(cat "$manifest_path")
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

        local result
        result=$(install_single_skill_with_tracking \
            "$skill_path" "$dest_path" "$manifest_key" \
            "default" "$manifest_json" "$timestamp")

        local action
        action=$(head -1 <<< "$result")
        manifest_json=$(tail -n +2 <<< "$result")

        case "$action" in
            installed) installed=$((installed + 1)) ;;
            updated)   updated=$((updated + 1)) ;;
            skipped)   skipped=$((skipped + 1)) ;;
        esac
    done < <(get_all_skill_paths_for_role "$kit_root" "$role")

    # Layer 2: Team repo
    if [[ "$include_team_repo" == "true" ]]; then
        local team_repo_path
        team_repo_path=$(get_team_repo_local_path "$team_repo_url")
        if [[ -d "$team_repo_path" ]]; then
            local team_skills_base="$team_repo_path/skills"

            while IFS= read -r skill_path; do
                [[ -z "$skill_path" ]] && continue
                local relative_path="${skill_path#"$team_skills_base"/}"
                local manifest_key="team-skills/$relative_path"
                local dest_path="$target_dir/$manifest_key"

                local result
                result=$(install_single_skill_with_tracking \
                    "$skill_path" "$dest_path" "$manifest_key" \
                    "team" "$manifest_json" "$timestamp")

                local action
                action=$(head -1 <<< "$result")
                manifest_json=$(tail -n +2 <<< "$result")

                case "$action" in
                    installed) installed=$((installed + 1)) ;;
                    updated)   updated=$((updated + 1)) ;;
                    skipped)   skipped=$((skipped + 1)) ;;
                esac
            done < <(get_team_repo_skill_paths "$role" "$team_repo_url")
        fi
    fi

    # Write manifest once at end
    echo "$manifest_json" | jq '.' > "$manifest_path"

    echo "{\"installed\":$installed,\"updated\":$updated,\"skipped\":$skipped}"
}

# shellcheck disable=SC2178,SC2128
install_project_skills() {
    # Installs team-knowledge repo skills into project-level directory.
    # Tracks last-installed hashes via a local manifest so user modifications
    # are not overwritten.
    # Usage: install_project_skills role team_repo_url target_dir
    # Outputs: JSON with installed/updated/skipped counts
    local role="$1" team_repo_url="$2" target_dir="$3"

    local installed=0 updated=0 skipped=0

    local team_repo_path
    team_repo_path=$(get_team_repo_local_path "$team_repo_url")
    if [[ ! -d "$team_repo_path" ]]; then
        echo "{\"installed\":0,\"updated\":0,\"skipped\":0}"
        return
    fi

    local team_skills_base="$team_repo_path/skills"
    local team_skills_dir="$target_dir/team-skills"
    local manifest_path="$team_skills_dir/.team-ai-kit-skills-manifest.json"

    # Load existing manifest
    local manifest_json='{"files":{}}'
    if [[ -f "$manifest_path" ]]; then
        manifest_json=$(cat "$manifest_path")
    fi

    while IFS= read -r skill_path; do
        [[ -z "$skill_path" ]] && continue
        local relative_path="${skill_path#"$team_skills_base"/}"
        local dest_path="$target_dir/team-skills/$relative_path"
        local dest_dir
        dest_dir=$(dirname "$dest_path")
        [[ -d "$dest_dir" ]] || mkdir -p "$dest_dir"

        local source_hash
        source_hash=$(get_file_content_hash "$skill_path") || continue

        if [[ ! -f "$dest_path" ]]; then
            cp "$skill_path" "$dest_path"
            manifest_json=$(echo "$manifest_json" | jq --arg key "$relative_path" --arg hash "$source_hash" '.files[$key] = {hash: $hash}')
            installed=$((installed + 1))
        else
            local dest_hash
            dest_hash=$(get_file_content_hash "$dest_path")
            if [[ "$source_hash" == "$dest_hash" ]]; then
                manifest_json=$(echo "$manifest_json" | jq --arg key "$relative_path" --arg hash "$source_hash" '.files[$key] = {hash: $hash}')
                skipped=$((skipped + 1))
            else
                # Source and dest differ -- check if user modified it
                local last_installed_hash
                last_installed_hash=$(echo "$manifest_json" | jq -r ".files[\"$relative_path\"].hash // empty" 2>/dev/null)
                if [[ -n "$last_installed_hash" && "$dest_hash" != "$last_installed_hash" ]]; then
                    # User modified the file -- skip to preserve their changes
                    skipped=$((skipped + 1))
                else
                    # File matches last-installed hash or no record -- safe to update
                    cp "$skill_path" "$dest_path"
                    manifest_json=$(echo "$manifest_json" | jq --arg key "$relative_path" --arg hash "$source_hash" '.files[$key] = {hash: $hash}')
                    updated=$((updated + 1))
                fi
            fi
        fi
    done < <(get_team_repo_skill_paths "$role" "$team_repo_url")

    # Save updated manifest
    [[ -d "$team_skills_dir" ]] || mkdir -p "$team_skills_dir"
    echo "$manifest_json" | jq '.' > "$manifest_path"

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

new_cursor_mcp_config() {
    local engram_path="$1"
    jq -n --arg engram "$engram_path" '{
        mcpServers: {
            engram: {
                command: $engram,
                args: ["mcp", "--tools=agent"]
            },
            context7: {
                url: "https://mcp.context7.com/mcp"
            }
        }
    }'
}

# -- Instructions Generation ---------------------------------------------------

new_copilot_instructions() {
    # Usage: new_copilot_instructions role [pack_rules_content] [team_rules_content] [skip_engram_protocol]
    # skip_engram_protocol: "true" to skip engram protocol (gentle-ai handles it)
    local role="$1"
    local pack_rules_content="${2:-}"
    local team_rules_content="${3:-}"
    local skip_engram_protocol="${4:-false}"

    cat <<EOF
# Team AI Kit -- Copilot Instructions

> Auto-generated by team-ai-kit. Role: $role
> Do not edit between team-ai-kit markers -- use team-ai-kit update to refresh.

---

## Team Conventions

- Follow the team's established patterns and conventions
- Always explain WHY, not just WHAT, when making decisions

EOF

    if [[ "$skip_engram_protocol" != "true" ]]; then
        get_engram_protocol_content
    fi

    if [[ -n "$pack_rules_content" ]]; then
        printf '%s\n' "$pack_rules_content"
    fi

    if [[ -n "$team_rules_content" ]]; then
        printf '\n<!-- team-ai-kit:team-rules -->\n'
        printf '%s\n' "$team_rules_content"
        printf '<!-- /team-ai-kit:team-rules -->\n'
    fi
}

update_instructions_team_rules() {
    # Usage: update_instructions_team_rules file_path team_rules_content
    # Updates only the team-rules section in an existing instructions file.
    # Outputs: "changed" or "unchanged"
    local file_path="$1"
    local team_rules_content="$2"

    [[ -f "$file_path" ]] || { echo "unchanged"; return; }

    local existing
    existing=$(cat "$file_path")

    local start_marker='<!-- team-ai-kit:team-rules -->'
    local end_marker='<!-- /team-ai-kit:team-rules -->'
    local new_section
    new_section=$(printf '%s\n%s\n%s' "$start_marker" "$team_rules_content" "$end_marker")

    local updated
    if echo "$existing" | grep -qF "$start_marker"; then
        # Replace between markers using temp file to avoid awk escape issues
        local tmpfile
        tmpfile=$(mktemp)
        local in_section=false
        while IFS= read -r line; do
            if [[ "$line" == *"$start_marker"* ]]; then
                printf '%s\n' "$new_section" >> "$tmpfile"
                in_section=true
            elif [[ "$line" == *"$end_marker"* ]]; then
                in_section=false
            elif [[ "$in_section" == false ]]; then
                printf '%s\n' "$line" >> "$tmpfile"
            fi
        done <<< "$existing"
        updated=$(cat "$tmpfile")
        rm -f "$tmpfile"
    else
        updated=$(printf '%s\n\n%s\n' "$existing" "$new_section")
    fi

    if [[ "$updated" == "$existing" ]]; then
        echo "unchanged"
        return
    fi

    printf '%s\n' "$updated" > "$file_path"
    echo "changed"
}

get_engram_protocol_content() {
    # Returns the Engram Memory Protocol markdown content wrapped in markers.
    # Uses single-quoted heredoc delimiter to prevent variable expansion.
    cat <<'ENGRAM_PROTOCOL_EOF'

<!-- team-ai-kit:engram-protocol -->
## Engram Persistent Memory -- Protocol

You have access to Engram, a persistent memory system that survives across sessions and compactions.
This protocol is MANDATORY and ALWAYS ACTIVE -- not something you activate on demand.

### PROACTIVE SAVE TRIGGERS (mandatory -- do NOT wait for user to ask)

Call `mem_save` IMMEDIATELY and WITHOUT BEING ASKED after any of these:
- Architecture or design decision made
- Team convention documented or established
- Workflow change agreed upon
- Tool or library choice made with tradeoffs
- Bug fix completed (include root cause)
- Feature implemented with non-obvious approach
- Configuration change or environment setup done
- Non-obvious discovery about the codebase
- Gotcha, edge case, or unexpected behavior found
- Pattern established (naming, structure, convention)
- User preference or constraint learned

Self-check after EVERY task: "Did I make a decision, fix a bug, learn something non-obvious, or establish a convention? If yes, call mem_save NOW."

Format for `mem_save`:
- **title**: Verb + what -- short, searchable (e.g. "Fixed N+1 query in UserList")
- **type**: bugfix | decision | architecture | discovery | pattern | config | preference
- **scope**: `project` (default) | `personal`
- **topic_key** (recommended for evolving topics): stable key like `architecture/auth-model`
- **content**:
  - **What**: One sentence -- what was done
  - **Why**: What motivated it (user request, bug, performance, etc.)
  - **Where**: Files or paths affected
  - **Learned**: Gotchas, edge cases, things that surprised you (omit if none)

Topic update rules:
- Different topics MUST NOT overwrite each other
- Same topic evolving -> use same `topic_key` (upsert)
- Unsure about key -> call `mem_suggest_topic_key` first
- Know exact ID to fix -> use `mem_update`

### WHEN TO SEARCH MEMORY

On any variation of "remember", "recall", "what did we do", "how did we solve", "recordar", "que hicimos", or references to past work:
1. Call `mem_context` -- checks recent session history (fast, cheap)
2. If not found, call `mem_search` with relevant keywords
3. If found, use `mem_get_observation` for full untruncated content

Also search PROACTIVELY when:
- Starting work on something that might have been done before
- User mentions a topic you have no context on
- User's FIRST message references the project, a feature, or a problem -- call `mem_search` with keywords from their message to check for prior work before responding

### SESSION CLOSE PROTOCOL (mandatory)

Before ending a session or saying "done" / "listo" / "that's it", call `mem_session_summary` with this structure:

```
## Goal
[What we were working on this session]

## Instructions
[User preferences or constraints discovered -- skip if none]

## Discoveries
- [Technical findings, gotchas, non-obvious learnings]

## Accomplished
- [Completed items with key details]

## Next Steps
- [What remains to be done -- for the next session]

## Relevant Files
- path/to/file -- [what it does or what changed]
```

This is NOT optional. If you skip this, the next session starts blind.

### AFTER COMPACTION

If you see a compaction message or "FIRST ACTION REQUIRED":
1. IMMEDIATELY call `mem_session_summary` with the compacted summary content -- this persists what was done before compaction
2. Call `mem_context` to recover additional context from previous sessions
3. Only THEN continue working

Do not skip step 1. Without it, everything done before compaction is lost from memory.
<!-- /team-ai-kit:engram-protocol -->

ENGRAM_PROTOCOL_EOF
}

update_instructions_engram_protocol() {
    # Usage: update_instructions_engram_protocol file_path [skip_engram_protocol]
    # Updates only the engram-protocol section in an existing instructions file.
    # If skip_engram_protocol is "true", removes existing markers instead of updating.
    # Outputs: "changed" or "unchanged"
    local file_path="$1"
    local skip_engram_protocol="${2:-false}"

    [[ -f "$file_path" ]] || { echo "unchanged"; return; }

    local existing
    existing=$(cat "$file_path")

    local start_marker='<!-- team-ai-kit:engram-protocol -->'
    local end_marker='<!-- /team-ai-kit:engram-protocol -->'

    if [[ "$skip_engram_protocol" == "true" ]]; then
        # Remove existing protocol section if present
        if echo "$existing" | grep -qF "$start_marker"; then
            local tmpfile
            tmpfile=$(mktemp)
            # shellcheck disable=SC2064  # intentional: expand $tmpfile now, not at signal time
            trap "rm -f '$tmpfile'" EXIT
            local in_section=false
            while IFS= read -r line || [[ -n "$line" ]]; do
                if [[ "$line" == *"$start_marker"* ]]; then
                    in_section=true
                elif [[ "$line" == *"$end_marker"* ]]; then
                    in_section=false
                elif [[ "$in_section" == false ]]; then
                    printf '%s\n' "$line" >> "$tmpfile"
                fi
            done <<< "$existing"
            local updated
            updated=$(cat "$tmpfile")
            rm -f "$tmpfile"
            trap - EXIT
            # Collapse 3+ consecutive blank lines to 2 (parity with PS1)
            updated=$(echo "$updated" | awk 'BEGIN{blank=0} /^[[:space:]]*$/{blank++; if(blank<=2) print; next} {blank=0; print}')
            if [[ "$updated" == "$existing" ]]; then
                echo "unchanged"
            else
                printf '%s\n' "$updated" > "$file_path"
                echo "changed"
            fi
        else
            echo "unchanged"
        fi
        return
    fi

    local new_section
    new_section=$(get_engram_protocol_content)
    # Trim leading/trailing whitespace
    new_section=$(echo "$new_section" | sed '/./,$!d' | sed -e :a -e '/^[[:space:]]*$/{ $d; N; ba; }')

    local updated
    if echo "$existing" | grep -qF "$start_marker"; then
        # Replace between markers using temp file to avoid escape issues
        local tmpfile
        tmpfile=$(mktemp)
        # shellcheck disable=SC2064  # intentional: expand $tmpfile now, not at signal time
        trap "rm -f '$tmpfile'" EXIT
        local in_section=false
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == *"$start_marker"* ]]; then
                printf '%s\n' "$new_section" >> "$tmpfile"
                in_section=true
            elif [[ "$line" == *"$end_marker"* ]]; then
                in_section=false
            elif [[ "$in_section" == false ]]; then
                printf '%s\n' "$line" >> "$tmpfile"
            fi
        done <<< "$existing"
        updated=$(cat "$tmpfile")
        rm -f "$tmpfile"
        trap - EXIT
    else
        updated=$(printf '%s\n\n%s\n' "$existing" "$new_section")
    fi

    if [[ "$updated" == "$existing" ]]; then
        echo "unchanged"
        return
    fi

    printf '%s\n' "$updated" > "$file_path"
    echo "changed"
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
        cursor)   dir_name="cursor" ;;
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

# -- Knowledge Repo ------------------------------------------------------------

initialize_knowledge_repo() {
    local target_dir="$1"
    local dirs=("skills/shared" "skills/roles" "rules")
    local created=()

    for dir in "${dirs[@]}"; do
        local full_path="$target_dir/$dir"
        if [[ ! -d "$full_path" ]]; then
            mkdir -p "$full_path"
            created+=("$dir")
        fi
    done

    local created_json
    created_json=$(printf '%s\n' "${created[@]}" | jq -R . | jq -sc '.')
    jq -n --argjson created "$created_json" --arg path "$target_dir" \
        '{created: $created, path: $path}'
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

# -- Uninstall -----------------------------------------------------------------

collect_uninstall_targets() {
    # Collects all files/dirs that team-ai-kit created in a project.
    # Usage: collect_uninstall_targets project_root
    # Outputs: one path per line (files and dirs to remove)
    local project_root="$1"
    local targets=()

    # 1. Project config
    local config_path="$project_root/.team-ai-kit.json"
    [[ -f "$config_path" ]] && targets+=("$config_path")

    # 2. Instructions file (detect IDE from project config)
    local ide
    ide=$(get_project_config_value "$project_root" "ide" 2>/dev/null) || true
    if [[ -n "$ide" ]]; then
        local instructions_path
        instructions_path=$(get_ide_instructions_path "$ide" "$project_root" 2>/dev/null) || true
        if [[ -n "$instructions_path" && -f "$instructions_path" ]]; then
            targets+=("$instructions_path")
        fi
    fi

    # 3. team-skills directory (global skills dir)
    local global_skills_dir="$project_root/team-skills"
    [[ -d "$global_skills_dir" ]] && targets+=("$global_skills_dir")

    # 4. IDE-specific project skills (e.g. .cursor/skills)
    if [[ -n "$ide" ]]; then
        local project_skills_dir
        project_skills_dir=$(get_ide_project_skills_directory "$ide" "$project_root" 2>/dev/null) || true
        if [[ -n "$project_skills_dir" && -d "$project_skills_dir" && "$project_skills_dir" != "$global_skills_dir" ]]; then
            targets+=("$project_skills_dir")
        fi
    fi

    # 5. Git hooks (only if they contain our marker)
    local marker='# [team-ai-kit] engram sync hook'
    local hooks_dir="$project_root/.git/hooks"
    for hook in pre-commit post-merge; do
        local hook_path="$hooks_dir/$hook"
        if [[ -f "$hook_path" ]] && grep -qF "$marker" "$hook_path" 2>/dev/null; then
            targets+=("hook:$hook_path")
        fi
    done

    # 6. .gitattributes (only if it contains our marker)
    local ga_marker='# [team-ai-kit] engram diff rules'
    local ga_path="$project_root/.gitattributes"
    if [[ -f "$ga_path" ]] && grep -qF "$ga_marker" "$ga_path" 2>/dev/null; then
        targets+=("gitattributes:$ga_path")
    fi

    printf '%s\n' "${targets[@]}"
}

remove_hook_marker_block() {
    # Removes the team-ai-kit block from a git hook file.
    # If the hook only contains our block + shebang, removes the file entirely.
    local hook_path="$1"
    local marker='# [team-ai-kit] engram sync hook'

    local content
    content=$(cat "$hook_path")

    # Build cleaned content: remove from marker to next "fi" (inclusive)
    local cleaned=""
    local in_block=false
    while IFS= read -r line; do
        if [[ "$line" == *"$marker"* ]]; then
            in_block=true
            continue
        fi
        if [[ "$in_block" == true ]]; then
            # Our hooks end with "fi"
            if [[ "$line" == "fi" ]]; then
                in_block=false
                continue
            fi
            continue
        fi
        cleaned+="$line"$'\n'
    done <<< "$content"

    # Strip leading/trailing blank lines
    cleaned=$(echo "$cleaned" | sed '/^$/N;/^\n$/d' | sed -e '/^$/d')

    # If only shebang remains (or empty), remove the file
    if [[ -z "$cleaned" || "$cleaned" == "#!/bin/sh" ]]; then
        rm -f "$hook_path"
    else
        printf '%s\n' "$cleaned" > "$hook_path"
    fi
}

uninstall_project() {
    # Removes all team-ai-kit artifacts from a project.
    # Usage: uninstall_project project_root
    # Outputs: JSON with removed items count
    local project_root="$1"
    local removed=0

    local targets
    targets=$(collect_uninstall_targets "$project_root")

    while IFS= read -r target; do
        [[ -z "$target" ]] && continue
        if [[ "$target" == hook:* ]]; then
            local hook_path="${target#hook:}"
            remove_hook_marker_block "$hook_path"
            removed=$((removed + 1))
        elif [[ "$target" == gitattributes:* ]]; then
            local ga_path="${target#gitattributes:}"
            remove_gitattributes_block "$(dirname "$ga_path")"
            removed=$((removed + 1))
        elif [[ -d "$target" ]]; then
            rm -rf "$target"
            removed=$((removed + 1))
        elif [[ -f "$target" ]]; then
            rm -f "$target"
            removed=$((removed + 1))
        fi
    done <<< "$targets"

    # Remove from global manifest
    local manifest_path
    manifest_path=$(get_skill_manifest_path)
    if [[ -f "$manifest_path" ]]; then
        rm -f "$manifest_path"
        removed=$((removed + 1))
    fi

    echo "{\"removed\":$removed}"
}
