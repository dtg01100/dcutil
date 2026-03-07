#!/bin/bash

# "Break dcutil" - Comprehensive stress and edge case testing
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DCUTIL="$SCRIPT_DIR/dcutil-files/dcutil"

echo "💥 Break dcutil - Stress & Edge Case Testing"
echo "============================================"
echo ""

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_EXPECTED_FAIL=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

test_expected_fail() {
    echo -e "${PURPLE}🎯 EXPECTED FAIL${NC}: $1"
    ((TESTS_EXPECTED_FAIL++))
    ((TESTS_RUN++))
}

run_break_test() {
    local test_name="$1"
    local test_cmd="$2"
    local should_fail="${3:-false}"
    local expected_exit="${4:-0}"

    echo -e "${BLUE}Breaking${NC}: $test_name"

    if eval "$test_cmd" 2>/dev/null; then
        local exit_code=$?
        if [ "$should_fail" = "true" ]; then
            if [ $exit_code -ne 0 ]; then
                test_expected_fail "$test_name (correctly failed with exit $exit_code)"
            else
                test_fail "$test_name (should have failed but succeeded)"
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
        if [ "$should_fail" = "true" ]; then
            if [ $exit_code -ne 0 ]; then
                test_expected_fail "$test_name (correctly failed with exit $exit_code)"
            else
                test_fail "$test_name (should have failed but succeeded)"
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

echo "🧪 Testing Invalid Command Line Arguments"
echo "========================================="

# Test completely invalid commands
run_break_test "Completely invalid command" "\"$DCUTIL\" xyz123abc" true
run_break_test "Command with invalid characters" "\"$DCUTIL\" @#$%^&*()" true
run_break_test "Empty command" "\"$DCUTIL\" ''" true
run_break_test "Command with only spaces" "\"$DCUTIL\" '   '" true

# Test valid commands with invalid arguments
run_break_test "up with invalid option" "\"$DCUTIL\" up --invalid-option" true
run_break_test "down with arguments" "\"$DCUTIL\" down extra-arg" true
run_break_test "status with invalid flag" "\"$DCUTIL\" status --badflag" true

# Test numeric edge cases
run_break_test "Command that's just a number" "\"$DCUTIL\" 12345" true
run_break_test "Negative number command" "\"$DCUTIL\" -999" true

echo ""
echo "🧪 Testing Malformed Configuration Files"
echo "========================================"

# Create test directory with broken configs
mkdir -p test-break-config
cd test-break-config

# Test invalid JSON
echo '{"name": "broken", "image": }' > .devcontainer/devcontainer.json
run_break_test "Invalid JSON syntax" "\"$DCUTIL\" status" true

# Test empty JSON
echo '{}' > .devcontainer/devcontainer.json
run_break_test "Empty JSON config" "\"$DCUTIL\" status" false

# Test JSON with invalid properties
echo '{"name": 123, "image": null, "invalidProp": "value"}' > .devcontainer/devcontainer.json
run_break_test "Invalid property types" "\"$DCUTIL\" schema validate" true

# Test corrupted devcontainer.json
echo 'not json at all' > .devcontainer/devcontainer.json
run_break_test "Non-JSON content" "\"$DCUTIL\" status" true

# Test missing required fields
echo '{"name": "test"}' > .devcontainer/devcontainer.json
run_break_test "Missing required image field" "\"$DCUTIL\" status" false

cd ..

echo ""
echo "🧪 Testing Permission & Access Issues"
echo "===================================="

# Create directory with no permissions
mkdir -p test-no-perm
chmod 000 test-no-perm
run_break_test "No read permission on directory" "cd test-no-perm && \"$DCUTIL\" status 2>/dev/null" true
chmod 755 test-no-perm
rmdir test-no-perm

# Test with read-only config file
mkdir -p test-readonly
echo '{"name": "readonly"}' > test-readonly/devcontainer.json
chmod 444 test-readonly/devcontainer.json
run_break_test "Read-only config file" "cd test-readonly && \"$DCUTIL\" status" false
chmod 644 test-readonly/devcontainer.json
rm -rf test-readonly

echo ""
echo "🧪 Testing Network & External Dependency Failures"
echo "================================================"

# Test with network unavailable (simulate by blocking curl)
run_break_test "Network unavailable for templates" "curl --connect-timeout 1 http://nonexistent-domain-12345.com 2>/dev/null && \"$DCUTIL\" init fast 2>/dev/null || true" true

# Test with invalid URLs in config
mkdir -p test-bad-url
cd test-bad-url
echo '{"name": "badurl", "image": "nonexistent-registry.com/invalid/image:tag"}' > .devcontainer/devcontainer.json
run_break_test "Invalid image URL" "\"$DCUTIL\" up" true
cd ..

echo ""
echo "🧪 Testing Resource Exhaustion"
echo "=============================="

# Test with very long command arguments
long_arg=$(printf 'A%.0s' {1..10000})
run_break_test "Extremely long argument" "\"$DCUTIL\" status $long_arg 2>/dev/null" true

# Test with many arguments
many_args=""
for i in {1..100}; do
    many_args="$many_args arg$i"
done
run_break_test "Too many arguments" "\"$DCUTIL\" status $many_args 2>/dev/null" true

echo ""
echo "🧪 Testing Concurrent Operations"
echo "==============================="

# Test running multiple dcutil commands simultaneously
run_break_test "Concurrent status calls" "for i in {1..5}; do \"$DCUTIL\" status >/dev/null 2>&1 & done; wait" false

echo ""
echo "🧪 Testing Invalid Container Names & Images"
echo "==========================================="

mkdir -p test-invalid-names
cd test-invalid-names

# Test with invalid container names
echo '{"name": "invalid@name", "image": "ubuntu:latest"}' > .devcontainer/devcontainer.json
run_break_test "Invalid container name with special chars" "\"$DCUTIL\" status" false

# Test with non-existent image
echo '{"name": "nonexistent", "image": "definitely-does-not-exist:latest"}' > .devcontainer/devcontainer.json
run_break_test "Non-existent image" "\"$DCUTIL\" up" true

cd ..

echo ""
echo "🧪 Testing Missing Dependencies"
echo "==============================="

# Test without jq (simulate by renaming)
if command -v jq >/dev/null; then
    jq_path=$(which jq)
    mv "$jq_path" "${jq_path}.backup" 2>/dev/null || true
    run_break_test "Missing jq dependency" "\"$DCUTIL\" volumes list 2>/dev/null" true
    mv "${jq_path}.backup" "$jq_path" 2>/dev/null || true
fi

# Test without devcontainer CLI
if command -v devcontainer >/dev/null; then
    dc_path=$(which devcontainer)
    mv "$dc_path" "${dc_path}.backup" 2>/dev/null || true
    run_break_test "Missing devcontainer CLI" "\"$DCUTIL\" up 2>/dev/null" true
    mv "${dc_path}.backup" "$dc_path" 2>/dev/null || true
fi

echo ""
echo "🧪 Testing Corrupted State"
echo "=========================="

mkdir -p test-corrupted
cd test-corrupted

# Create config with circular references (if possible)
echo '{"name": "corrupted", "features": {"self": "self"}}' > .devcontainer/devcontainer.json
run_break_test "Self-referencing config" "\"$DCUTIL\" schema validate" true

# Test with conflicting settings
echo '{"name": "conflict", "image": "ubuntu", "dockerFile": "Dockerfile", "dockerComposeFile": "compose.yml"}' > .devcontainer/devcontainer.json
run_break_test "Conflicting configuration options" "\"$DCUTIL\" schema validate" true

cd ..

echo ""
echo "🧪 Testing Edge Cases in Subcommands"
echo "==================================="

# Test features with invalid feature names
run_break_test "Invalid feature name" "\"$DCUTIL\" features install @#$%^&" true

# Test volumes with invalid paths
run_break_test "Invalid volume path" "\"$DCUTIL\" volumes add test-vol /nonexistent/source /nonexistent/target" true

# Test compose with no compose file
run_break_test "Compose without compose file" "\"$DCUTIL\" compose up" true

# Test run with no arguments
run_break_test "Run command without args" "\"$DCUTIL\" run" true

echo ""
echo "🧪 Testing Boundary Conditions"
echo "============================="

# Test with empty environment variables
DCUTIL_SAVE=$DCUTIL_BACKEND
export DCUTIL_BACKEND=""
run_break_test "Empty backend environment var" "\"$DCUTIL\" status" false
export DCUTIL_BACKEND=$DCUTIL_SAVE

# Test with invalid backend
export DCUTIL_BACKEND="invalid-backend"
run_break_test "Invalid backend setting" "\"$DCUTIL\" status" false
export DCUTIL_BACKEND=$DCUTIL_SAVE

# Test with extremely long paths
mkdir -p test-long-path
long_path="test-long-path"
for i in {1..10}; do
    long_path="$long_path/very-long-directory-name-that-might-cause-issues"
done
mkdir -p "$long_path"
cd "$long_path"
run_break_test "Extremely long path" "\"$DCUTIL\" status" false
cd ../../../../..

echo ""
echo "🧪 Testing Rapid Command Sequences"
echo "=================================="

# Test rapid start/stop cycles
run_break_test "Rapid status checks" "for i in {1..10}; do \"$DCUTIL\" status >/dev/null 2>&1; done" false

echo ""
echo "🧪 Testing Memory & Performance Stress"
echo "====================================="

# Test with large number of environment variables
env_vars=""
for i in {1..50}; do
    env_vars="$env_vars TEST_VAR_$i=value_$i"
done
run_break_test "Many environment variables" "env $env_vars \"$DCUTIL\" status >/dev/null" false

echo ""
echo "=== Break Test Results ==="
echo "Total tests: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed (unexpected): $TESTS_FAILED"
echo "Expected failures: $TESTS_EXPECTED_FAIL"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 dcutil survived all break attempts!${NC}"
    echo -e "${PURPLE}💪 $TESTS_EXPECTED_FAIL expected failures handled correctly${NC}"
    exit 0
else
    echo -e "${RED}💥 $TESTS_FAILED unexpected failures - dcutil has vulnerabilities!${NC}"
    exit 1
fi

# Cleanup
rm -rf test-break-config test-no-perm test-readonly test-bad-url test-invalid-names test-corrupted test-long-path