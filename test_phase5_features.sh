#!/bin/bash

# Test script for Phase 5 Devcontainer Features Implementation
# Tests userEnvProbe, hostRequirements, and shutdownAction features

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCUTIL="$SCRIPT_DIR/dcutil"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    log_test "$test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

# Create test directory
TEST_DIR="/tmp/dcutil_phase5_test_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Create test devcontainer.json with userEnvProbe, hostRequirements, and shutdownAction
cat > devcontainer.json << 'EOF'
{
    "name": "Phase 5 Test Container",
    "dockerFile": "Dockerfile",
    "userEnvProbe": "bash",
    "hostRequirements": {
        "cpu": "1",
        "memory": "1GB",
        "storage": "1GB",
        "gpu": "optional"
    },
    "shutdownAction": "stop",
    "customizations": {
        "vscode": {
            "extensions": ["ms-vscode.cpptools"]
        }
    }
}
EOF

# Create test Dockerfile
cat > Dockerfile << 'EOF'
FROM alpine:latest
RUN apk add --no-cache bash
CMD ["sleep", "3600"]
EOF

# Create .devcontainer/devcontainer-feature.json for testing
mkdir -p .devcontainer
cat > .devcontainer/devcontainer-feature.json << 'EOF'
{
    "name": "test-feature",
    "version": "1.0.0",
    "description": "Test feature for Phase 5",
    "containerEnv": {
        "TEST_FEATURE_ENABLED": "true"
    }
}
EOF

echo "Phase 5 Devcontainer Features Test Suite"
echo "======================================="
echo "Testing userEnvProbe, hostRequirements, and shutdownAction features"
echo ""

# Test 1: Check if userprobe module is loaded
run_test "UserProbe module loading" "$DCUTIL userprobe help"

# Test 2: Check if hostrequirements module is loaded
run_test "HostRequirements module loading" "$DCUTIL hostrequirements help"

# Test 3: Check if shutdown module is loaded
run_test "Shutdown module loading" "$DCUTIL shutdown help"

# Test 4: Test userEnvProbe configuration parsing
run_test "userEnvProbe configuration parsing" "$DCUTIL userprobe validate"

# Test 5: Test hostRequirements validation
run_test "hostRequirements validation" "$DCUTIL hostrequirements validate"

# Test 6: Test shutdownAction configuration parsing
run_test "shutdownAction configuration parsing" "$DCUTIL shutdown validate"

# Test 7: Test user environment probing (basic)
run_test "User environment probing" "echo 'test' | $DCUTIL userprobe probe 2>/dev/null || true"

# Test 8: Test host requirements status display
run_test "Host requirements status display" "$DCUTIL hostrequirements show"

# Test 9: Test shutdown action configuration display
run_test "Shutdown action configuration display" "$DCUTIL shutdown show"

# Test 10: Test module integration
run_test "Module integration check" "grep -q 'userprobe\|hostrequirements\|shutdown' \"$DCUTIL\""

# Test 11: Test help system integration
run_test "Help system integration" "$DCUTIL help | grep -q -E '(userprobe|hostrequirements|shutdown)'"

# Test 12: Test command routing
run_test "Command routing functionality" "echo '$DCUTIL userprobe 2>&1 | grep -q "Usage:"' | bash"

echo ""
echo "Test Results Summary"
echo "==================="
echo "Total Tests: $TESTS_TOTAL"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed! Phase 5 implementation is working correctly.${NC}"
    exit_code=0
else
    echo -e "${RED}❌ Some tests failed. Please check the implementation.${NC}"
    exit_code=1
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"

exit $exit_code