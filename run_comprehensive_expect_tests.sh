#!/bin/bash

# Comprehensive expect test runner for dcutil
# Tests all features, wizard, dialog, and menu functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🧪 Running comprehensive dcutil expect tests..."
echo "=============================================="

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run expect test
run_expect_test() {
    local test_name="$1"
    local test_script="$2"
    local test_dir="$3"
    local timeout="${4:-120}"
    
    echo ""
    echo "🧪 Running: $test_name"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Clean up test directory if it exists
    if [ -n "$test_dir" ] && [ -d "$test_dir" ]; then
        rm -rf "$test_dir/.devcontainer" "$test_dir/.github" 2>/dev/null || true
    fi
    
    # Run expect in the test directory
    local output=""
    if [ -n "$test_dir" ]; then
        output=$(cd "$test_dir" && timeout "$timeout" expect "../$test_script" 2>&1)
    else
        output=$(timeout "$timeout" expect "$test_script" 2>&1)
    fi
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "PASS"; then
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAIL: $test_name (exit code: $exit_code)"
        # Show last few lines of output for debugging
        echo "$output" | tail -15
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 1: Comprehensive features and menu test
if [ -f "test_comprehensive.expect" ]; then
    run_expect_test "Comprehensive Features & Menu" "test_comprehensive.expect" "" 120
fi

# Test 2: Dialog features test
if [ -f "test_dialog_features.expect" ]; then
    run_expect_test "Dialog Features" "test_dialog_features.expect" "" 60
fi

# Test 3: Wizard comprehensive test
if [ -f "test_wizard_comprehensive.expect" ]; then
    run_expect_test "Wizard Comprehensive" "test_wizard_comprehensive.expect" "" 120
fi

# Test 4: Menu functionality test
if [ -f "test_menu.expect" ]; then
    run_expect_test "Menu Functionality" "test_menu.expect" "" 60
fi

# Test 5: Actual features test (existing)
if [ -f "test_actual_features.expect" ]; then
    if [ -d "test_features_dir" ]; then
        run_expect_test "Actual Features" "test_actual_features.expect" "test_features_dir" 60
    else
        echo "⚠️  Skipping actual features test (test_features_dir not found)"
    fi
fi

# Test 6: Features dialog test (existing)
if [ -f "test_features_dialog.expect" ]; then
    run_expect_test "Features Dialog" "test_features_dialog.expect" "" 60
fi

# Test 7: Wizard comprehensive test (existing)
if [ -f "test_wizard_comprehensive.expect" ]; then
    if [ -d "test-wizard-comprehensive" ]; then
        run_expect_test "Wizard Basic" "test_wizard_comprehensive.expect" "test-wizard-comprehensive" 120
    else
        echo "⚠️  Skipping wizard comprehensive test (test-wizard-comprehensive not found)"
    fi
fi

# Test 8: Menu test (existing)
if [ -d "test-menu" ]; then
    if [ -f "test-menu/test_menu.expect" ]; then
        run_expect_test "Interactive Menu" "test_menu.expect" "test-menu" 60
    else
        echo "⚠️  Skipping interactive menu test (test_menu.expect not found in test-menu)"
    fi
else
    echo "⚠️  Skipping interactive menu test (test-menu directory not found)"
fi

# Test 9: Error conditions test (existing)
if [ -d "test-error-conditions" ]; then
    if [ -f "test-error-conditions/test_error_existing_config.expect" ]; then
        run_expect_test "Error: Existing Config" "test_error_existing_config.expect" "test-error-conditions" 60
    else
        echo "⚠️  Skipping error conditions test (test_error_existing_config.expect not found)"
    fi
else
    echo "⚠️  Skipping error conditions test (test-error-conditions directory not found)"
fi

# Test 10: Fast init test (existing)
if [ -d "test-fast-init" ]; then
    if [ -f "test-fast-init/test_fast_init.expect" ]; then
        run_expect_test "Fast Init" "test_fast_init.expect" "test-fast-init" 120
    else
        echo "⚠️  Skipping fast init test (test_fast_init.expect not found)"
    fi
else
    echo "⚠️  Skipping fast init test (test-fast-init directory not found)"
fi

# Test 11: Wizard custom test (existing)
if [ -d "test-wizard-custom" ]; then
    if [ -f "test-wizard-custom/test_wizard_custom.expect" ]; then
        run_expect_test "Wizard Custom Image" "test_wizard_custom.expect" "test-wizard-custom" 120
    else
        echo "⚠️  Skipping wizard custom test (test_wizard_custom.expect not found)"
    fi
else
    echo "⚠️  Skipping wizard custom test (test-wizard-custom directory not found)"
fi

# Test 12: Edit tests (existing)
if [ -d "test-edit" ]; then
    if [ -f "test-edit/expect_edit_valid.expect" ]; then
        run_expect_test "Edit valid" "expect_edit_valid.expect" "test-edit" 60
    else
        echo "⚠️  Skipping edit valid test (expect_edit_valid.expect not found)"
    fi
    
    if [ -f "test-edit/expect_edit_invalid_then_reedit.expect" ]; then
        run_expect_test "Edit invalid-then-reedit" "expect_edit_invalid_then_reedit.expect" "test-edit" 60
    else
        echo "⚠️  Skipping edit invalid-then-reedit test (expect_edit_invalid_then_reedit.expect not found)"
    fi
    
    if [ -f "test-edit/expect_edit_invalid_cycle.expect" ]; then
        run_expect_test "Edit invalid cycle (re-edit)" "expect_edit_invalid_cycle.expect" "test-edit" 60
    else
        echo "⚠️  Skipping edit invalid cycle test (expect_edit_invalid_cycle.expect not found)"
    fi
else
    echo "⚠️  Skipping edit tests (test-edit directory not found)"
fi

echo ""
echo "=== Test Results ==="
echo "Total tests: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo "🎉 All expect tests passed!"
    exit 0
else
    echo "💥 $TESTS_FAILED expect tests failed"
    exit 1
fi