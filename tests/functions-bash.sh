#!/usr/bin/env bash
# Unit tests for lib/functions.sh -- mirrors PS1 Pester tests
# Ad-hoc framework matching e2e-bash.sh style

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the functions under test
# shellcheck source=../lib/functions.sh
source "$KIT_ROOT/lib/functions.sh"
set +e  # Undo set -e inherited from functions.sh -- tests must not abort on failure

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1 -- got: '$2'"; FAIL=$((FAIL + 1)); }

assert_eq() {
    local test_name="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$test_name"
    else
        fail "$test_name (expected '$expected')" "$actual"
    fi
}

assert_contains() {
    local test_name="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF -- "$needle"; then
        pass "$test_name"
    else
        fail "$test_name (missing '$needle')" ""
    fi
}

assert_not_contains() {
    local test_name="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF -- "$needle"; then
        fail "$test_name (should not contain '$needle')" ""
    else
        pass "$test_name"
    fi
}

assert_exit_success() {
    local test_name="$1"
    shift
    if "$@" &>/dev/null; then
        pass "$test_name"
    else
        fail "$test_name (exit code $?)" ""
    fi
}

assert_exit_fail() {
    local test_name="$1"
    shift
    if "$@" &>/dev/null; then
        fail "$test_name (expected failure, got success)" ""
    else
        pass "$test_name"
    fi
}

echo "=== Unit Tests: lib/functions.sh ==="
echo ""

# =============================================================================
# _sanitize_project_name
# =============================================================================
echo "--- _sanitize_project_name ---"

assert_eq "keeps safe characters unchanged" \
    "my-project_v2.0" "$(_sanitize_project_name "my-project_v2.0")"

assert_eq "strips shell metacharacters" \
    "projrm-rfecho" "$(_sanitize_project_name 'proj"; rm -rf /; echo "')"

assert_eq "strips spaces" \
    "myproject" "$(_sanitize_project_name "my project")"

assert_eq "strips dollar signs and backticks" \
    "projHOMEcmd" "$(_sanitize_project_name 'proj$HOME`cmd`')"

assert_eq "returns empty for all-unsafe input" \
    "rm-rf" "$(_sanitize_project_name '$(rm -rf /)')"

assert_eq "handles empty string" \
    "" "$(_sanitize_project_name "")"

echo ""

# =============================================================================
# get_gentle_ai_agent_id
# =============================================================================
echo "--- get_gentle_ai_agent_id ---"

assert_eq "maps vscode to vscode-copilot" \
    "vscode-copilot" "$(get_gentle_ai_agent_id "vscode")"

assert_eq "maps opencode to opencode" \
    "opencode" "$(get_gentle_ai_agent_id "opencode")"

assert_eq "maps cursor to cursor" \
    "cursor" "$(get_gentle_ai_agent_id "cursor")"

# intellij should return empty + fail exit
result=$(get_gentle_ai_agent_id "intellij" 2>/dev/null) || true
assert_eq "returns empty for intellij" "" "$result"

result=$(get_gentle_ai_agent_id "vim" 2>/dev/null) || true
assert_eq "returns empty for unknown IDE" "" "$result"

# case-insensitive
assert_eq "case-insensitive: VSCode" \
    "vscode-copilot" "$(get_gentle_ai_agent_id "VSCode")"

assert_eq "case-insensitive: OPENCODE" \
    "opencode" "$(get_gentle_ai_agent_id "OPENCODE")"

assert_eq "case-insensitive: CURSOR" \
    "cursor" "$(get_gentle_ai_agent_id "CURSOR")"

echo ""

# =============================================================================
# test_gentle_ai_supports_ide
# =============================================================================
echo "--- test_gentle_ai_supports_ide ---"

assert_exit_success "vscode is supported" test_gentle_ai_supports_ide "vscode"
assert_exit_success "opencode is supported" test_gentle_ai_supports_ide "opencode"
assert_exit_success "cursor is supported" test_gentle_ai_supports_ide "cursor"
assert_exit_fail "intellij is not supported" test_gentle_ai_supports_ide "intellij"
assert_exit_fail "vim is not supported" test_gentle_ai_supports_ide "vim"

echo ""

# =============================================================================
# new_copilot_instructions
# =============================================================================
echo "--- new_copilot_instructions ---"

output=$(new_copilot_instructions "frontend")
assert_contains "includes role in header" "$output" "frontend"

output=$(new_copilot_instructions "backend-node")
assert_contains "includes Team Conventions section" "$output" "Team Conventions"

output=$(new_copilot_instructions "frontend")
assert_contains "includes engram protocol start marker" "$output" "<!-- team-ai-kit:engram-protocol -->"
assert_contains "includes engram protocol end marker" "$output" "<!-- /team-ai-kit:engram-protocol -->"
assert_contains "includes mem_save in protocol" "$output" "mem_save"
assert_contains "includes mem_context in protocol" "$output" "mem_context"
assert_contains "includes mem_session_summary in protocol" "$output" "mem_session_summary"
assert_contains "includes AFTER COMPACTION" "$output" "AFTER COMPACTION"

# engram-protocol before team-rules
output=$(new_copilot_instructions "frontend" "" "## Team Rules")
engram_pos=$(echo "$output" | grep -n "team-ai-kit:engram-protocol" | head -1 | cut -d: -f1)
team_pos=$(echo "$output" | grep -n "team-ai-kit:team-rules" | head -1 | cut -d: -f1)
if [[ -n "$engram_pos" && -n "$team_pos" && "$engram_pos" -lt "$team_pos" ]]; then
    pass "engram-protocol placed before team-rules"
else
    fail "engram-protocol should be before team-rules" "engram=$engram_pos team=$team_pos"
fi

# pack rules
output=$(new_copilot_instructions "frontend" "## My Custom Rules
Rule 1: Do this" "")
assert_contains "appends pack rules" "$output" "My Custom Rules"
assert_contains "pack rules content" "$output" "Rule 1"

# no pack rules
output=$(new_copilot_instructions "devops")
assert_contains "works without pack rules" "$output" "devops"

# team rules wrapped in markers
output=$(new_copilot_instructions "frontend" "" "## Architecture
Use hexagonal architecture")
assert_contains "team-rules start marker" "$output" "<!-- team-ai-kit:team-rules -->"
assert_contains "team-rules end marker" "$output" "<!-- /team-ai-kit:team-rules -->"
assert_contains "team rules content" "$output" "hexagonal architecture"

# both pack and team rules
output=$(new_copilot_instructions "frontend" "## Pack Rules
Rule 1" "## Team Rules
Rule 2")
assert_contains "includes pack rules" "$output" "Pack Rules"
assert_contains "includes team rules" "$output" "Team Rules"
assert_contains "includes team-rules marker" "$output" "<!-- team-ai-kit:team-rules -->"

# no team-rules marker when empty
output=$(new_copilot_instructions "frontend")
assert_not_contains "no team-rules markers when empty" "$output" "team-ai-kit:team-rules"

# skip_engram_protocol = true
output=$(new_copilot_instructions "frontend" "" "" "true")
assert_not_contains "skip: no engram-protocol marker" "$output" "team-ai-kit:engram-protocol"
assert_not_contains "skip: no mem_save" "$output" "mem_save"
assert_contains "skip: still has Team Conventions" "$output" "Team Conventions"

# skip_engram_protocol = false (default)
output=$(new_copilot_instructions "frontend" "" "" "false")
assert_contains "no-skip: includes engram-protocol" "$output" "team-ai-kit:engram-protocol"
assert_contains "no-skip: includes mem_save" "$output" "mem_save"

# skip engram but keep team rules
output=$(new_copilot_instructions "frontend" "" "## Team Rules" "true")
assert_not_contains "skip+team: no engram marker" "$output" "team-ai-kit:engram-protocol"
assert_contains "skip+team: has team-rules marker" "$output" "<!-- team-ai-kit:team-rules -->"
assert_contains "skip+team: has team rules content" "$output" "Team Rules"

# Team Conventions should NOT have extra engram lines (fix #6 parity)
output=$(new_copilot_instructions "frontend")
assert_not_contains "no 'Use engram' in conventions" "$output" "Use engram to save"
assert_not_contains "no 'Search engram' in conventions" "$output" "Search engram before"

echo ""

# =============================================================================
# update_instructions_engram_protocol
# =============================================================================
echo "--- update_instructions_engram_protocol ---"

# nonexistent file
result=$(update_instructions_engram_protocol "/tmp/nonexistent-$$.md")
assert_eq "returns unchanged for nonexistent file" "unchanged" "$result"

# appends protocol when no markers
tmpfile=$(mktemp)
echo "# Existing content" > "$tmpfile"
result=$(update_instructions_engram_protocol "$tmpfile")
assert_eq "appends: returns changed" "changed" "$result"
content=$(cat "$tmpfile")
assert_contains "appends: has start marker" "$content" "<!-- team-ai-kit:engram-protocol -->"
assert_contains "appends: has mem_save" "$content" "mem_save"
assert_contains "appends: has end marker" "$content" "<!-- /team-ai-kit:engram-protocol -->"
rm -f "$tmpfile"

# replaces content between existing markers
tmpfile=$(mktemp)
cat > "$tmpfile" <<'TESTEOF'
# Header
<!-- team-ai-kit:engram-protocol -->
# Old Protocol
<!-- /team-ai-kit:engram-protocol -->
# Footer
TESTEOF
result=$(update_instructions_engram_protocol "$tmpfile")
assert_eq "replaces: returns changed" "changed" "$result"
content=$(cat "$tmpfile")
assert_contains "replaces: has mem_save" "$content" "mem_save"
assert_not_contains "replaces: no old protocol" "$content" "Old Protocol"
assert_contains "replaces: preserves header" "$content" "# Header"
assert_contains "replaces: preserves footer" "$content" "# Footer"
rm -f "$tmpfile"

# returns unchanged when content identical
tmpfile=$(mktemp)
protocol=$(get_engram_protocol_content)
printf '# Header\n\n%s\n' "$protocol" > "$tmpfile"
result=$(update_instructions_engram_protocol "$tmpfile")
assert_eq "unchanged when identical" "unchanged" "$result"
rm -f "$tmpfile"

# skip: removes existing protocol
tmpfile=$(mktemp)
cat > "$tmpfile" <<'TESTEOF'
# Header
<!-- team-ai-kit:engram-protocol -->
## Old Protocol
<!-- /team-ai-kit:engram-protocol -->
# Footer
TESTEOF
result=$(update_instructions_engram_protocol "$tmpfile" "true")
assert_eq "skip-remove: returns changed" "changed" "$result"
content=$(cat "$tmpfile")
assert_not_contains "skip-remove: no engram marker" "$content" "engram-protocol"
assert_contains "skip-remove: preserves header" "$content" "# Header"
assert_contains "skip-remove: preserves footer" "$content" "# Footer"
rm -f "$tmpfile"

# skip: returns unchanged when no markers exist
tmpfile=$(mktemp)
echo "# No protocol here" > "$tmpfile"
result=$(update_instructions_engram_protocol "$tmpfile" "true")
assert_eq "skip-noop: returns unchanged" "unchanged" "$result"
rm -f "$tmpfile"

echo ""

# =============================================================================
# ensure_gitattributes / remove_gitattributes_block
# =============================================================================
echo "--- ensure_gitattributes ---"

# Test: creates .gitattributes when it doesn't exist
ga_tmpdir=$(mktemp -d)
ga_json=$(ensure_gitattributes "$ga_tmpdir")
ga_created=$(echo "$ga_json" | jq -r '.created')
assert_eq "creates .gitattributes when absent" "true" "$ga_created"
assert_contains "file has marker" "$(cat "$ga_tmpdir/.gitattributes")" "# [team-ai-kit] engram diff rules"
assert_contains "file has linguist-generated" "$(cat "$ga_tmpdir/.gitattributes")" "linguist-generated=true"
assert_contains "file has -diff" "$(cat "$ga_tmpdir/.gitattributes")" ".engram/** -diff"
rm -rf "$ga_tmpdir"

# Test: appends to existing .gitattributes
ga_tmpdir=$(mktemp -d)
echo "*.pdf binary" > "$ga_tmpdir/.gitattributes"
ga_json=$(ensure_gitattributes "$ga_tmpdir")
ga_updated=$(echo "$ga_json" | jq -r '.updated')
assert_eq "appends to existing .gitattributes" "true" "$ga_updated"
assert_contains "preserves existing content" "$(cat "$ga_tmpdir/.gitattributes")" "*.pdf binary"
assert_contains "adds marker" "$(cat "$ga_tmpdir/.gitattributes")" "# [team-ai-kit] engram diff rules"
rm -rf "$ga_tmpdir"

# Test: idempotent -- no-op when marker present
ga_tmpdir=$(mktemp -d)
printf '# [team-ai-kit] engram diff rules\n.engram/** linguist-generated=true\n.engram/** -diff\n' > "$ga_tmpdir/.gitattributes"
ga_json=$(ensure_gitattributes "$ga_tmpdir")
ga_created=$(echo "$ga_json" | jq -r '.created')
ga_updated=$(echo "$ga_json" | jq -r '.updated')
assert_eq "idempotent: created=false" "false" "$ga_created"
assert_eq "idempotent: updated=false" "false" "$ga_updated"
rm -rf "$ga_tmpdir"

echo "--- remove_gitattributes_block ---"

# Test: removes our lines, keeps others
ga_tmpdir=$(mktemp -d)
printf '*.pdf binary\n\n# [team-ai-kit] engram diff rules\n.engram/** linguist-generated=true\n.engram/** -diff\n' > "$ga_tmpdir/.gitattributes"
remove_gitattributes_block "$ga_tmpdir"
assert_contains "keeps other rules" "$(cat "$ga_tmpdir/.gitattributes")" "*.pdf binary"
assert_not_contains "removes marker" "$(cat "$ga_tmpdir/.gitattributes")" "team-ai-kit"
rm -rf "$ga_tmpdir"

# Test: deletes file when only our lines remain
ga_tmpdir=$(mktemp -d)
printf '# [team-ai-kit] engram diff rules\n.engram/** linguist-generated=true\n.engram/** -diff\n' > "$ga_tmpdir/.gitattributes"
remove_gitattributes_block "$ga_tmpdir"
if [[ ! -f "$ga_tmpdir/.gitattributes" ]]; then
    pass "deletes file when only our lines"
else
    fail "should delete file when only our lines" "file still exists"
fi
rm -rf "$ga_tmpdir"

# Test: no-op when no file
ga_tmpdir=$(mktemp -d)
remove_gitattributes_block "$ga_tmpdir"
pass "no-op when .gitattributes absent"
rm -rf "$ga_tmpdir"

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "================================"
echo "  PASS: $PASS  FAIL: $FAIL"
echo "================================"
if [[ "$FAIL" == "0" ]]; then
    echo "  All tests passed!"
    exit 0
else
    echo "  Some tests failed."
    exit 1
fi
