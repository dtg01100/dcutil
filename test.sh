#!/usr/bin/env bash

# Basic test suite for dcutil
# Run with: ./test.sh

set -euo pipefail

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
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

test_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

test_skip() {
    echo -e "${YELLOW}⏭️  SKIP${NC}: $1"
    ((TESTS_RUN++))
}

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit="${3:-0}"

    echo -e "${BLUE}Running${NC}: $test_name"

    # Disable exit-on-error for this command so we can capture non-zero exits
    set +e
    eval "$test_cmd"
    local rc=$?
    set -e

    if [ $rc -eq "$expected_exit" ]; then
        test_pass "$test_name"
    else
        test_fail "$test_name (expected exit $expected_exit, got $rc)"
    fi
}

# Test: Basic help command
run_test "Help command" "\"$DCUTIL\" help >/dev/null"

# Test: Version command
run_test "Version command" "\"$DCUTIL\" version >/dev/null"

# Test: Invalid command
run_test "Invalid command" "\"$DCUTIL\" nonexistent-command >/dev/null" 1

# Test: Test command (our improvements test)
run_test "Test command" "\"$DCUTIL\" test >/dev/null"

# Test: Completion setup
run_test "Completion command" "\"$DCUTIL\" completion bash >/dev/null"

# Test: Status command (should work even without containers)
run_test "Status command" "\"$DCUTIL\" status >/dev/null"

# Test: List command
run_test "List command" "\"$DCUTIL\" list >/dev/null"

# Test: Podman status
run_test "Podman status" "\"$DCUTIL\" podman status >/dev/null"


# Test: Volumes help
run_test "Volumes help" "\"$DCUTIL\" volumes >/dev/null" 1

# Test: Compose help
run_test "Compose help" "\"$DCUTIL\" compose >/dev/null" 1

# Test: Features help
run_test "Features help" "\"$DCUTIL\" features >/dev/null" 1

# Test: Advanced help
run_test "Advanced help" "\"$DCUTIL\" advanced >/dev/null" 1

# Test: Integration help
run_test "Integration help" "\"$DCUTIL\" integration >/dev/null" 1

# Test: Merging help
run_test "Merging help" "\"$DCUTIL\" merging >/dev/null" 1

# Test: Userprobe help
run_test "Userprobe help" "\"$DCUTIL\" userprobe >/dev/null" 1

# Test: Hostrequirements help
run_test "Hostrequirements help" "\"$DCUTIL\" hostrequirements >/dev/null" 1

# Test: Shutdown help
run_test "Shutdown help" "\"$DCUTIL\" shutdown >/dev/null" 1

# Test: Schema help
run_test "Schema help" "\"$DCUTIL\" schema >/dev/null" 1

# Test syntax validation
run_test "Syntax validation" "bash -n \"$DCUTIL\""

# Test library syntax
run_test "Core library syntax" "bash -n \"$SCRIPT_DIR/lib/core.sh\""

# Test podman library syntax
run_test "Podman library syntax" "bash -n \"$SCRIPT_DIR/lib/podman.sh\""

# Test docker library syntax
run_test "Docker library syntax" "bash -n \"$SCRIPT_DIR/lib/docker.sh\""

# Test API library syntax
run_test "API library syntax" "bash -n \"$SCRIPT_DIR/lib/api_official_cli.sh\""

# Additional feature unit tests

# Test: parse_feature_spec - short format
run_test "parse_feature_spec short" "bash -c 'source \"$SCRIPT_DIR/lib/features.sh\"; parse_feature_spec \"node\" | grep -q \"^ghcr.io/devcontainers/features/node:latest$\"'"

# Test: parse_feature_spec - medium format
run_test "parse_feature_spec medium" "bash -c 'source \"$SCRIPT_DIR/lib/features.sh\"; parse_feature_spec \"devcontainers/features/node:18\" | grep -q \"^ghcr.io/devcontainers/features/node:18$\"'"

# Test: parse_feature_spec - full format
run_test "parse_feature_spec full" "bash -c 'source \"$SCRIPT_DIR/lib/features.sh\"; parse_feature_spec \"ghcr.io/devcontainers/features/node:18\" | grep -q \"^ghcr.io/devcontainers/features/node:18$\"'"

# Test: get_effective_feature_spec - normalize git numeric version
run_test "get_effective_feature_spec git numeric->latest" "bash -c 'source \"$SCRIPT_DIR/lib/features.sh\"; get_effective_feature_spec \"git:1\" \"{}\" | grep -q \"^ghcr.io/devcontainers/features/git:latest$\"'"

# Test: validate_feature_cache_dir
_run_validate_feature_cache_dir() {
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/src"
    echo "{}" > "$tmpdir/devcontainer-feature.json"
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$tmpdir/src/install.sh"
    chmod +x "$tmpdir/src/install.sh"
    source "$SCRIPT_DIR/lib/features.sh"
    validate_feature_cache_dir "$tmpdir"
}
run_test "validate_feature_cache_dir" "_run_validate_feature_cache_dir"

# Test: parse_features_config mapping
_run_parse_features_config_mapping() {
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/lib/core.sh"
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/lib/docker.sh"
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/lib/features.sh"
    PROJECT_DIR="$(cd .. >/dev/null && pwd)"
    export PROJECT_DIR
    parse_devcontainer_config
    parse_features_config >/dev/null
    printf "%s\n" "${FEATURES_IDS[*]}" | grep -q "ghcr.io/devcontainers/features/git"
}
run_test "parse_features_config mapping" "_run_parse_features_config_mapping"
# Test: resolve_feature_install_order
_run_resolve_feature_install_order() {
    tmpcache=$(mktemp -d)
    export FEATURES_CACHE_DIR="$tmpcache"
    mkdir -p "$tmpcache/ghcr.io_devcontainers_features_a_latest/src"
    printf '%s' '{"id":"a"}' > "$tmpcache/ghcr.io_devcontainers_features_a_latest/devcontainer-feature.json"
    printf 'ghcr.io/devcontainers/features/b:latest\n' > "$tmpcache/ghcr.io_devcontainers_features_a_latest/dependsOn.list"
    mkdir -p "$tmpcache/ghcr.io_devcontainers_features_b_latest/src"
    printf '%s' '{"id":"b"}' > "$tmpcache/ghcr.io_devcontainers_features_b_latest/devcontainer-feature.json"
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/lib/core.sh"
    source "$SCRIPT_DIR/lib/features.sh"
    resolve_feature_install_order "ghcr.io/devcontainers/features/a:latest" "ghcr.io/devcontainers/features/b:latest" | sed -n 1,2p | grep -q "ghcr.io/devcontainers/features/b:latest"
}
run_test "resolve_feature_install_order" "_run_resolve_feature_install_order"

# Test: Features install dry-run
run_test "Features install dry-run" "\"$DCUTIL\" features install --dry-run >/dev/null" 

# Test: install_feature host mode with mock cached script
run_test "install_feature host mock" "bash -c 'tmpcache=$(mktemp -d); export FEATURES_CACHE_DIR=$tmpcache; mkdir -p \"$tmpcache/ghcr.io_devcontainers_features_git_latest/src\"; echo \"{\\\"id\\\":\\\"git\\\",\\\"version\\\":\\\"1.3.4\\\"}\" > \"$tmpcache/ghcr.io_devcontainers_features_git_latest/devcontainer-feature.json\"; echo \"#!/usr/bin/env bash\nexit 0\" > \"$tmpcache/ghcr.io_devcontainers_features_git_latest/src/install.sh\"; chmod +x \"$tmpcache/ghcr.io_devcontainers_features_git_latest/src/install.sh\"; source \"$SCRIPT_DIR/lib/core.sh\"; source \"$SCRIPT_DIR/lib/features.sh\"; export FEATURES_FORCE_HOST_INSTALL=true; install_feature ghcr.io/devcontainers/features/git:latest'"

# Test: sanitize_features_json mapping of numeric keys
_run_sanitize_features_json_mapping() {
        tmpproj=$(mktemp -d)
        mkdir -p "$tmpproj/.devcontainer"
        cat > "$tmpproj/.devcontainer/devcontainer.json" <<JD
{
    "name": "tmpl",
    "features": {
        "1": {},
        "ghcr.io/devcontainers/features/2": {}
    }
}
JD
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/lib/core.sh"
        source "$SCRIPT_DIR/lib/template_integration.sh"
        fetch_available_features_official() { echo '[{"id":"git","registry":"ghcr.io/devcontainers/features"},{"id":"docker-in-docker","registry":"ghcr.io/devcontainers/features"}]'; }
        cd "$tmpproj"
        sanitize_features_json
        grep -q "ghcr.io/devcontainers/features/git" .devcontainer/devcontainer.json
}
run_test "sanitize_features_json mapping" "_run_sanitize_features_json_mapping"


# Test: New helper functions exist in security module
run_test "New helper functions syntax" "bash -c 'source \"$SCRIPT_DIR/lib/security.sh\"; declare -f copy_agent_config_files >/dev/null 2>&1 && declare -f copy_single_file >/dev/null 2>&1 && declare -f copy_dir_content >/dev/null 2>&1'"


# Test: Function can be called without error (when no valid agent is provided, returns 1)
    source "$SCRIPT_DIR/lib/security.sh"
    PROJECT_DIR="/tmp"
    export PROJECT_DIR
    local rc=$?
    [ $rc -ne 0 ]
}

# Interactive UI Tests using expect
# Test: Interactive menu functionality
if command -v expect >/dev/null 2>&1; then
    run_test "Interactive menu test" "cd \"$SCRIPT_DIR/../test-menu\" && expect \"$SCRIPT_DIR/../test_menu.expect\" >/dev/null 2>&1"

    run_test "Fast init interactive test" "cd \"$SCRIPT_DIR/../test-fast-init\" && rm -rf .devcontainer && expect \"$SCRIPT_DIR/../test_fast_init.expect\" >/dev/null 2>&1"

    run_test "Wizard basic interactive test" "cd \"$SCRIPT_DIR/../test-wizard-comprehensive\" && rm -rf .devcontainer && timeout 180 expect \"$SCRIPT_DIR/../test_wizard_comprehensive.expect\" >/dev/null 2>&1"

    run_test "Error condition test" "cd \"$SCRIPT_DIR/../test-error-conditions\" && mkdir -p .devcontainer && echo '{\"name\": \"existing\"}' > .devcontainer/devcontainer.json && expect \"$SCRIPT_DIR/../test_error_existing_config.expect\" >/dev/null 2>&1"
else
    test_skip "Interactive tests (expect not available)"
fi

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
