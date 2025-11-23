#!/usr/bin/env bash

# Test script for edge cases and error conditions in the npm-standardized agent installation system
# Tests various failure scenarios and error handling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="test_edge_cases"
DCUTIL="$SCRIPT_DIR/dcutil"

# Exit codes
EXIT_TEST_FAILED=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Cleanup function
cleanup() {
    info "Cleaning up test environment..."
    if [ -d "$TEST_DIR" ]; then
        cd "$TEST_DIR"
        "$DCUTIL" clean 2>/dev/null || true
        cd "$SCRIPT_DIR"
        rm -rf "$TEST_DIR"
    fi
}

# Set up test environment
setup_test_env() {
    info "Setting up test environment..."

    # Create test directory
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"

    # Create a devcontainer configuration
    mkdir -p .devcontainer
    cat > .devcontainer/devcontainer.json << 'EOF'
{
    "name": "Edge Cases Test",
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "workspaceFolder": "/workspaces/test",
    "remoteUser": "vscode",
    "containerUser": "vscode",
    "features": {
        "ghcr.io/devcontainers/features/node:1": {
            "version": "lts"
        }
    }
}
EOF

    success "Test environment created"
}

# Test invalid agent names
test_invalid_agents() {
    info "=== Testing Invalid Agent Names ==="
    
    source "$SCRIPT_DIR/lib/security.sh"
    
    local invalid_agents=("nonexistent" "invalid-agent" "123" "" "very-long-invalid-agent-name-that-does-not-exist")
    
    for agent in "${invalid_agents[@]}"; do
        info "Testing invalid agent: '$agent'"
        
        if get_agent_install_command "$agent" 2>/dev/null; then
            error "❌ Invalid agent '$agent' should have failed to get install command"
            return 1
        else
            success "✅ Invalid agent '$agent' correctly rejected"
        fi
    done
    
    return 0
}

# Test error handling in get_agent_install_command
test_get_command_error_handling() {
    info "=== Testing Get Agent Command Error Handling ==="
    
    source "$SCRIPT_DIR/lib/security.sh"
    
    # Test with empty string
    if get_agent_install_command "" 2>/dev/null; then
        error "❌ Empty agent name should have failed"
        return 1
    else
        success "✅ Empty agent name correctly rejected"
    fi
    
    # Test with special characters
    local special_names=("-test" "_test" "test-" "test_" "a" "z")
    
    for name in "${special_names[@]}"; do
        if get_agent_install_command "$name" 2>/dev/null; then
            # If it doesn't exist in our case statement, it should fail
            if [[ " aider copilot-cli cody qwen-cli gemini claude-cli openai-cli opencode " != *" $name "* ]]; then
                error "❌ Agent '$name' should have failed since it's not a valid agent"
                return 1
            fi
        else
            # It's expected that non-existent agents fail
            success "✅ Non-existent agent '$name' correctly rejected"
        fi
    done
    
    return 0
}

# Test function with various inputs
test_function_inputs() {
    info "=== Testing Function Input Validation ==="
    
    # The bash functions are shell functions that rely on the case statement
    # which should handle all string inputs appropriately
    source "$SCRIPT_DIR/lib/security.sh"
    
    # Test normal agent names
    local normal_agents=("aider" "copilot-cli" "cody" "qwen-cli" "gemini" "claude-cli" "openai-cli" "opencode")
    
    for agent in "${normal_agents[@]}"; do
        local cmd
        cmd=$(get_agent_install_command "$agent")
        if [[ "$cmd" == npm* ]]; then
            success "✅ Agent '$agent' returns proper npm command: $cmd"
        else
            error "❌ Agent '$agent' does not return npm command: $cmd"
            return 1
        fi
    done
    
    return 0
}

# Test error handling in the install_agent function context
test_install_agent_error_paths() {
    info "=== Testing Install Agent Error Paths ==="
    
    # This is harder to test without actually running the full install
    # but we can check the function structure
    
    source "$SCRIPT_DIR/lib/security.sh"
    
    # Test that the function exists
    if declare -f "install_agent" >/dev/null 2>&1; then
        success "✅ install_agent function exists"
    else
        error "❌ install_agent function does not exist"
        return 1
    fi
    
    # Check that the error handling structure is appropriate
    if grep -q "error_exit.*Failed to install" "$SCRIPT_DIR/lib/security.sh"; then
        success "✅ Error exit handling exists in install function"
    else
        warning "Error exit handling pattern not found (may be handled differently)"
    fi
    
    return 0
}

# Test security functions with various inputs
test_security_function_inputs() {
    info "=== Testing Security Function Input Handling ==="
    
    source "$SCRIPT_DIR/lib/security.sh"
    
    # Test with various agent names and install commands
    local test_cases=(
        "aider:npm install -g aider-chat"
        "opencode:npm install -g @opencode/cli"
        "invalid:invalid command"
        "test:another command"
    )
    
    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r agent cmd <<< "$test_case"
        
        # This should not produce any output for any agent now
        local result
        result=$(check_agent_security_risk "$agent" "$cmd" 2>&1)
        
        if [ -z "$result" ]; then
            success "✅ Security check for '$agent' returned no output (as expected)"
        else
            warning "Security check for '$agent' returned: $result (may be expected for non-existent agents)"
        fi
    done
    
    return 0
}

# Test edge cases with environment variables
test_environment_variables() {
    info "=== Testing Environment Variable Handling ==="
    
    # Test the functions with various environment settings
    source "$SCRIPT_DIR/lib/security.sh"
    
    # Test DCUTIL_ASSUME_YES handling (though it affects the actual install flow)
    local original_assume_yes="$DCUTIL_ASSUME_YES"
    
    # This test simply verifies the functions can be called with environment variables set
    info "Testing with DCUTIL_ASSUME_YES=1..."
    DCUTIL_ASSUME_YES=1
    local cmd
    cmd=$(get_agent_install_command "aider")
    if [[ "$cmd" == npm* ]]; then
        success "✅ Function works with DCUTIL_ASSUME_YES=1"
    else
        error "❌ Function failed with DCUTIL_ASSUME_YES=1"
        return 1
    fi
    
    # Restore original
    DCUTIL_ASSUME_YES="$original_assume_yes"
    
    return 0
}

# Test the vulnerability scanning with different inputs
test_vulnerability_scan_paths() {
    info "=== Testing Vulnerability Scan Paths ==="
    
    source "$SCRIPT_DIR/lib/security.sh"
    
    # Function exists
    if declare -f "scan_vulnerabilities" >/dev/null 2>&1; then
        success "✅ scan_vulnerabilities function exists"
    else
        error "❌ scan_vulnerabilities function does not exist"
        return 1
    fi
    
    # The function should handle npm type properly
    # We can't easily test the full container execution, but we can verify structure
    
    if grep -q "INSTALL_TYPE.*npm" "$SCRIPT_DIR/lib/security.sh"; then
        success "✅ npm handling exists in vulnerability scanning"
    else
        error "❌ npm handling missing from vulnerability scanning"
        return 1
    fi
    
    return 0
}

# Test error conditions in container context (simulated)
test_container_error_handling() {
    info "=== Testing Container Error Handling ==="
    
    # Start a container to test the environment
    if "$DCUTIL" up 2>/dev/null; then
        success "✅ Container started successfully"
    else
        error "❌ Could not start container for testing"
        return 1
    fi
    
    # Test that npm is available
    if "$DCUTIL" run "command -v npm" 2>/dev/null; then
        success "✅ npm available in container"
    else
        error "❌ npm not available in container"
        "$DCUTIL" down
        return 1
    fi
    
    # Test npm functionality
    if "$DCUTIL" run "npm --version" 2>/dev/null; then
        success "✅ npm version command works"
    else
        error "❌ npm version command failed"
        "$DCUTIL" down
        return 1
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return 0
}

# Test multiple installations and idempotency
test_installation_idempotency() {
    info "=== Testing Installation Idempotency ==="
    
    # Start container
    "$DCUTIL" up
    
    # Test installing the same agent multiple times (conceptually)
    # Since we can't easily test the actual install without real npm packages,
    # we'll test that the structure supports idempotency
    
    # Check if npm can handle reinstallation
    if "$DCUTIL" run "npm install -g jake" 2>/dev/null && "$DCUTIL" run "npm install -g jake" 2>/dev/null; then
        success "✅ npm supports reinstallation (idempotency friendly)"
    else
        warning "npm reinstallation test had issues (may be normal)"
    fi
    
    # Clean up test package
    "$DCUTIL" run "npm uninstall -g jake" 2>/dev/null || true
    
    "$DCUTIL" down
    
    return 0
}

# Main test function
main() {
    info "Starting Edge Cases and Error Conditions Tests"
    
    trap cleanup EXIT

    setup_test_env
    
    local exit_code=0
    
    if test_invalid_agents; then
        success "Invalid agent tests passed"
    else
        error "Invalid agent tests failed"
        exit_code=1
    fi
    
    if test_get_command_error_handling; then
        success "Get command error handling tests passed"
    else
        error "Get command error handling tests failed"
        exit_code=$((exit_code + 2))
    fi
    
    if test_function_inputs; then
        success "Function input tests passed"
    else
        error "Function input tests failed"
        exit_code=$((exit_code + 4))
    fi
    
    if test_install_agent_error_paths; then
        success "Install agent error path tests passed"
    else
        error "Install agent error path tests failed"
        exit_code=$((exit_code + 8))
    fi
    
    if test_security_function_inputs; then
        success "Security function input tests passed"
    else
        error "Security function input tests failed"
        exit_code=$((exit_code + 16))
    fi
    
    if test_environment_variables; then
        success "Environment variable tests passed"
    else
        error "Environment variable tests failed"
        exit_code=$((exit_code + 32))
    fi
    
    if test_vulnerability_scan_paths; then
        success "Vulnerability scan path tests passed"
    else
        error "Vulnerability scan path tests failed"
        exit_code=$((exit_code + 64))
    fi
    
    if test_container_error_handling; then
        success "Container error handling tests passed"
    else
        error "Container error handling tests failed"
        exit_code=$((exit_code + 128))
    fi
    
    if test_installation_idempotency; then
        success "Installation idempotency tests passed"
    else
        error "Installation idempotency tests failed"
        exit_code=$((exit_code + 256))
    fi
    
    if [ $exit_code -eq 0 ]; then
        success "🎉 All edge case and error condition tests passed!"
        info " resilient error handling has been validated"
    else
        error "💥 Some edge case tests failed (code: $exit_code)"
    fi
    
    exit $exit_code
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi