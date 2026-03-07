#!/bin/bash

# Comprehensive test runner for both text and dialog modes
# Usage: ./run_mode_tests.sh [text|dialog|both]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCUTIL_CMD="${1:-./dcutil}"
TEST_MODE="${2:-both}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_file="$2"
    local mode="$3"
    
    echo -e "${BLUE}▶ Running: $test_name ($mode mode)${NC}"
    
    # Run the test and capture the exit code
    expect "$test_file" "$DCUTIL_CMD" >/dev/null 2>&1
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED: $test_name ($mode mode)${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗ FAILED: $test_name ($mode mode)${NC}"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Function to run text mode tests
run_text_mode_tests() {
    echo -e "${YELLOW}=========================================${NC}"
    echo -e "${YELLOW}🧪 Running TEXT Mode Tests${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    
    # Menu tests
    echo "Running menu test..."
    if [ -f "$SCRIPT_DIR/test-menu/test_menu_text_mode.expect" ]; then
        run_test "Menu Text Mode" "$SCRIPT_DIR/test-menu/test_menu_text_mode.expect" "text"
        echo "Menu test completed successfully"
    else
        echo "Menu test file not found at $SCRIPT_DIR/test-menu/test_menu_text_mode.expect"
    fi
    
    # Wizard tests
    echo "Running wizard test..."
    if [ -f "$SCRIPT_DIR/test-wizard-comprehensive/test_wizard_text_mode.expect" ]; then
        run_test "Wizard Text Mode" "$SCRIPT_DIR/test-wizard-comprehensive/test_wizard_text_mode.expect" "text"
        echo "Wizard test completed successfully"
    else
        echo "Wizard test file not found at $SCRIPT_DIR/test-wizard-comprehensive/test_wizard_text_mode.expect"
    fi
    
    echo "All text mode tests completed"
}

# Function to run dialog mode tests
run_dialog_mode_tests() {
    echo -e "${YELLOW}=========================================${NC}"
    echo -e "${YELLOW}🧪 Running DIALOG Mode Tests${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    
    # Menu tests
    if [ -f "$SCRIPT_DIR/test-menu/test_menu_dialog_mode.expect" ]; then
        run_test "Menu Dialog Mode" "$SCRIPT_DIR/test-menu/test_menu_dialog_mode.expect" "dialog"
    fi
    
    if [ -f "$SCRIPT_DIR/test-wizard-comprehensive/test_wizard_dialog_mode.expect" ]; then
        run_test "Wizard Dialog Mode" "$SCRIPT_DIR/test-wizard-comprehensive/test_wizard_dialog_mode.expect" "dialog"
    fi
}

# Function to run all tests
run_all_tests() {
    run_text_mode_tests
    run_dialog_mode_tests
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [dcutil_path] [test_mode]"
    echo ""
    echo "Arguments:"
    echo "  dcutil_path  Path to dcutil executable (default: ./dcutil)"
    echo "  test_mode    Test mode: text, dialog, or both (default: both)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Run all tests with ./dcutil"
    echo "  $0 /usr/local/bin/dcutil     # Run all tests with specific dcutil"
    echo "  $0 ./dcutil text             # Run only text mode tests"
    echo "  $0 ./dcutil dialog           # Run only dialog mode tests"
}

# Check if expect is available
if ! command -v expect >/dev/null 2>&1; then
    echo -e "${RED}Error: expect is required but not found${NC}"
    echo "Please install expect: sudo apt-get install expect"
    exit 1
fi

# Parse arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

# Run tests based on mode
case "$TEST_MODE" in
    "text")
        run_text_mode_tests
        ;;
    "dialog")
        run_dialog_mode_tests
        ;;
    "both")
        run_all_tests
        ;;
    *)
        echo -e "${RED}Error: Invalid test mode '$TEST_MODE'${NC}"
        echo "Valid modes: text, dialog, both"
        show_usage
        exit 1
        ;;
esac

# Show results
echo ""
echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}TEST RESULTS SUMMARY${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo -e "Total Tests Run:    $TOTAL_TESTS"
echo -e "Tests Passed:       $PASSED_TESTS"
echo -e "Tests Failed:       $FAILED_TESTS"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi