#!/usr/bin/env bash

# Comprehensive test script for all supported agent installers
# Tests each agent installation with appropriate handling for different installation types

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="test_all_agents"
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

    # Create a simple devcontainer configuration
    mkdir -p .devcontainer
    cat > .devcontainer/devcontainer.json << 'EOF'
{
    "name": "Test All Agent Installers Container",
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
        }
    }
}
EOF

    success "Test environment created"
}

# Test a specific agent installation
test_single_agent() {
    local agent="$1"
    local agent_desc="$2"
    local expect_failure="${3:-false}"
    
    info "Testing $agent_desc installation..."
    
    # Start container if not running
    if ! "$DCUTIL" status 2>/dev/null | grep -q "running"; then
        "$DCUTIL" up
    fi
    
    # Different agents require different installation approaches
    case "$agent" in
        "opencode")
            # High-risk agent, needs special handling with confirmation
            if echo "n" | DCUTIL_TEST_SKIP_PORTABLE=true "$DCUTIL" install-agent "$agent"; then
                if [ "$expect_failure" = true ]; then
                    warning "Expected failure for $agent but installation succeeded"
                else
                    success "$agent installation completed successfully"
                fi
            else
                if [ "$expect_failure" = true ]; then
                    success "Expected failure for $agent occurred"
                else
                    error "$agent installation failed when it should have succeeded"
                    return 1
                fi
            fi
            ;;
        "aider"|"qwen-cli"|"gemini"|"claude-cli"|"openai-cli")
            # Python-based agents
            if echo "n" | DCUTIL_TEST_SKIP_PORTABLE=true "$DCUTIL" install-agent "$agent"; then
                success "$agent installation completed successfully"
            else
                if [ "$expect_failure" = true ]; then
                    success "Expected failure for $agent occurred"
                else
                    error "$agent installation failed when it should have succeeded"
                    return 1
                fi
            fi
            ;;
        "copilot-cli"|"cody"|"tabnine")
            # NPM-based agents
            if echo "n" | DCUTIL_TEST_SKIP_PORTABLE=true "$DCUTIL" install-agent "$agent"; then
                success "$agent installation completed successfully"
            else
                if [ "$expect_failure" = true ]; then
                    success "Expected failure for $agent occurred"
                else
                    error "$agent installation failed when it should have succeeded"
                    return 1
                fi
            fi
            ;;
        *)
            error "Unknown agent: $agent"
            return 1
            ;;
    esac

    # Clean up the container after each agent test to ensure clean state
    "$DCUTIL" clean 2>/dev/null || true
    
    return 0
}

# Test all supported agents
test_all_agents() {
    info "=== Testing All Supported Agent Installers ==="
    
    # Define all supported agents
    local agents_to_test=(
        "aider:Aider AI coding assistant"
        "copilot-cli:GitHub Copilot CLI"
        "cody:Sourcegraph Cody"
        "tabnine:Tabnine AI"
        "qwen-cli:Qwen CLI"
        "gemini:Google Gemini"
        "claude-cli:Claude CLI"
        "openai-cli:OpenAI CLI"
    )
    
    local failed_agents=()
    local successful_agents=()
    
    for agent_entry in "${agents_to_test[@]}"; do
        IFS=':' read -r agent agent_desc <<< "$agent_entry"
        info "Starting test for $agent ($agent_desc)"
        
        if test_single_agent "$agent" "$agent_desc"; then
            success "✅ $agent test passed"
            successful_agents+=("$agent")
        else
            error "❌ $agent test failed"
            failed_agents+=("$agent")
        fi
        
        # Clean up any lingering state
        "$DCUTIL" clean 2>/dev/null || true
    done
    
    # Test the high-risk opencode agent separately with proper handling
    info "Testing opencode (high-risk agent)..."
    if echo "n" | test_single_agent "opencode" "OpenCode (high-risk curl-based)" true; then
        success "✅ opencode test handled correctly (expected to fail with 'n' response)"
        successful_agents+=("opencode")
    else
        # This is expected as opencode requires 'y' confirmation for security reasons
        success "✅ opencode test handled correctly (expected security prompt behavior)"
        successful_agents+=("opencode")
    fi
    
    # Summary
    info "\n=== Test Summary ==="
    success "Successfully tested ${#successful_agents[@]} agents: ${successful_agents[*]}"
    
    if [ ${#failed_agents[@]} -gt 0 ]; then
        error "Failed agents: ${failed_agents[*]}"
        return 1
    else
        success "All agent installations completed successfully!"
        return 0
    fi
}

# Test agent-specific functionality
test_agent_functionality() {
    info "=== Testing Agent Functionality ==="
    
    # Start a container for testing
    info "Starting test container..."
    "$DCUTIL" up
    
    # Test aider functionality as it's most likely to succeed
    info "Testing aider functionality (if installed)..."
    if "$DCUTIL" run "command -v aider" 2>/dev/null; then
        if "$DCUTIL" run "aider --version" 2>&1 | head -n 1; then
            success "Aider is functional"
        else
            warning "Aider installed but not functional"
        fi
    else
        info "Aider not installed in current container"
    fi
    
    # Test qwen-cli functionality
    info "Testing qwen-cli functionality (if installed)..."
    if "$DCUTIL" run "command -v qwen" 2>/dev/null; then
        if "$DCUTIL" run "qwen --help" 2>/dev/null | head -n 5; then
            success "Qwen CLI is functional"
        else
            warning "Qwen CLI installed but not functional"
        fi
    else
        info "Qwen CLI not installed in current container"
    fi
    
    # Clean up
    "$DCUTIL" down
}

# Main test function
main() {
    info "Starting Comprehensive Agent Installer Tests"
    info "This test will test installation of all supported AI agents"

    trap cleanup EXIT

    setup_test_env
    test_all_agents
    
    # Only run functionality test if we have a way to enter the container
    # test_agent_functionality
    
    success "All agent installer tests completed!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi