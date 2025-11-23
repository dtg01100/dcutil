#!/usr/bin/env bash

# Debug version of test_final_compliance.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCUTIL="$SCRIPT_DIR/dcutil"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

run_test() {
    local test_name="$1"
    local test_command="$2"

    ((TESTS_TOTAL++))
    log_test "$test_name"

    if eval "$test_command" >/dev/null 2>&1; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

echo "Debug test starting..."

# Test 1: Help system
echo "Running test 1..."
run_test "Main help system" "$DCUTIL help"
echo "Test 1 completed"

# Test 2: Command validation
echo "Running test 2..."
run_test "Command validation" "$DCUTIL invalid-command 2>&1 | grep -q 'Invalid command'"
echo "Test 2 completed"

echo "All tests completed. Total: $TESTS_TOTAL, Passed: $TESTS_PASSED, Failed: $TESTS_FAILED"