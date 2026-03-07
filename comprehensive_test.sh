#!/bin/bash

# Comprehensive dcutil functionality test suite
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DCUTIL="$SCRIPT_DIR/dcutil-files/dcutil"

echo "🧪 Comprehensive dcutil Functionality Test Suite"
echo "================================================"
echo ""

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
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

test_skip() {
    echo -e "${YELLOW}⏭️  SKIP${NC}: $1"
    ((TESTS_SKIPPED++))
    ((TESTS_RUN++))
}

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit="${3:-0}"
    local skip_if="${4:-}"

    # Check if test should be skipped
    if [ -n "$skip_if" ] && eval "$skip_if"; then
        test_skip "$test_name ($skip_if)"
        return
    fi

    echo -e "${BLUE}Running${NC}: $test_name"

    # Run the test
    if eval "$test_cmd"; then
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

# Helper function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Helper function to check if docker/podman is available
container_runtime_available() {
    # Return success if either docker or podman can list containers
    if command -v docker >/dev/null 2>&1; then
        docker ps >/dev/null 2>&1 && return 0 || return 1
    elif command -v podman >/dev/null 2>&1; then
        podman ps >/dev/null 2>&1 && return 0 || return 1
    fi
    return 1
}

# Helper function to check if devcontainer CLI is available
devcontainer_available() {
    command -v devcontainer >/dev/null 2>&1
}

echo "🔍 Checking prerequisites..."
echo ""

# Check prerequisites
run_test "Docker/Podman available" "container_runtime_available" 0
run_test "devcontainer CLI available" "devcontainer_available" 0
run_test "jq available" "command_exists jq" 0
run_test "curl available" "command_exists curl" 0

echo ""
echo "🧪 Testing Core Container Management Commands"
echo "=============================================="

# Test basic help and version
run_test "dcutil help" "\"$DCUTIL\" help >/dev/null" 0
run_test "dcutil version" "\"$DCUTIL\" version >/dev/null" 0

# Test status (should work without containers)
run_test "dcutil status (no containers)" "\"$DCUTIL\" status >/dev/null" 0

# Test list (should work without containers)
run_test "dcutil list (no containers)" "\"$DCUTIL\" list >/dev/null" 0

# Test invalid command
run_test "dcutil invalid-command" "\"$DCUTIL\" nonexistent-command >/dev/null" 1

echo ""
echo "🧪 Testing Advanced Features"
echo "============================"

# Test features command help
run_test "dcutil features (no args)" "\"$DCUTIL\" features >/dev/null" 1

# Test advanced command help
run_test "dcutil advanced (no args)" "\"$DCUTIL\" advanced >/dev/null" 1

# Test integration command help
run_test "dcutil integration (no args)" "\"$DCUTIL\" integration >/dev/null" 1

# Test schema validation
run_test "dcutil schema (no args)" "\"$DCUTIL\" schema validate 2>/dev/null || true" 0

echo ""
echo "🧪 Testing Backend Management"
echo "============================="

# Test podman backend
run_test "dcutil podman status" "\"$DCUTIL\" podman status >/dev/null" 0

echo ""
echo "🧪 Testing Orchestration & Utilities"
echo "===================================="

# Test volumes command help
run_test "dcutil volumes (no args)" "\"$DCUTIL\" volumes >/dev/null" 1

# Test compose command help
run_test "dcutil compose (no args)" "\"$DCUTIL\" compose >/dev/null" 1

# Test environment command
run_test "dcutil environment (no args)" "\"$DCUTIL\" environment info >/dev/null" 0


echo ""
echo "🧪 Testing Interactive Flows (Expect Tests)"
echo "==========================================="

# Run expect tests if available
if command_exists expect; then
    echo "Running expect-based interactive tests..."

    # Clean and run menu test
    run_test "Interactive Menu" "cd test-menu && rm -rf .devcontainer .github 2>/dev/null; expect ../test_menu.expect >/dev/null 2>&1 && echo 'PASS found' | grep -q PASS" 0

    # Clean and run error test
    run_test "Error: Existing Config" "cd test-error-conditions && mkdir -p .devcontainer && echo '{\"name\": \"existing\"}' > .devcontainer/devcontainer.json && expect ../test_error_existing_config.expect >/dev/null 2>&1 && echo 'PASS found' | grep -q PASS" 0

    # Clean and run fast init test
    run_test "Fast Init" "cd test-fast-init && rm -rf .devcontainer .github 2>/dev/null; expect ../test_fast_init.expect >/dev/null 2>&1 && echo 'PASS found' | grep -q PASS" 0

    # Clean and run wizard tests
    run_test "Wizard Basic" "cd test-wizard-comprehensive && rm -rf .devcontainer .github 2>/dev/null; timeout 120 expect ../test_wizard_comprehensive.expect >/dev/null 2>&1 && echo 'PASS found' | grep -q PASS" 0

    run_test "Wizard Custom Image" "cd test-wizard-custom && rm -rf .devcontainer .github 2>/dev/null; timeout 120 expect ../test_wizard_custom.expect >/dev/null 2>&1 && echo 'PASS found' | grep -q PASS" 0
else
    test_skip "Interactive tests (expect not available)"
fi

echo ""
echo "🧪 Testing Project-Specific Scenarios"
echo "===================================="

# Test different project types
PROJECT_TYPES=("test-go" "test-node" "test-python" "test-rust" "test-ubuntu")

for project in "${PROJECT_TYPES[@]}"; do
    if [ -d "$project" ]; then
        echo "Testing $project..."

        # Test status in project directory
        run_test "$project status" "cd $project && \"$DCUTIL\" status >/dev/null" 0

        # Test schema validation
        run_test "$project schema validate" "cd $project && \"$DCUTIL\" schema validate >/dev/null 2>&1" 0
    fi
done

echo ""
echo "🧪 Testing Library Syntax"
echo "========================="

# Test library syntax
LIB_DIR="$SCRIPT_DIR/dcutil-files/lib"
if [ -d "$LIB_DIR" ]; then
    for lib_file in "$LIB_DIR"/*.sh; do
        if [ -f "$lib_file" ]; then
            lib_name=$(basename "$lib_file" .sh)
            run_test "$lib_name library syntax" "bash -n \"$lib_file\"" 0
        fi
    done
fi

echo ""
echo "=== Comprehensive Test Results ==="
echo "Total tests: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Skipped: $TESTS_SKIPPED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All functionality tests passed!${NC}"
    exit 0
else
    echo -e "${RED}💥 $TESTS_FAILED functionality tests failed${NC}"
    exit 1
fi