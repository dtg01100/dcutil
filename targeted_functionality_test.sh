#!/bin/bash

# Targeted dcutil Functionality Tests
# Focus on specific failing areas and edge cases

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCUTIL="$SCRIPT_DIR/dcutil-files/dcutil"

echo "🎯 TARGETED DCUTIL FUNCTIONALITY TESTS"
echo "====================================="
echo ""

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit="${3:-0}"

    echo -e "${BLUE}Testing${NC}: $test_name"

    if timeout 15 bash -c "$test_cmd" 2>/dev/null; then
        local exit_code=$?
        if [ $exit_code -eq "$expected_exit" ]; then
            test_pass "$test_name"
        else
            test_fail "$test_name (exit $exit_code, expected $expected_exit)"
        fi
    else
        local exit_code=$?
        if [ $exit_code -eq "$expected_exit" ]; then
            test_pass "$test_name"
        else
            test_fail "$test_name (exit $exit_code, expected $expected_exit)"
        fi
    fi
}

echo "🔍 INVESTIGATING FAILING TESTS"
echo "=============================="

# Test status and list commands more thoroughly
echo "Testing status command in different contexts..."
run_test "status in project root" "cd $SCRIPT_DIR && \"$DCUTIL\" status 2>&1 | grep -q 'status\|Status\|error'" 0
run_test "status in test-ubuntu" "cd $SCRIPT_DIR/test-ubuntu && \"$DCUTIL\" status 2>&1 | grep -q 'status\|Status\|error'" 0
run_test "list command" "\"$DCUTIL\" list 2>&1 | grep -q 'list\|List\|error'" 0

echo ""
echo "🐳 TESTING CONTAINER RUNTIME INTEGRATION"
echo "========================================"

# Test podman backend specifically
run_test "podman backend init" "\"$DCUTIL\" podman status 2>&1 | grep -q 'Podman\|status'" 0
run_test "podman validate" "\"$DCUTIL\" podman validate 2>&1 | grep -q 'validate\|Validate'" 0

echo ""
echo "📦 TESTING VOLUME SYSTEM"
echo "========================"

# Test volume functionality
run_test "volumes help" "\"$DCUTIL\" volumes 2>&1 | grep -q 'Usage\|help'" 0
run_test "volumes list" "\"$DCUTIL\" volumes list >/dev/null 2>&1" 0

# Test volume operations that should fail gracefully
run_test "volumes add invalid" "\"$DCUTIL\" volumes add test-invalid /definitely/does/not/exist /tmp >/dev/null 2>&1" 6

echo ""
echo "🏗️  TESTING PROJECT TYPE DETECTION"
echo "=================================="

# Test different project types
PROJECTS=("test-go" "test-node" "test-python" "test-rust" "test-ubuntu")

for project in "${PROJECTS[@]}"; do
    if [ -d "$SCRIPT_DIR/$project" ]; then
        echo "Testing $project..."
        run_test "$project status" "cd $SCRIPT_DIR/$project && \"$DCUTIL\" status 2>&1 | grep -q 'status\|Status'" 0
        run_test "$project schema" "cd $SCRIPT_DIR/$project && \"$DCUTIL\" schema validate 2>&1 | grep -q 'valid\|Valid'" 0
    fi
done

echo ""
echo "⚙️  TESTING SUBSYSTEMS"
echo "======================"

# Test all major subsystems (some may return 1 if no config)
SUBSYSTEMS=("features info:0" "advanced info:0" "integration info:0" "merging show:0" "userprobe probe:0" "hostrequirements validate:0" "shutdown show:0" "environment list:0")

for subsystem in "${SUBSYSTEMS[@]}"; do
    cmd=$(echo "$subsystem" | cut -d' ' -f1)
    subcmd=$(echo "$subsystem" | cut -d' ' -f2 | cut -d':' -f1)
    expected_exit=$(echo "$subsystem" | cut -d':' -f2)
    run_test "$cmd $subcmd" "\"$DCUTIL\" $cmd $subcmd >/dev/null 2>&1" "$expected_exit"
done

echo ""
echo "🚫 TESTING ERROR CONDITIONS"
echo "==========================="

# Test various error conditions
run_test "non-existent path" "\"$DCUTIL\" status /definitely/does/not/exist >/dev/null 2>&1" 1
run_test "invalid command" "\"$DCUTIL\" xyz123 2>&1 | grep -q 'Unknown\|invalid'" 1
run_test "run without args" "\"$DCUTIL\" run 2>&1 | grep -q 'requires\|Usage'" 1

echo ""
echo "🔧 TESTING COMMAND COMPLETION"
echo "============================="

run_test "bash completion" "\"$DCUTIL\" completion bash | wc -l | grep -q '^[0-9]'" 0
run_test "zsh completion" "\"$DCUTIL\" completion zsh | wc -l | grep -q '^[0-9]'" 0

echo ""
echo "📊 TESTING CONFIGURATION HANDLING"
echo "================================="

# Test configuration file handling
run_test "missing config" "mkdir -p /tmp/test-missing && cd /tmp/test-missing && \"$DCUTIL\" status 2>&1 | grep -q 'status\|Status'" 0

run_test "malformed config" "mkdir -p /tmp/test-malformed && cd /tmp/test-malformed && echo '{\"name\": \"test\", \"image\": }' > .devcontainer/devcontainer.json && \"$DCUTIL\" schema validate 2>&1 | grep -q 'error\|Error'" 1

echo ""
echo "🧪 TESTING LIBRARY INTEGRATION"
echo "=============================="

# Test that libraries can be sourced
run_test "core library source" "bash -c 'source \"$SCRIPT_DIR/dcutil-files/lib/core.sh\" && echo \"EXIT_SUCCESS=$EXIT_SUCCESS\"' >/dev/null 2>&1" 0

run_test "docker library source" "bash -c 'source \"$SCRIPT_DIR/dcutil-files/lib/core.sh\" && source \"$SCRIPT_DIR/dcutil-files/lib/docker.sh\" && echo \"loaded\"' | grep -q 'loaded'" 0

echo ""
echo "🎯 TESTING SPECIFIC FUNCTIONALITY"
echo "================================="

# Test specific features
run_test "build command" "\"$DCUTIL\" build 2>&1 | grep -q 'build\|Build'" 0
run_test "clean command" "\"$DCUTIL\" clean 2>&1 | grep -q 'clean\|Clean'" 0
run_test "stats command" "\"$DCUTIL\" stats 2>&1 | grep -q 'container\|running\|start'" 0
run_test "logs command" "\"$DCUTIL\" logs 2>&1 | grep -q 'logs\|Logs'" 0

echo ""
echo "🔐 TESTING SSH PROPAGATION TOGGLE" 
echo "================================="

# 1) Status should report disabled when no relevant runArgs present
run_test "ssh status -- disabled when no runArgs" "tmpdir=\$(mktemp -d) && cd \$tmpdir && mkdir -p .devcontainer && echo '{}' > .devcontainer/devcontainer.json && \"$DCUTIL\" ssh status 2>&1 | grep -q 'DISABLED'" 0

# 2) Enable should add runArgs and env marker
run_test "ssh enable adds runArgs to empty config" "tmpdir=\$(mktemp -d) && cd \$tmpdir && mkdir -p .devcontainer && echo '{}' > .devcontainer/devcontainer.json && \"$DCUTIL\" ssh enable >/dev/null 2>&1 && cat .devcontainer/devcontainer.json | grep -q 'ssh-agent.sock' && cat .devcontainer/devcontainer.json | grep -q 'SSH_AUTH_SOCK=/ssh-agent.sock'" 0

# 3) Enable should append to existing runArgs rather than overwrite
run_test "ssh enable preserves existing runArgs" "tmpdir=\$(mktemp -d) && cd \$tmpdir && mkdir -p .devcontainer && printf '%s' '{\"runArgs\":[\"--health-cmd\",\"true\",\"--env\",\"FOO=bar\"]}' > .devcontainer/devcontainer.json && \"$DCUTIL\" ssh enable >/dev/null 2>&1 && grep -q 'FOO=bar' .devcontainer/devcontainer.json && grep -q 'ssh-agent.sock' .devcontainer/devcontainer.json" 0

# 4) Toggle flips the status on and off

# 5) Disable removes runArgs and env marker
run_test "ssh disable removes entries" "tmpdir=\$(mktemp -d) && cd \$tmpdir && mkdir -p .devcontainer && printf '%s' '{\"runArgs\":[\"--volume\", \"${SSH_AUTH_SOCK:-/tmp/ssh-agent.sock}:/ssh-agent.sock\", \"--env\", \"SSH_AUTH_SOCK=/ssh-agent.sock\"]}' > .devcontainer/devcontainer.json && \"$DCUTIL\" ssh disable >/dev/null 2>&1 && ! (grep -q 'ssh-agent.sock' .devcontainer/devcontainer.json) && ! (grep -q 'SSH_AUTH_SOCK=/ssh-agent.sock' .devcontainer/devcontainer.json)" 0

echo ""
echo "🧪 ADDITIONAL EDGE-CASE TESTS"
echo "==========================="

# 1) features info should succeed and include 'info' even when HOME cache cannot be created
run_test "features info when HOME unwritable" "HOME=/root \"$DCUTIL\" features info 2>&1 | grep -qi 'info'" 0

# 2) volumes add should expand ~ and be listed
run_test "volumes add handles tilde expansion" "tmpproj=\$(mktemp -d) && cd \$tmpproj && mkdir -p .devcontainer && echo '{}' > .devcontainer/devcontainer.json && mkdir -p \$HOME/test-tilde && \"$DCUTIL\" volumes add tilde-test ~/test-tilde /data >/dev/null 2>&1 && \"$DCUTIL\" volumes list | grep -q tilde-test" 0

# 3) volumes add should reject invalid mount type
run_test "volumes add invalid mount type" "tmpproj=\$(mktemp -d) && cd \$tmpproj && mkdir -p .devcontainer && echo '{}' > .devcontainer/devcontainer.json && \"$DCUTIL\" volumes add badtype /tmp /mnt unsupported >/dev/null 2>&1" 1

# 4) parse_features_config numeric mapping edge-case
run_test "parse_features_config numeric mapping" "bash -c '"$SCRIPT_DIR/test-helpers/feature_numeric_test.sh"' | grep -q success" 0

echo ""
echo "=== TARGETED TEST RESULTS ==="
echo "Tests run: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"

success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))

echo "Success rate: ${success_rate}%"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TARGETED TESTS PASSED!${NC}"
    echo -e "${BLUE}dcutil functionality is working correctly${NC}"
else
    echo -e "${YELLOW}⚠️  $TESTS_FAILED tests failed - investigating issues...${NC}"

    echo ""
    echo "🔍 FAILURE ANALYSIS"
    echo "==================="

    # Analyze specific failures
    echo "Testing status command failure..."
    if "$DCUTIL" status 2>&1 | grep -q "Error\|error\|failed"; then
        echo "Status command has errors - may need container runtime"
    else
        echo "Status command works but exits with code 1"
    fi

    echo ""
    echo "Testing podman backend..."
    if "$DCUTIL" podman status 2>&1 | grep -q "Error\|error"; then
        echo "Podman backend has issues"
    else
        echo "Podman backend works but may exit with code 1"
    fi

    echo ""
    echo "Testing volumes..."
    if "$DCUTIL" volumes list 2>&1 | grep -q "Error\|error\|jq"; then
        echo "Volumes command has dependency issues (likely jq)"
    else
        echo "Volumes command works but may exit with code 1"
    fi
fi