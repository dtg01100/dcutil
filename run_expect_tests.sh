#!/bin/bash

# Comprehensive expect test runner for dcutil
# Note: Do NOT use 'set -e' - we want to run all tests and collect failures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
cd "$SCRIPT_DIR" || exit 1

echo "🧪 Running dcutil expect tests..."
echo "=================================="

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

run_expect_test() {
    local test_name="$1"
    local test_script="$2"
    local test_dir="$3"
    local timeout="${4:-60}"
    local skip_cleanup="${5:-false}"

    echo ""
    echo -e "${BLUE}Running${NC}: $test_name"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Check if expect is available
    if ! command -v expect >/dev/null 2>&1; then
        echo -e "${YELLOW}⏭️  SKIP${NC}: $test_name (expect not installed)"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        return
    fi

    # Check if test script exists
    if [ ! -f "$test_script" ]; then
        echo -e "${YELLOW}⏭️  SKIP${NC}: $test_name (test script not found: $test_script)"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        return
    fi

    # Create and clean up test directory if specified
    if [ -n "$test_dir" ]; then
        mkdir -p "$test_dir"
        if [ "$skip_cleanup" != "true" ]; then
            rm -rf "$test_dir/.devcontainer" "$test_dir/.github" 2>/dev/null || true
        fi
    fi

    # Run expect test from project root (expect scripts handle their own cd)
    local output
    local exit_code
    output=$(timeout "$timeout" expect "$test_script" "$test_dir" 2>&1) || exit_code=$?

    # Check for timeout (exit code 124)
    if [ "${exit_code:-0}" -eq 124 ]; then
        echo -e "${RED}❌ FAIL${NC}: $test_name (timed out after ${timeout}s)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return
    fi

    if [ "${exit_code:-0}" -eq 0 ] && echo "$output" | grep -q "PASS"; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name (exit code: ${exit_code:-0})"
        # Show last few lines of output for debugging
        echo "Last 10 lines of output:"
        echo "$output" | tail -10
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test menu functionality
run_expect_test "Interactive Menu" "test_menu.expect" "test-menu" 30

# Test error conditions
run_expect_test "Error: Existing Config" "test_error_existing_config.expect" "test-error-conditions" 30

# Test enter stopped container (skip cleanup to preserve any existing state)
run_expect_test "Enter Stopped Container" "test_enter_stopped.expect" "test-enter-stopped" 120 true

# Test fast init
run_expect_test "Fast Init" "test_fast_init.expect" "test-fast-init" 60

# Test wizard (comprehensive)
run_expect_test "Wizard Basic" "test_wizard_comprehensive.expect" "test-wizard-comprehensive" 60

# Test custom wizard
run_expect_test "Wizard Custom Image" "test_wizard_custom.expect" "test-wizard-custom" 60

# Test agent installation with appropriate timeout for container operations
echo ""
echo -e "${BLUE}Running container-based tests...${NC}"
run_expect_test "Agent Install" "test_agent_install.expect" "test-agent" 120

echo ""
echo "=== Test Results ==="
echo "Total tests: $TESTS_RUN"
echo -e "${GREEN}Passed${NC}: $TESTS_PASSED"
echo -e "${RED}Failed${NC}: $TESTS_FAILED"
echo -e "${YELLOW}Skipped${NC}: $TESTS_SKIPPED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All expect tests passed!${NC}"
    exit 0
else
    echo -e "${RED}💥 $TESTS_FAILED expect tests failed${NC}"
    exit 1
fi