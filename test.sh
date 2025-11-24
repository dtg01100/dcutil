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

    if eval "$test_cmd"; then
        if [ $? -eq "$expected_exit" ]; then
            test_pass "$test_name"
        else
            test_fail "$test_name (expected exit $expected_exit, got $?)"
        fi
    else
        if [ $? -eq "$expected_exit" ]; then
            test_pass "$test_name"
        else
            test_fail "$test_name (expected exit $expected_exit, got $?)"
        fi
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

# Test: Agent help
run_test "Agent help" "\"$DCUTIL\" install-agent >/dev/null" 1

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