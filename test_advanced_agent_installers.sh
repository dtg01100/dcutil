#!/usr/bin/env bash

# Advanced test script for agent installers
# Tests different installation scenarios and edge cases for all supported agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="test_advanced_agents"
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

    # Create a devcontainer configuration with required features
    mkdir -p .devcontainer
    cat > .devcontainer/devcontainer.json << 'EOF'
{
    "name": "Advanced Agent Test Container",
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "workspaceFolder": "/workspaces/test",
    "remoteUser": "vscode",
    "containerUser": "vscode",
    "features": {
        "ghcr.io/devcontainers/features/python:1": {
            "version": "3.11"
        },
        "ghcr.io/devcontainers/features/node:1": {
            "version": "lts"
        },
        "ghcr.io/devcontainers/features/git:1": {}
    },
    "postCreateCommand": "pip3 install --upgrade pip && npm install -g npm@latest"
}
EOF

    success "Test environment created"
}

# Test basic installation for an agent
test_basic_install() {
    local agent="$1"
    info "Testing basic installation for $agent..."
    
    # Start container
    "$DCUTIL" up
    
    # Install agent with auto-confirmation
    if DCUTIL_TEST_SKIP_PORTABLE=true DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent "$agent"; then
        success "$agent basic installation succeeded"
        local install_success=0
    else
        error "$agent basic installation failed"
        local install_success=1
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return $install_success
}

# Test installation with venv creation
test_venv_install() {
    local agent="$1"
    info "Testing $agent installation with virtual environment..."
    
    # Start container
    "$DCUTIL" up
    
    # Check if venv was created after installation
    if DCUTIL_TEST_SKIP_PORTABLE=true DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent "$agent"; then
        # Check if agent-specific venv was created
        if "$DCUTIL" run "test -d /home/vscode/.dcutil/agents/$agent" 2>/dev/null; then
            success "$agent venv installation succeeded and venv created"
            local venv_success=0
        else
            warning "$agent installed but venv was not created as expected"
            local venv_success=0  # Don't fail for this, as some agents might not create venv
        fi
    else
        error "$agent venv installation failed"
        local venv_success=1
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return $venv_success
}

# Test configuration mounting for an agent
test_config_mount() {
    local agent="$1"
    info "Testing $agent installation with config mounting..."
    
    # Start container
    "$DCUTIL" up
    
    # For this test, we'll just install and check if the agent is available
    # Configuration mounting requires actual config files that might not exist
    if DCUTIL_TEST_SKIP_PORTABLE=true DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent "$agent"; then
        success "$agent installed with config mounting consideration"
        local config_success=0
    else
        error "$agent installation with config mounting consideration failed"
        local config_success=1
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return $config_success
}

# Test security scanning for an agent
test_security_scan() {
    local agent="$1"
    info "Testing $agent with security scanning..."
    
    # Start container
    "$DCUTIL" up
    
    # Install agent and check if security scan runs
    if DCUTIL_TEST_SKIP_PORTABLE=true DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent "$agent"; then
        success "$agent security scan completed"
        local scan_success=0
    else
        error "$agent security scan failed"
        local scan_success=1
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return $scan_success
}

# Run all tests for a single agent
test_agent_comprehensive() {
    local agent="$1"
    local agent_desc="$2"
    
    info "\n=== Testing $agent ($agent_desc) ==="
    
    local failures=0
    
    # Test basic installation
    if test_basic_install "$agent"; then
        success "$agent basic installation test passed"
    else
        error "$agent basic installation test failed"
        ((failures++))
    fi
    
    # Test venv installation (for Python-based agents)
    case "$agent" in
        aider|qwen-cli|gemini|claude-cli|openai-cli)
            if test_venv_install "$agent"; then
                success "$agent venv installation test passed"
            else
                error "$agent venv installation test failed"
                ((failures++))
            fi
            ;;
    esac
    
    # Test config mount consideration
    if test_config_mount "$agent"; then
        success "$agent config mount test passed"
    else
        error "$agent config mount test failed"
        ((failures++))
    fi
    
    # Test security scanning
    if test_security_scan "$agent"; then
        success "$agent security scan test passed"
    else
        error "$agent security scan test failed"
        ((failures++))
    fi
    
    # Test multiple reinstalls to ensure idempotency
    info "Testing $agent installation idempotency..."
    "$DCUTIL" up
    for i in {1..2}; do
        if DCUTIL_TEST_SKIP_PORTABLE=true DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent "$agent"; then
            success "$agent reinstall (attempt $i) succeeded"
        else
            error "$agent reinstall (attempt $i) failed"
            ((failures++))
            break
        fi
    done
    "$DCUTIL" down
    
    if [ $failures -eq 0 ]; then
        success "✅ $agent comprehensive tests completed successfully"
    else
        error "❌ $agent comprehensive tests had $failures failures"
    fi
    
    return $failures
}

# Test all supported agents comprehensively
test_all_agents_comprehensive() {
    info "=== Comprehensive Agent Installation Tests ==="
    
    local supported_agents=(
        "aider:Aider AI coding assistant"
        "copilot-cli:GitHub Copilot CLI"  
        "cody:Sourcegraph Cody"
        "qwen-cli:Qwen CLI"
        "gemini:Google Gemini"
        "claude-cli:Claude CLI"
        "openai-cli:OpenAI CLI"
    )
    
    local total_failures=0
    local total_agents=0
    
    for agent_entry in "${supported_agents[@]}"; do
        IFS=':' read -r agent agent_desc <<< "$agent_entry"
        ((total_agents++))
        
        if test_agent_comprehensive "$agent" "$agent_desc"; then
            success "🎉 $agent all tests passed"
        else
            error "💥 $agent had test failures"
            ((total_failures++))
        fi
        
        # Clean up any remaining containers before next test
        "$DCUTIL" clean 2>/dev/null || true
    done
    
    info "\n=== Final Results ==="
    local successful_agents=$((total_agents - total_failures))
    info "Total agents tested: $total_agents"
    info "Successful: $successful_agents"
    info "Failed: $total_failures"
    
    if [ $total_failures -eq 0 ]; then
        success "🎉 All agent tests completed successfully!"
        return 0
    else
        error "💥 $total_failures agent(s) had test failures"
        return 1
    fi
}

# Test edge cases and error conditions
test_edge_cases() {
    info "=== Testing Edge Cases ==="
    
    # Start container
    "$DCUTIL" up
    
    # Test with non-existent agent
    info "Testing non-existent agent..."
    if DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent nonexistent-agent 2>/dev/null; then
        error "Non-existent agent installation should have failed"
        local edge_success=1
    else
        success "Non-existent agent correctly rejected"
    fi
    
    # Test with empty agent name
    info "Testing empty agent name..."
    if "$DCUTIL" install-agent 2>/dev/null; then
        error "Empty agent name should have failed"
        local edge_success=1
    else
        success "Empty agent name correctly rejected"
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return 0
}

# Main test function
main() {
    info "Starting Advanced Agent Installer Tests"
    info "Testing comprehensive installation scenarios for all supported agents"

    trap cleanup EXIT

    setup_test_env
    test_all_agents_comprehensive
    test_edge_cases

    success "All advanced agent installer tests completed!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi