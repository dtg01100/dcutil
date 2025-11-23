#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCUTIL="$SCRIPT_DIR/dcutil"

# Test function similar to the original
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "Running test: $test_name"
    echo "Command: $test_command"
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo "PASS: $test_name"
    else
        echo "FAIL: $test_name"
    fi
}

# Test 1: Help system
run_test "Main help system" "$DCUTIL help"
echo "Test 1 completed"

# Test 2: Command validation  
run_test "Command validation" "$DCUTIL invalid-command 2>&1 | grep -q 'Invalid command'"
echo "Test 2 completed"

echo "All tests finished"