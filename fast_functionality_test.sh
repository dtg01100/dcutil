#!/bin/bash

# Fast dcutil Functionality Test Suite
# Tests core features quickly without long-running operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DCUTIL="$SCRIPT_DIR/dcutil-files/dcutil"

echo "⚡ FAST DCUTIL FUNCTIONALITY TEST SUITE"
echo "======================================"
echo ""

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

    if timeout 30 bash -c "$test_cmd" 2>/dev/null; then
        local exit_code=$?
        if [ $exit_code -eq "$expected_exit" ]; then
            test_pass "$test_name"
        else
            test_fail "$test_name (expected exit $expected_exit, got $exit_code)"
        fi
    else
        local exit_code=$?
        if [ $exit_code -eq "$expected_exit" ]; then
            test_pass "$test_name"
        else
            test_fail "$test_name (expected exit $expected_exit, got $exit_code)"
        fi
    fi
}

echo "🔍 CORE FUNCTIONALITY TESTS"
echo "==========================="

# Basic commands
run_test "dcutil help" "\"$DCUTIL\" help | grep -q 'Usage'" 0
run_test "dcutil version" "\"$DCUTIL\" version | grep -q 'v1'" 0
run_test "dcutil status" "\"$DCUTIL\" status | grep -q 'status\|Status'" 0
run_test "dcutil list" "\"$DCUTIL\" list | grep -q 'list\|List'" 0

# Error cases
run_test "dcutil invalid command" "\"$DCUTIL\" nonexistent 2>&1 | grep -q 'Unknown\|invalid'" 1

echo ""
echo "🏗️  INITIALIZATION TESTS"
echo "========================"

# Test init fast in different project types
run_test "test-ubuntu init fast" "cd test-ubuntu && rm -rf .devcontainer && \"$DCUTIL\" init fast 2>&1 | grep -q 'successfully'" 0
run_test "test-node init fast" "cd test-node && rm -rf .devcontainer && \"$DCUTIL\" init fast 2>&1 | grep -q 'successfully'" 0

echo ""
echo "📊 VALIDATION TESTS"
echo "==================="

# Schema validation
run_test "test-ubuntu schema validate" "cd test-ubuntu && \"$DCUTIL\" schema validate 2>&1 | grep -q 'valid\|Valid'" 0
run_test "test-node schema validate" "cd test-node && \"$DCUTIL\" schema validate 2>&1 | grep -q 'valid\|Valid'" 0

echo ""
echo "⚙️  SUBSYSTEM TESTS"
echo "==================="

# Features
run_test "features info" "\"$DCUTIL\" features info 2>&1 | grep -q 'info\|Info'" 0
run_test "features validate" "\"$DCUTIL\" features validate 2>&1 | grep -q 'validate\|Validate'" 0

# Advanced
run_test "advanced info" "\"$DCUTIL\" advanced info 2>&1 | grep -q 'info\|Info'" 0

# Integration
run_test "integration info" "\"$DCUTIL\" integration info 2>&1 | grep -q 'info\|Info'" 0

# Volumes
run_test "volumes list" "\"$DCUTIL\" volumes list 2>&1 | grep -q 'list\|List'" 0

# Compose
run_test "compose status" "\"$DCUTIL\" compose status 2>&1 | grep -q 'status\|Status'" 0

# Environment
run_test "environment info" "\"$DCUTIL\" environment info 2>&1 | grep -q 'info\|Info'" 0

# Podman
run_test "podman status" "\"$DCUTIL\" podman status 2>&1 | grep -q 'status\|Status'" 0

echo ""
echo "🔧 COMMAND STRUCTURE TESTS"
echo "=========================="

# Test command argument validation
run_test "run without args" "\"$DCUTIL\" run 2>&1 | grep -q 'requires\|Usage'" 1
run_test "volumes without args" "\"$DCUTIL\" volumes 2>&1 | grep -q 'Usage\|help'" 1
run_test "compose without args" "\"$DCUTIL\" compose 2>&1 | grep -q 'Usage\|help'" 1

echo ""
echo "📝 COMPLETION TESTS"
echo "==================="

run_test "bash completion" "\"$DCUTIL\" completion bash | grep -q 'function\|_dcutil'" 0
run_test "zsh completion" "\"$DCUTIL\" completion zsh | grep -q 'compdef\|_dcutil'" 0

echo ""
echo "🧪 LIBRARY INTEGRITY TESTS"
echo "=========================="

# Test library syntax
LIB_DIR="$SCRIPT_DIR/dcutil-files/lib"
if [ -d "$LIB_DIR" ]; then
    for lib_file in "$LIB_DIR"/*.sh; do
        if [ -f "$lib_file" ] && [ -r "$lib_file" ]; then
            lib_name=$(basename "$lib_file" .sh)
            run_test "$lib_name syntax" "bash -n \"$lib_file\"" 0
        fi
    done
fi

echo ""
echo "🚫 ERROR HANDLING TESTS"
echo "========================"

run_test "non-existent path" "\"$DCUTIL\" status /definitely/does/not/exist 2>&1 | grep -q 'exist\|not.*found'" 1
run_test "malformed JSON" "mkdir -p /tmp/test-malformed && cd /tmp/test-malformed && echo '{\"name\": \"test\", \"image\": }' > .devcontainer/devcontainer.json && \"$DCUTIL\" schema validate 2>&1 | grep -q 'error\|Error'" 1

echo ""
echo "=== FAST FUNCTIONALITY TEST RESULTS ==="
echo "Total tests: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"

success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))

echo "Success rate: ${success_rate}%"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL CORE FUNCTIONALITY TESTS PASSED!${NC}"
    echo -e "${BLUE}dcutil core features are working correctly${NC}"
    exit 0
else
    echo -e "${RED}💥 $TESTS_FAILED core functionality tests failed${NC}"
    echo -e "${YELLOW}Some core features may have issues${NC}"
    exit 1
fi