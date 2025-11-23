#!/usr/bin/env bash

# Test script for validating npm-based agent installations
# This tests what would work with npm packages vs current pip packages

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="test_npm_validation"
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

    # Create a devcontainer configuration with both Python and Node.js
    mkdir -p .devcontainer
    cat > .devcontainer/devcontainer.json << 'EOF'
{
    "name": "NPM Agent Validation Test",
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

# Test npm availability and basic functionality
test_npm_basics() {
    info "=== Testing NPM Availability and Basic Functionality ==="
    
    # Start container
    "$DCUTIL" up
    
    # Check if npm is available
    if "$DCUTIL" run "command -v npm" 2>/dev/null; then
        success "npm is available in container"
        
        # Test npm version
        if version=$("$DCUTIL" run "npm --version" 2>/dev/null); then
            success "npm version: $version"
        else
            error "Could not get npm version"
            "$DCUTIL" down
            return 1
        fi
    else
        error "npm is not available in container"
        "$DCUTIL" down
        return 1
    fi
    
    # Check if npx is available (for testing packages without installation)
    if "$DCUTIL" run "command -v npx" 2>/dev/null; then
        success "npx is available in container"
    else
        warning "npx is not available in container"
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return 0
}

# Test current pip-based installations to compare
test_current_pip_agents() {
    info "=== Testing Current Pip-based Agent Installations ==="
    
    local pip_agents=("aider" "qwen-cli")
    local successful=()
    local failed=()
    
    for agent in "${pip_agents[@]}"; do
        info "Testing current pip installation for $agent..."
        
        # Start container
        "$DCUTIL" up
        
        if DCUTIL_TEST_SKIP_PORTABLE=true DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent "$agent" 2>/dev/null; then
            success "$agent pip installation succeeded"
            successful+=("$agent")
        else
            error "$agent pip installation failed"
            failed+=("$agent")
        fi
        
        # Clean up for next test
        "$DCUTIL" down
    done
    
    info "Pip agent results: ${#successful[@]} successful, ${#failed[@]} failed"
    info "Successful: ${successful[*]}"
    info "Failed: ${failed[*]}"
}

# Test npm-based installations that currently work
test_current_npm_agents() {
    info "=== Testing Current NPM-based Agent Installations ==="
    
    local npm_agents=("copilot-cli" "cody" "tabnine")
    local successful=()
    local failed=()
    
    for agent in "${npm_agents[@]}"; do
        info "Testing current npm installation for $agent..."
        
        # Start container
        "$DCUTIL" up
        
        if DCUTIL_TEST_SKIP_PORTABLE=true DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent "$agent" 2>/dev/null; then
            success "$agent npm installation succeeded"
            successful+=("$agent")
        else
            error "$agent npm installation failed"
            failed+=("$agent")
        fi
        
        # Clean up for next test
        "$DCUTIL" down
    done
    
    info "NPM agent results: ${#successful[@]} successful, ${#failed[@]} failed"
    info "Successful: ${successful[*]}"
    info "Failed: ${failed[*]}"
}

# Test npm package availability for pip-based agents
test_npm_alternatives() {
    info "=== Testing NPM Package Availability for Current Pip Agents ==="
    
    # Start container
    "$DCUTIL" up
    
    # Test if npm packages exist for pip-based agents by trying npx
    local agents_to_test=(
        "aider-chat:Aider (via npx - may work without installation)"
        # Note: The following are hypothetical packages, testing if npx can find them
        # "qwen-cli:Qwen CLI"
        # "@google/gemini:Google Gemini" 
        # "@anthropic/claude:Claude"
        # "@openai/cli:OpenAI CLI"
    )
    
    for agent_entry in "${agents_to_test[@]}"; do
        IFS=':' read -r package agent_desc <<< "$agent_entry"
        info "Testing availability of $package ($agent_desc)..."
        
        # Try npx to see if package exists (this doesn't install, just checks)
        if "$DCUTIL" run "timeout 10 npx $package --help" 2>/dev/null; then
            success "$package appears to be available via npx"
        elif "$DCUTIL" run "timeout 10 npm search $package --json | grep -q $package" 2>/dev/null; then
            success "$package appears to be available in npm registry"
        else
            warning "$package may not be available via npm/npx"
        fi
    done
    
    # Clean up
    "$DCUTIL" down
}

# Summary and recommendations
show_recommendations() {
    info "=== Recommendations for NPM Standardization ==="
    
    info "1. Some agents like aider might already work with npm (aider-chat package exists)"
    info "2. High-value targets for npm packages:"
    echo "   - opencode: Currently uses high-risk curl|bash, would be much safer with npm"
    echo "   - qwen-cli, gemini, claude-cli, openai-cli: Could provide better consistency"
    info "3. For packages that don't have npm equivalents, consider:"
    echo "   - Working with maintainers to create npm packages"
    echo "   - Using npx for execution without installation"
    echo "   - Creating thin npm wrappers around pip packages"
    info "4. Benefits of standardization:"
    echo "   - Single installation method to maintain"
    echo "   - More consistent security model"
    echo "   - Elimination of high-risk curl|bash installations"
}

# Main test function
main() {
    info "Starting NPM Agent Installation Validation Tests"
    info "Validating current state and potential for npm standardization"

    trap cleanup EXIT

    setup_test_env
    test_npm_basics
    test_current_pip_agents
    test_current_npm_agents
    test_npm_alternatives
    show_recommendations

    success "NPM validation tests completed!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi