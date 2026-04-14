#!/usr/bin/env bash
# E2E test for team-ai-kit bash CLI
# Intentionally NOT using set -e so we can capture failures

export PATH="/c/Users/Win11/scoop/shims:$PATH"
export HOME="/tmp/team-ai-kit-e2e-home-$$"
mkdir -p "$HOME"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="/tmp/team-ai-kit-e2e-target-$$"
PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

cleanup() {
    rm -rf "$TEST_DIR" "$HOME" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== E2E: team-ai-kit bash CLI ==="
echo "KIT_ROOT: $KIT_ROOT"
echo "TEST_DIR: $TEST_DIR"
echo "HOME:     $HOME"
echo ""

# -- Test 1: Help ---
echo "--- Test 1: help command ---"
output=$(bash "$KIT_ROOT/bin/team-ai-kit" help 2>&1) || true
if echo "$output" | grep -q "Team AI Kit"; then
    pass "help shows banner"
else
    fail "help doesn't show banner"
    echo "$output" | head -5
fi

# -- Test 2: Setup non-interactive ---
echo "--- Test 2: setup non-interactive ---"
output=$(bash "$KIT_ROOT/bin/team-ai-kit" setup --ide vscode --role frontend --target-dir "$TEST_DIR" --skip-prerequisites --skip-gentle-ai 2>&1) || true
echo "$output"
if echo "$output" | grep -q "Setup Complete"; then
    pass "setup completes"
else
    fail "setup didn't complete"
fi

# -- Test 3: Skills installed ---
echo "--- Test 3: skills installed ---"
if [ -d "$TEST_DIR/team-skills" ]; then
    skill_count=$(find "$TEST_DIR/team-skills" -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$skill_count" = "7" ]; then
        pass "7 skills installed"
    else
        fail "expected 7 skills, got $skill_count"
        find "$TEST_DIR/team-skills" -name '*.md' -type f 2>/dev/null
    fi
else
    fail "team-skills dir not found"
    ls -la "$TEST_DIR" 2>/dev/null || echo "TEST_DIR doesn't exist"
fi

# -- Test 4: Config saved ---
echo "--- Test 4: config saved ---"
if [ -f "$HOME/.team-ai-kit/config.json" ]; then
    pass "config.json exists"
    config_ide=$(jq -r '.ide' "$HOME/.team-ai-kit/config.json" 2>/dev/null) || config_ide="error"
    if [ "$config_ide" = "vscode" ]; then
        pass "config IDE = vscode"
    else
        fail "config IDE = '$config_ide'"
    fi
else
    fail "config.json not found"
    ls -la "$HOME/.team-ai-kit/" 2>/dev/null || echo "config dir missing"
fi

# -- Test 5: Manifest ---
echo "--- Test 5: manifest ---"
if [ -f "$HOME/.team-ai-kit/manifest.json" ]; then
    pass "manifest.json exists"
    mcount=$(jq '.files | length' "$HOME/.team-ai-kit/manifest.json" 2>/dev/null) || mcount="error"
    if [ "$mcount" = "7" ]; then
        pass "manifest tracks 7 files"
    else
        fail "manifest tracks $mcount files"
        jq '.files | keys' "$HOME/.team-ai-kit/manifest.json" 2>/dev/null || true
    fi
else
    fail "manifest.json not found"
fi

# -- Test 6: Modify + update ---
echo "--- Test 6: user modification preserved ---"
arch_skill="$TEST_DIR/team-skills/shared/architecture/SKILL.md"
if [ -f "$arch_skill" ]; then
    echo '# MY CUSTOM ARCHITECTURE RULES' > "$arch_skill"
    bash "$KIT_ROOT/bin/team-ai-kit" update --target-dir "$TEST_DIR" 2>&1 >/dev/null || true
    content=$(cat "$arch_skill")
    if echo "$content" | grep -q "MY CUSTOM"; then
        pass "user modification preserved"
    else
        fail "modification overwritten"
    fi
else
    fail "architecture skill not found at $arch_skill"
fi

# -- Test 7: Status ---
echo "--- Test 7: status ---"
output=$(bash "$KIT_ROOT/bin/team-ai-kit" status 2>&1) || true
if echo "$output" | grep -q "vscode"; then
    pass "status shows IDE"
else
    fail "status doesn't show IDE"
    echo "$output"
fi

# -- Summary ---
echo ""
echo "================================"
echo "  PASS: $PASS  FAIL: $FAIL"
echo "================================"
if [ "$FAIL" = "0" ]; then
    echo "  All tests passed!"
else
    echo "  Some tests failed."
fi
