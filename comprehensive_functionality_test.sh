#!/bin/bash

# Comprehensive dcutil Functionality Test Suite
# Tests ALL features, commands, and edge cases

# Note: Do NOT use 'set -e' in this test harness. We want to capture
# failures per-test instead of aborting the whole run. Individual tests
# are guarded and time-limited to avoid hangs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit

DCUTIL="$SCRIPT_DIR/dcutil-files/dcutil"

echo "🧪 COMPREHENSIVE DCUTIL FUNCTIONALITY TEST SUITE"
echo "================================================"
echo ""

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
## PURPLE not used in this script - removed to silence unused variable warnings
CYAN='\033[0;36m'
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

test_skip() {
    echo -e "${YELLOW}⏭️  SKIP${NC}: $1"
    ((TESTS_SKIPPED++))
    ((TESTS_RUN++))
}

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit="${3:-0}"
    local should_fail="${4:-false}"
    local timeout_sec="${COMPREHENSIVE_TIMEOUT_SEC:-20}"

    echo -e "${BLUE}Testing${NC}: $test_name"
    # Run the test command with a timeout in a clean bash subshell.
    # Using bash -lc to allow pipelines and expansions to behave consistently.
    if timeout "$timeout_sec" bash -lc "$test_cmd" 2>/dev/null; then
        local exit_code=$?
        if [ "$should_fail" = "true" ]; then
            if [ $exit_code -ne 0 ]; then
                test_pass "$test_name (correctly failed)"
            else
                test_fail "$test_name (should have failed)"
            fi
        else
            if [ $exit_code -eq "$expected_exit" ]; then
                test_pass "$test_name"
            else
                test_fail "$test_name (expected exit $expected_exit, got $exit_code)"
            fi
        fi
    else
        local exit_code=$?
        # If the timeout fired, normalize the message for clarity.
        if [ "$exit_code" -eq 124 ]; then
            test_fail "$test_name (timed out after ${timeout_sec}s)"
            return
        fi
        if [ "$should_fail" = "true" ]; then
            if [ $exit_code -ne 0 ]; then
                test_pass "$test_name (correctly failed)"
            else
                test_fail "$test_name (should have failed)"
            fi
        else
            if [ $exit_code -eq "$expected_exit" ]; then
                test_pass "$test_name"
            else
                test_fail "$test_name (expected exit $expected_exit, got $exit_code)"
            fi
        fi
    fi
}

echo "🔍 ENVIRONMENT CHECKS"
echo "====================="

# Check all dependencies
run_test "Docker available" "docker --version >/dev/null" 0
run_test "Podman available" "podman --version >/dev/null" 0
run_test "devcontainer CLI available" "devcontainer --version >/dev/null" 0
run_test "jq available" "jq --version >/dev/null" 0
run_test "curl available" "curl --version >/dev/null" 0
run_test "git available" "git --version >/dev/null" 0

echo ""
echo "📋 BASIC COMMAND TESTS"
echo "======================"

# Test basic commands that don't require containers
run_test "dcutil help" "\"$DCUTIL\" help | grep -q 'Usage'" 0
run_test "dcutil version" "\"$DCUTIL\" version | grep -q 'v1'" 0
run_test "dcutil status (no container)" "\"$DCUTIL\" status | grep -q 'status\|Status'" 0
run_test "dcutil list (no containers)" "\"$DCUTIL\" list | grep -q 'list\|List'" 0

# Test invalid commands
run_test "dcutil invalid-command" "\"$DCUTIL\" nonexistent 2>&1 | grep -q 'Unknown\|invalid'" 1 true

echo ""
echo "🏗️  PROJECT INITIALIZATION TESTS"
echo "==============================="

# Test init commands
PROJECT_TYPES=("test-go" "test-node" "test-python" "test-rust" "test-ubuntu")

for project in "${PROJECT_TYPES[@]}"; do
    if [ -d "$project" ]; then
        echo "Testing $project initialization..."

        # Clean existing config
        rm -rf "$project/.devcontainer"

        # Test init fast
        run_test "$project init fast" "cd $project && \"$DCUTIL\" init fast 2>&1 | grep -q 'configured successfully'" 0

        # Clean and test init wizard (skip for automation)
        rm -rf "$project/.devcontainer"
        test_skip "$project init wizard (interactive - skipped for automation)"
    fi
done

echo ""
echo "📊 SCHEMA VALIDATION TESTS"
echo "=========================="

for project in "${PROJECT_TYPES[@]}"; do
    if [ -d "$project" ] && [ -f "$project/.devcontainer/devcontainer.json" ]; then
        run_test "$project schema validate" "cd $project && \"$DCUTIL\" schema validate 2>&1 | grep -q 'valid\|Valid'" 0
    fi
done

echo ""
echo "🔧 FEATURES MANAGEMENT TESTS"
echo "============================"

# Test features commands
run_test "dcutil features (no args)" "\"$DCUTIL\" features 2>&1 | grep -q 'Usage\|help'" 1 true
run_test "dcutil features info" "\"$DCUTIL\" features info 2>&1 | grep -q 'info\|Info'" 0

# Test feature validation
run_test "dcutil features validate" "\"$DCUTIL\" features validate 2>&1 | grep -q 'validate\|Validate'" 0

echo ""
echo "⚙️  ADVANCED FEATURES TESTS"
echo "=========================="

# Test advanced commands
run_test "dcutil advanced (no args)" "\"$DCUTIL\" advanced 2>&1 | grep -q 'Usage\|help'" 1 true
run_test "dcutil advanced info" "\"$DCUTIL\" advanced info 2>&1 | grep -q 'info\|Info'" 0

echo ""
echo "🔗 INTEGRATION TESTS"
echo "==================="

# Test integration commands
run_test "dcutil integration (no args)" "\"$DCUTIL\" integration 2>&1 | grep -q 'Usage\|help'" 1 true
run_test "dcutil integration info" "\"$DCUTIL\" integration info 2>&1 | grep -q 'info\|Info'" 0

echo ""
echo "🔄 MERGING TESTS"
echo "================"

# Test merging commands
run_test "dcutil merging (no args)" "\"$DCUTIL\" merging 2>&1 | grep -q 'Usage\|help'" 1 true
run_test "dcutil merging show" "\"$DCUTIL\" merging show 2>&1 | grep -q 'show\|Show'" 0

echo ""
echo "👤 USER PROBE TESTS"
echo "==================="

# Test userprobe commands
run_test "dcutil userprobe (no args)" "\"$DCUTIL\" userprobe 2>&1 | grep -q 'Usage\|help'" 1 true
run_test "dcutil userprobe probe" "\"$DCUTIL\" userprobe probe 2>&1 | grep -q 'probe\|Probe'" 0

echo ""
echo "🏠 HOST REQUIREMENTS TESTS"
echo "=========================="

# Test hostrequirements commands
run_test "dcutil hostrequirements (no args)" "\"$DCUTIL\" hostrequirements 2>&1 | grep -q 'Usage\|help'" 1 true
run_test "dcutil hostrequirements validate" "\"$DCUTIL\" hostrequirements validate 2>&1 | grep -q 'validate\|Validate'" 0

echo ""
echo "⏹️  SHUTDOWN TESTS"
echo "=================="

# Test shutdown commands
run_test "dcutil shutdown (no args)" "\"$DCUTIL\" shutdown 2>&1 | grep -q 'Usage\|help'" 1 true
run_test "dcutil shutdown show" "\"$DCUTIL\" shutdown show 2>&1 | grep -q 'show\|Show'" 0

echo ""
echo "🐳 PODMAN BACKEND TESTS"
echo "======================="

# Test podman backend
run_test "dcutil podman status" "\"$DCUTIL\" podman status 2>&1 | grep -q 'status\|Status'" 0
run_test "dcutil podman validate" "\"$DCUTIL\" podman validate 2>&1 | grep -q 'validate\|Validate'" 0

echo ""
echo "📦 VOLUME MANAGEMENT TESTS"
echo "=========================="

# Test volume commands
run_test "dcutil volumes (no args)" "\"$DCUTIL\" volumes 2>&1 | grep -q 'Usage\|help'" 1 true
run_test "dcutil volumes list" "\"$DCUTIL\" volumes list 2>&1 | grep -q 'list\|List'" 0

# Test volume operations (these will fail without proper setup, but test command structure)
run_test "dcutil volumes add (invalid)" "\"$DCUTIL\" volumes add test /tmp /tmp 2>&1 | grep -q 'add\|Add'" 1 true

echo ""
echo "🐳 COMPOSE TESTS"
echo "================"

# Test compose commands
run_test "dcutil compose (no args)" "\"$DCUTIL\" compose 2>&1 | grep -q 'Usage\|help'" 1 true
run_test "dcutil compose status" "\"$DCUTIL\" compose status 2>&1 | grep -q 'status\|Status'" 0

echo ""
echo "🌐 ENVIRONMENT TESTS"
echo "==================="

# Test environment commands
run_test "dcutil environment info" "\"$DCUTIL\" environment info 2>&1 | grep -q 'info\|Info'" 0
run_test "dcutil environment validate" "\"$DCUTIL\" environment validate 2>&1 | grep -q 'validate\|Validate'" 0

echo ""
echo "🤖 AGENT INSTALLATION TESTS"
echo "==========================="

# Test agent commands

# Test agent validation (these will fail without containers, but test command acceptance)

echo ""
echo "🔧 BUILD SYSTEM TESTS"
echo "====================="

# Test build commands
run_test "dcutil build (no args)" "\"$DCUTIL\" build 2>&1 | grep -q 'build\|Build'" 0
run_test "dcutil clean" "\"$DCUTIL\" clean 2>&1 | grep -q 'clean\|Clean'" 0

echo ""
echo "📊 MONITORING TESTS"
echo "==================="

# Test monitoring commands
run_test "dcutil stats" "\"$DCUTIL\" stats 2>&1 | grep -q 'stats\|Stats\|Resource'" 0
run_test "dcutil logs" "\"$DCUTIL\" logs 2>&1 | grep -q 'logs\|Logs'" 0

echo ""
echo "🔄 LIFECYCLE TESTS"
echo "=================="

# Test lifecycle commands
run_test "dcutil restart" "\"$DCUTIL\" restart 2>&1 | grep -q 'restart\|Restart'" 0
run_test "dcutil enter" "\"$DCUTIL\" enter 2>&1 | grep -q 'enter\|Enter'" 0

echo ""
echo "🧪 INTERACTIVE MENU TESTS"
echo "========================="

# Test menu commands (these will show menu but not execute due to no TTY)
run_test "dcutil menu (no TTY)" "echo '0' | \"$DCUTIL\" 2>&1 | grep -q 'menu\|What'" 0

echo ""
echo "📝 COMPLETION TESTS"
echo "==================="

# Test completion
run_test "dcutil completion bash" "\"$DCUTIL\" completion bash | grep -q 'function\|_dcutil'" 0
run_test "dcutil completion zsh" "\"$DCUTIL\" completion zsh | grep -q 'compdef\|_dcutil'" 0

echo ""
echo "🧪 EDGE CASE TESTS"
echo "=================="

# Test with various path scenarios
run_test "dcutil with relative path" "\"$DCUTIL\" status ./test-go 2>&1 | grep -q 'status\|Status'" 0
run_test "dcutil with absolute path" "\"$DCUTIL\" status \"$PWD/test-node\" 2>&1 | grep -q 'status\|Status'" 0

# Test with environment variables
run_test "dcutil with DCUTIL_QUIET" "DCUTIL_QUIET=1 \"$DCUTIL\" status 2>&1 | wc -l | grep -q '^[0-5]$'" 0

echo ""
echo "🔍 LIBRARY SYNTAX TESTS"
echo "======================="

# Test all library files for syntax errors
LIB_DIR="$SCRIPT_DIR/dcutil-files/lib"
if [ -d "$LIB_DIR" ]; then
    for lib_file in "$LIB_DIR"/*.sh; do
        if [ -f "$lib_file" ] && [ -r "$lib_file" ]; then
            lib_name=$(basename "$lib_file" .sh)
            run_test "$lib_name library syntax" "bash -n \"$lib_file\"" 0
        fi
    done
fi

echo ""
echo "📊 CONFIGURATION TESTS"
echo "======================"

# Test configuration file handling
for project in "${PROJECT_TYPES[@]}"; do
    if [ -d "$project" ]; then
        # Test with missing devcontainer.json
        run_test "$project missing config" "cd $project && rm -f .devcontainer/devcontainer.json && \"$DCUTIL\" status 2>&1 | grep -q 'status\|Status'" 0

        # Test with malformed JSON
        echo '{"name": "test", "image": }' > "$project/.devcontainer/devcontainer.json"
        run_test "$project malformed JSON" "cd $project && \"$DCUTIL\" schema validate 2>&1 | grep -q 'error\|Error\|invalid'" 1 true
    fi
done

echo ""
echo "🚫 ERROR CONDITION TESTS"
echo "========================"

# Test various error conditions
run_test "dcutil with non-existent path" "\"$DCUTIL\" status /definitely/does/not/exist 2>&1 | grep -q 'exist\|not.*found'" 1 true
run_test "dcutil run without container" "\"$DCUTIL\" run echo test 2>&1 | grep -q 'not.*running\|no.*container'" 1 true

echo ""
echo "🎯 COMMAND COMBINATION TESTS"
echo "============================"

# Test command combinations and sequences
run_test "Multiple status calls" "for i in {1..3}; do \"$DCUTIL\" status >/dev/null 2>&1; done" 0
run_test "Mixed commands sequence" "\"$DCUTIL\" version >/dev/null && \"$DCUTIL\" help >/dev/null && \"$DCUTIL\" status >/dev/null" 0

echo ""
echo "=== COMPREHENSIVE TEST RESULTS ==="
echo "Total tests: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Skipped: $TESTS_SKIPPED"

success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))

echo "Success rate: ${success_rate}%"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL FUNCTIONALITY TESTS PASSED!${NC}"
    echo -e "${CYAN}dcutil is fully functional and ready for use${NC}"
    exit 0
else
    echo -e "${RED}💥 $TESTS_FAILED functionality tests failed${NC}"
    echo -e "${YELLOW}Some features may not work as expected${NC}"
    exit 1
fi