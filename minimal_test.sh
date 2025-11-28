#!/bin/bash

# Minimal dcutil Functionality Test
# Tests only the most essential features

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCUTIL="$SCRIPT_DIR/dcutil"

echo "🎯 MINIMAL DCUTIL FUNCTIONALITY TEST"
echo "==================================="
echo ""

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit="${3:-0}"

    echo -e "${BLUE}Testing${NC}: $test_name"
    ((TESTS_RUN++))

    if timeout 30 bash -c "$test_cmd"; then
        local exit_code=$?
        if [ $exit_code -eq "$expected_exit" ]; then
            test_pass "$test_name"
        else
            test_fail "$test_name (exit $exit_code)"
        fi
    else
        local exit_code=$?
        if [ $exit_code -eq "$expected_exit" ]; then
            test_pass "$test_name"
        else
            test_fail "$test_name (exit $exit_code)"
        fi
    fi
}

echo "📋 BASIC COMMANDS"
run_test "help" "\"$DCUTIL\" help | grep -q Usage" 0
run_test "version" "\"$DCUTIL\" version | grep -q v1" 0
run_test "status" "\"$DCUTIL\" status >/dev/null 2>&1" 0
run_test "list" "\"$DCUTIL\" list >/dev/null 2>&1" 0

echo ""
echo "🏗️  INIT TESTS"
# Skip init tests if test directories don't exist (CI environment)
if [ -d "$SCRIPT_DIR/test-ubuntu" ]; then
    run_test "init fast ubuntu" "cd test-ubuntu && rm -rf .devcontainer && \"$DCUTIL\" init fast 2>&1 | grep -q successfully" 0
else
    echo "⏭️  Skipping init tests (test directories not found - CI environment)"
fi

if [ -d "$SCRIPT_DIR/test-node" ]; then
    run_test "init fast node" "cd test-node && rm -rf .devcontainer && \"$DCUTIL\" init fast 2>&1 | grep -q successfully" 0
fi

echo ""
echo "📊 VALIDATION TESTS"
# Skip validation tests if test directories don't exist
if [ -d "$SCRIPT_DIR/test-ubuntu" ]; then
    run_test "ubuntu schema" "cd test-ubuntu && \"$DCUTIL\" schema validate 2>&1 | grep -q valid" 0
else
    echo "⏭️  Skipping validation tests (test directories not found - CI environment)"
fi

if [ -d "$SCRIPT_DIR/test-node" ]; then
    run_test "node schema" "cd test-node && \"$DCUTIL\" schema validate 2>&1 | grep -q valid" 0
fi

echo ""
echo "⚙️  SUBSYSTEM TESTS"
run_test "features info" "\"$DCUTIL\" features info 2>&1 | grep -q info" 0
run_test "volumes list" "\"$DCUTIL\" volumes list >/dev/null 2>&1" 0
run_test "compose status" "\"$DCUTIL\" compose status >/dev/null 2>&1" 1
run_test "podman status" "\"$DCUTIL\" podman status >/dev/null 2>&1" 0

echo ""
echo "🚫 ERROR TESTS"
run_test "invalid command" "\"$DCUTIL\" nonexistent 2>&1 | grep -q Unknown" 1
run_test "run no args" "\"$DCUTIL\" run 2>&1 | grep -q requires" 1

echo ""
echo "🧪 LIBRARY TESTS"
LIB_DIR="$SCRIPT_DIR/lib"
if [ -d "$LIB_DIR" ]; then
    for lib_file in "$LIB_DIR"/*.sh; do
        if [ -f "$lib_file" ]; then
            lib_name=$(basename "$lib_file" .sh)
            run_test "$lib_name syntax" "bash -n \"$lib_file\"" 0
        fi
    done
else
    echo "⚠️  Library directory not found at $LIB_DIR"
fi

echo ""
echo "=== MINIMAL TEST RESULTS ==="
echo "Tests run: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL ESSENTIAL TESTS PASSED!${NC}"
else
    echo -e "${RED}💥 $TESTS_FAILED tests failed${NC}"
fi