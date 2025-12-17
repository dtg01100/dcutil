#!/bin/bash

# Master test runner for comprehensive menu and wizard testing
# Executes tests in priority order: high-risk first

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

print_test() {
    echo -e "${YELLOW}▶ Running: $1${NC}"
}

print_pass() {
    echo -e "${GREEN}✓ PASSED: $1${NC}"
}

print_fail() {
    echo -e "${RED}✗ FAILED: $1${NC}"
}

# Track results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

run_test() {
    local test_name="$1"
    local test_script="$2"
    
    print_test "$test_name"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ ! -f "$test_script" ]; then
        print_fail "$test_name (script not found: $test_script)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("$test_name")
        return 1
    fi
    
    if ! [ -x "$test_script" ]; then
        chmod +x "$test_script"
    fi
    
    if "$test_script" ./dcutil 2>&1 | tee "/tmp/test_${TESTS_RUN}.log"; then
        print_pass "$test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_fail "$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("$test_name")
        return 1
    fi
}

# Main execution
print_header "Comprehensive Menu & Wizard Testing Suite"
echo "Strategy: High-risk areas first, then medium, then low"
echo "Started at: $(date)"

# Check if dcutil exists
if [ ! -f ./dcutil ]; then
    echo -e "${RED}Error: ./dcutil not found${NC}"
    exit 1
fi

# HIGH RISK TESTS
print_header "HIGH RISK TESTS"

run_test "Menu Flow Comprehensive" \
    "test-menu/test_menu_comprehensive.expect" || true

run_test "Wizard Reliability" \
    "test-wizard-comprehensive/test_wizard_reliable.expect" || true

# MEDIUM RISK TESTS
print_header "MEDIUM RISK TESTS"

run_test "Features Regression" \
    "dcutil-files/tests/features_regression_test.sh" || true

# LOW RISK TESTS  
print_header "LOW RISK TESTS"

run_test "Menu Basic Navigation" \
    "test-menu/test_menu_simple.expect" || true

run_test "Wizard Basic Flow" \
    "test-wizard-comprehensive/test_wizard_comprehensive.expect" || true

# Summary
print_header "TEST RESULTS SUMMARY"

echo "Total Tests Run:    $TESTS_RUN"
echo -e "${GREEN}Tests Passed:       $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed:       $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed Tests:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${RED}✗ $test${NC}"
    done
    echo ""
    echo "Test logs available in /tmp/test_*.log"
    exit 1
else
    echo ""
    echo -e "${GREEN}🎉 All tests PASSED!${NC}"
    exit 0
fi
