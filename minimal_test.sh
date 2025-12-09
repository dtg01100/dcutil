#!/bin/bash
set -euo pipefail
DCUTIL="./dcutil"
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit="${3:-0}"
    echo "Running: $test_name"
    set +e
    eval "$test_cmd"
    local rc=$?
    set -e
    if [ $rc -eq "$expected_exit" ]; then
        echo "PASS: $test_name"
    else
        echo "FAIL: $test_name (expected $expected_exit, got $rc)"
        exit 1
    fi
}
run_test "Version command" "\"$DCUTIL\" version >/dev/null"
echo "Test completed"

