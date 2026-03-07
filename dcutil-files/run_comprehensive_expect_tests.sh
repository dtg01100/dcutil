#!/bin/bash

# Comprehensive expect test runner for dcutil
# Tests all features, wizard, dialog, and menu functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default test environment variables
export DCUTIL_FORCE_DIALOG="${DCUTIL_FORCE_DIALOG:-0}"
export FEATURES_DRY_RUN="${FEATURES_DRY_RUN:-true}"

# Detect docker availability and skip or mark heavy tests accordingly
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    export DCUTIL_TEST_NO_DOCKER=0
else
    export DCUTIL_TEST_NO_DOCKER=1
fi

# Helper to ensure a minimal devcontainer.json exists for tests (to avoid jq parse errors)
ensure_devcontainer_config() {
    local dir="$1"
    if [ -z "$dir" ]; then
        return 0
    fi

    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
    fi
    if [ ! -d "$dir/.devcontainer" ]; then
        mkdir -p "$dir/.devcontainer"
    fi
    local cfg_file="$dir/.devcontainer/devcontainer.json"

    # If config doesn't exist, create a minimal one
    if [ ! -f "$cfg_file" ]; then
        cat > "$cfg_file" <<'EOF'
{
  "name": "Test Environment",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {}
}
EOF
        return 0
    fi

    # If jq exists and the JSON fails to parse (comments or invalid), back it up and replace
    if command -v jq >/dev/null 2>&1; then
        if ! jq -e . "$cfg_file" >/dev/null 2>&1; then
            mv "$cfg_file" "$cfg_file.bak"
            cat > "$cfg_file" <<'EOF'
{
  "name": "Test Environment",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {}
}
EOF
        fi
    fi
}


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
    local timeout_val="${4:-120}"
    local dialog_force="${5:-${DCUTIL_FORCE_DIALOG}}"
    local skip_if_no_docker="${6:-0}"
    local skip_setup="${7:-0}"

    if [ "$skip_if_no_docker" -ne 0 ] && [ "$DCUTIL_TEST_NO_DOCKER" -eq 1 ]; then
        echo "⚠️  Skipping: $test_name (no docker available)"
        return 0
    fi

    echo ""
    echo "🧪 Running: $test_name"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Prepare environment
    local prev_dir
    prev_dir="$(pwd)"
    local prev_home
    prev_home="$HOME"
    local tmp_home
    tmp_home=$(mktemp -d)
    mkdir -p "$tmp_home"
    touch "$tmp_home/.dcutil_first_run" # Mark as not first run
    export HOME="$tmp_home"

    # Prepare test dir
    local tmp_dir=""
    local cleanup_tmp=0
    if [ -n "$test_dir" ] && [ -d "$SCRIPT_DIR/$test_dir" ]; then
        rm -rf "$SCRIPT_DIR/$test_dir/.devcontainer" "$SCRIPT_DIR/$test_dir/.github" 2>/dev/null || true
        if [ "$skip_setup" -eq 0 ]; then
            ensure_devcontainer_config "$SCRIPT_DIR/$test_dir"
        fi
        cd "$SCRIPT_DIR/$test_dir" || true
    else
        tmp_dir="$(mktemp -d)"
        cleanup_tmp=1
        if [ "$skip_setup" -eq 0 ]; then
            ensure_devcontainer_config "$tmp_dir"
        fi
        cd "$tmp_dir" || true
    fi

    # Ensure DEVCONTAINER_CONFIG_FILE envvar points to the test config
    if [ -f ".devcontainer/devcontainer.json" ]; then
        local config_file
        config_file="$(pwd)/.devcontainer/devcontainer.json"
        export DEVCONTAINER_CONFIG_FILE="$config_file"
    else
        export DEVCONTAINER_CONFIG_FILE=""
    fi

    # Export dialog and features dry-run settings
    export DCUTIL_FORCE_DIALOG="$dialog_force"
    export FEATURES_DRY_RUN="${FEATURES_DRY_RUN:-true}"

    # For tests that need text mode, disable dialog
    if [ "$dialog_force" = "0" ]; then
        export DCUTIL_DISABLE_DIALOG=1
    else
        export DCUTIL_DISABLE_DIALOG=0
    fi

    # Run expect in the current directory, pass dcutil path as arg
    local output
    local expect_script="$test_script"
    if [ -z "$test_dir" ]; then
        expect_script="$SCRIPT_DIR/$test_script"
    else
        # If test_dir is set, check if the script exists in test_dir or needs full path
        if [ -f "$SCRIPT_DIR/$test_dir/$test_script" ]; then
            expect_script="./$test_script"  # Relative to test_dir
        else
            expect_script="$SCRIPT_DIR/$test_script"  # Full path from root
        fi
    fi
    
    # Ensure dcutil path is absolute
    local dcutil_path="$SCRIPT_DIR/dcutil"
    
    output=$(timeout "$timeout_val" expect "$expect_script" "$dcutil_path" 2>&1 || true)
    local exit_code=$?

    # Restore environment
    export DEVCONTAINER_CONFIG_FILE=""
    export DCUTIL_FORCE_DIALOG="${DCUTIL_FORCE_DIALOG:-0}"
    cd "$prev_dir" || true
    export HOME="$prev_home"
    rm -rf "$tmp_home" 2>/dev/null || true
    if [ "$cleanup_tmp" -eq 1 ] && [ -n "$tmp_dir" ]; then
        rm -rf "$tmp_dir" || true
    fi

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

# Initial setup
mkdir -p test-dialog-mode test-menu test-text-mode test-unified-mode test-wizard-comprehensive test-volumes test_features_dir test-volumes-restore test-fast-init test-wizard-custom test-edit test-error-conditions

# 1. Dialog Mode Tests
if [ -f "test-dialog-mode/test_menu_dialog.expect" ]; then
    run_expect_test "Menu Dialog Mode" "test_menu_dialog.expect" "test-dialog-mode" 60 1
fi
if [ -f "test-dialog-mode/test_wizard_dialog.expect" ]; then
    run_expect_test "Wizard Dialog Mode" "test_wizard_dialog.expect" "test-dialog-mode" 60 1 0 1
fi

# 2. Text Mode Tests
if [ -f "test-text-mode/test_menu_text.expect" ]; then
    run_expect_test "Menu Text Mode" "test_menu_text.expect" "test-text-mode" 60 0
fi
if [ -f "test-text-mode/test_wizard_text.expect" ]; then
    run_expect_test "Wizard Text Mode" "test_wizard_text.expect" "test-text-mode" 60 0 0 1
fi

# 3. Unified/Comprehensive Tests
if [ -f "test-unified-mode/test_unified_comprehensive.expect" ]; then
    run_expect_test "Unified Comprehensive" "test_unified_comprehensive.expect" "test-unified-mode" 120 0
fi
if [ -f "test-unified-mode/test_unified_wizard.expect" ]; then
    run_expect_test "Unified Wizard" "test_unified_wizard.expect" "test-unified-mode" 120 0 0 1
fi

# 4. Wizard Comprehensive
if [ -f "test-wizard-comprehensive/test_wizard_comprehensive.expect" ]; then
    run_expect_test "Wizard Comprehensive" "test_wizard_comprehensive.expect" "test-wizard-comprehensive" 120 0 0 1
fi
if [ -f "test-wizard-comprehensive/test_wizard_dialog_mode.expect" ]; then
    run_expect_test "Wizard Comprehensive (Dialog)" "test_wizard_dialog_mode.expect" "test-wizard-comprehensive" 120 1 0 1
fi

# 5. Features Tests
if [ -f "test_dialog_features.expect" ]; then
    run_expect_test "Dialog Features" "test_dialog_features.expect" "" 60 1
fi
if [ -f "test_features_dialog.expect" ]; then
    run_expect_test "Features Dialog" "test_features_dialog.expect" "" 60 0
fi
if [ -f "test_features_cli.expect" ]; then
    run_expect_test "Features CLI" "test_features_cli.expect" "test_features_dir" 60 0
fi

# 6. Volumes Tests
if [ -f "test_volumes_cli.expect" ]; then
    run_expect_test "Volumes CLI" "test_volumes_cli.expect" "test-volumes" 60 0
fi
if [ -f "test_volumes_backup_restore.expect" ]; then
    run_expect_test "Volumes Backup/Restore" "test_volumes_backup_restore.expect" "test-volumes-restore" 120 0
fi

# 7. Edit & Config Tests
if [ -f "test-edit/expect_edit_valid.expect" ]; then
    run_expect_test "Edit valid" "expect_edit_valid.expect" "test-edit" 60 0
fi
if [ -f "test-error-conditions/test_error_existing_config.expect" ]; then
    run_expect_test "Error: Existing Config" "test_error_existing_config.expect" "test-error-conditions" 60 0
fi

# 8. Fast Init
if [ -f "test-fast-init/test_fast_init.expect" ]; then
    run_expect_test "Fast Init" "test_fast_init.expect" "test-fast-init" 120 0 0 1
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
