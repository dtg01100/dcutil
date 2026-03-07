#!/usr/bin/env bash

# Basic test suite for dcutil
# Run with: ./test.sh

set -euo pipefail

# Avoid interactive prompts during tests
export CI=true
export DCUTIL_QUIET=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCUTIL="$SCRIPT_DIR/dcutil"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_skip() {
    echo -e "${YELLOW}⏭️  SKIP${NC}: $1"
    TESTS_RUN=$((TESTS_RUN + 1))
}

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit="${3:-0}"

    echo -e "${BLUE}Running${NC}: $test_name"

    tmp_out=$(mktemp)
    tmp_err=$(mktemp)

    # Disable exit-on-error for this command so we can capture non-zero exits
    set +e
    # Only enable quiet mode for dcutil invocations to avoid masking other command outputs
    prev_dcquiet="${DCUTIL_QUIET:-}"
    if [[ "$test_cmd" == *"$DCUTIL"* ]]; then
        DCUTIL_QUIET=1
        export DCUTIL_QUIET
    fi
    # Use < /dev/null to prevent hangs if a command ignores DCUTIL_QUIET
    eval "$test_cmd" < /dev/null >"$tmp_out" 2>"$tmp_err"
    local rc=$?
    # restore previous DCUTIL_QUIET
    if [ -n "$prev_dcquiet" ]; then
        export DCUTIL_QUIET="$prev_dcquiet"
    else
        unset DCUTIL_QUIET 2>/dev/null || true
    fi
    set -e

    if [ $rc -eq "$expected_exit" ]; then
        test_pass "$test_name"
        rm -f "$tmp_out" "$tmp_err"
    else
        echo "---- BEGIN OUTPUT: $test_name stdout ----"
        sed -n '1,200p' "$tmp_out" || true
        echo "---- END OUTPUT: $test_name stdout ----"
        echo "---- BEGIN OUTPUT: $test_name stderr ----"
        sed -n '1,200p' "$tmp_err" || true
        echo "---- END OUTPUT: $test_name stderr ----"
        test_fail "$test_name (expected exit $expected_exit, got $rc)"
        rm -f "$tmp_out" "$tmp_err"
    fi
}

# Test: Basic help command
run_test "Help command" "$DCUTIL --quiet help" 0

# Test: Version command
run_test "Version command" "$DCUTIL --quiet version" 0

# Test: Invalid command
run_test "Invalid command" "$DCUTIL --quiet nonexistent-command" 1

# Test: Test command (our improvements test)
run_test "Test command" "$DCUTIL --quiet test" 0

# Test: Completion setup
run_test "Completion command" "$DCUTIL --quiet completion bash" 0

# Test: Status command (should work even without containers)
run_test "Status command" "$DCUTIL --quiet status" 0

# Test: List command
run_test "List command" "$DCUTIL --quiet list" 0

# Test: Podman status
run_test "Podman status" "$DCUTIL --quiet podman status" 0

# Test: Agent help
run_test "Agent help" "$DCUTIL --quiet install-agent" 1

# Test: Volumes help
run_test "Volumes help" "$DCUTIL --quiet volumes" 1

# Test: Compose help
run_test "Compose help" "$DCUTIL --quiet compose" 1

# Test: Features help
run_test "Features help" "$DCUTIL --quiet features" 1

# Test: Advanced help
run_test "Advanced help" "$DCUTIL --quiet advanced" 0

# Test: Integration help
run_test "Integration help" "$DCUTIL --quiet integration" 0

# Test: Merging help
run_test "Merging help" "$DCUTIL --quiet merging" 0

# Test: Userprobe help
run_test "Userprobe help" "$DCUTIL --quiet userprobe" 0

# Test: Hostrequirements help
run_test "Hostrequirements help" "$DCUTIL --quiet hostrequirements" 1

# Test: Shutdown help
run_test "Shutdown help" "$DCUTIL --quiet shutdown" 1

# Test: Schema help
run_test "Schema help" "$DCUTIL --quiet schema" 1

# Test syntax validation
run_test "Syntax validation" "bash -n \"$DCUTIL\""

# Test library syntax
run_test "Core library syntax" "bash -n \"$SCRIPT_DIR/lib/core.sh\""
run_test "Podman library syntax" "bash -n \"$SCRIPT_DIR/lib/podman.sh\""
run_test "Docker library syntax" "bash -n \"$SCRIPT_DIR/lib/docker.sh\""
run_test "API library syntax" "bash -n \"$SCRIPT_DIR/lib/api_official_cli.sh\""

# Feature parsing tests using a temporary script for better isolation
run_feature_tests() {
    local tscript=$(mktemp)
    cat > "$tscript" <<EOF
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/features.sh"

echo "Running parse_feature_spec short"
parse_feature_spec node | grep -q "^ghcr.io/devcontainers/features/node:latest$" || exit 1

echo "Running parse_feature_spec medium"
parse_feature_spec devcontainers/features/node:18 | grep -q "^ghcr.io/devcontainers/features/node:18$" || exit 1

echo "Running get_effective_feature_spec git numeric->latest"
get_effective_feature_spec git:1 '{}' | grep -q "^ghcr.io/devcontainers/features/git:latest$" || exit 1

echo "Running validate_feature_cache_dir"
tmpdir=\$(mktemp -d)
mkdir -p "\$tmpdir/src"
echo '{}' > "\$tmpdir/devcontainer-feature.json"
echo '#!/usr/bin/env bash' > "\$tmpdir/src/install.sh"
chmod +x "\$tmpdir/src/install.sh"
validate_feature_cache_dir "\$tmpdir" || exit 1
EOF
    run_test "Feature logic suite" "bash $tscript"
    rm -f "$tscript"
}

run_feature_tests

# Test: New helper functions syntax
run_test "New helper functions syntax" "bash -c \"source $SCRIPT_DIR/lib/core.sh; source $SCRIPT_DIR/lib/security.sh; declare -f copy_agent_config_files && declare -f copy_single_file && declare -f copy_dir_content\""

# Test: attempt_auto_install_prerequisites function exists
run_test "attempt_auto_install_prerequisites function exists" "bash -c \"source $SCRIPT_DIR/lib/core.sh; source $SCRIPT_DIR/lib/security.sh; declare -f attempt_auto_install_prerequisites\""

# Test: Function can be called without error
run_test "attempt_auto_install_prerequisites with invalid agent" "bash -c \"source $SCRIPT_DIR/lib/core.sh; source $SCRIPT_DIR/lib/security.sh; PROJECT_DIR='/tmp'; export PROJECT_DIR; attempt_auto_install_prerequisites 'invalid_agent'\"" 1

# Summary
echo
echo "=== Test Results ==="
echo "Total tests: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Skipped: $((TESTS_RUN - TESTS_PASSED - TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}💥 $TESTS_FAILED tests failed${NC}"
    exit 1
fi
