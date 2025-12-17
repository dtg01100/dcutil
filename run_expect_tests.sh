#!/bin/bash

# Comprehensive expect test runner for dcutil
# Gracefully handles missing tests and timeouts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🧪 Running dcutil expect tests..."
echo "=================================="

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

run_expect_test() {
    local test_name="$1"
    local test_script="$2"
    local test_dir="$3"
    local timeout="${4:-60}"

    local dcutil_path="../dcutil"
    local script_path="$test_script"

    # Check if test script exists
    if [ -n "$test_dir" ] && [ ! -f "$test_dir/$script_path" ]; then
        echo ""
        echo "Skipping: $test_name (script not found: $test_dir/$script_path)"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        return 0
    fi

    echo ""
    echo "Running: $test_name"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Clean up test directory if it exists
    if [ -n "$test_dir" ] && [ -d "$test_dir" ]; then
        rm -rf "$test_dir/.devcontainer" "$test_dir/.github" 2>/dev/null || true
    fi

    # Run expect in the test directory
    local output=""
    if [ -n "$test_dir" ]; then
        # Run inside test directory so artifacts go there; point expect at ../dcutil
        output=$(cd "$test_dir" && timeout "$timeout" expect "./$script_path" "$dcutil_path" 2>&1) || true
    else
        output=$(timeout "$timeout" expect "$script_path" ./dcutil 2>&1) || true
    fi
    local exit_code=$?

    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "PASS"; then
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [ $exit_code -eq 124 ]; then
        echo "⏱️  TIMEOUT: $test_name (exceeded ${timeout}s)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo "❌ FAIL: $test_name (exit code: $exit_code)"
        # Show last few lines of output for debugging
        echo "$output" | tail -5
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test menu functionality
if [ -d "test-menu" ]; then
    run_expect_test "Interactive Menu" "test_menu.expect" "test-menu" 30
    run_expect_test "Menu High-Risk" "test_menu_highrisk.expect" "test-menu" 30
    run_expect_test "Features Add/Remove" "test_features_add_remove.expect" "test-menu" 45
else
    echo "Skipping interactive menu test (test-menu directory not found)"
fi

# Test error conditions
if [ -d "test-error-conditions" ]; then
    run_expect_test "Error: Existing Config" "test_error_existing_config.expect" "test-error-conditions" 30
else
    echo "Skipping error conditions test (test-error-conditions directory not found)"
fi

# Test fast init
if [ -d "test-fast-init" ]; then
    run_expect_test "Fast Init" "test_fast_init.expect" "test-fast-init" 60
else
    echo "Skipping fast init test (test-fast-init directory not found)"
fi

# Test wizard (shorter timeout)
if [ -d "test-wizard-comprehensive" ]; then
    run_expect_test "Wizard Basic" "test_wizard_comprehensive.expect" "test-wizard-comprehensive" 60
else
    echo "Skipping wizard comprehensive test (test-wizard-comprehensive directory not found)"
fi

# Test custom wizard
if [ -d "test-wizard-custom" ]; then
    run_expect_test "Wizard Custom Image" "test_wizard_custom.expect" "test-wizard-custom" 60
else
    echo "Skipping wizard custom test (test-wizard-custom directory not found)"
fi

# Test edit functionality (expect tests present)
if [ -d "test-edit" ]; then
    run_expect_test "Edit valid" "expect_edit_valid.expect" "test-edit" 30
    run_expect_test "Edit invalid-then-reedit" "expect_edit_invalid_then_reedit.expect" "test-edit" 30
    if [ -f "test-edit/expect_edit_invalid_cycle.expect" ]; then
        run_expect_test "Edit invalid cycle (re-edit)" "expect_edit_invalid_cycle.expect" "test-edit" 30
    fi
else
    echo "Skipping edit expect tests (test-edit directory not found)"
fi

echo ""
echo "=== Test Results ==="
echo "Total tests run: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Skipped: $TESTS_SKIPPED"
echo "Failed: $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo "�� All expect tests passed!"
    exit 0
else
    echo "💥 $TESTS_FAILED expect tests failed"
    exit 1
fi
