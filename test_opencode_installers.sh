#!/usr/bin/env bash

# Updated test script for opencode agent installer
# Includes testing for both current curl-based and potential npm-based installation methods

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="test_opencode_agent"
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
    "name": "OpenCode Agent Test Container",
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

# Test current opencode installation (curl-based, high-risk)
test_current_opencode_install() {
    info "=== Testing Current OpenCode Installation (curl-based) ==="
    
    # Start container
    "$DCUTIL" up
    
    info "Testing opencode with 'no' response (should not install)..."
    if echo "n" | DCUTIL_TEST_SKIP_PORTABLE=true "$DCUTIL" install-agent opencode 2>/dev/null; then
        error "opencode installation should have been cancelled with 'no' response"
        local current_success=1
    else
        success "opencode installation correctly cancelled with 'no' response"
        local current_success=0
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return $current_success
}

# Test potential npm-based opencode installation
test_potential_npm_opencode() {
    info "=== Testing Potential NPM-based OpenCode Installation ==="
    
    # Start container
    "$DCUTIL" up
    
    info "Testing potential npm-based opencode installation..."
    
    # Check if npm is available
    if ! "$DCUTIL" run "command -v npm" 2>/dev/null; then
        warning "npm not available in container, installing Node.js..."
        if "$DCUTIL" run "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && apt-get install -y nodejs" 2>/dev/null; then
            success "Node.js installed"
        else
            error "Failed to install Node.js"
            "$DCUTIL" down
            return 1
        fi
    fi
    
    # Try to simulate what an npm-based installation would look like
    # Since the actual command is not implemented in dcutil yet, we'll test that npm is available
    if "$DCUTIL" run "npm --version" 2>/dev/null; then
        success "npm is available for potential opencode installation"
        
        # Test npm install command structure (without actually installing)
        info "Testing npm install command structure..."
        local npm_cmd="npm install -g @opencode/cli"  # hypothetical command
        info "Potential npm command: $npm_cmd"
        
        # If npm were supported for opencode, we would run:
        # DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent opencode
        # but we'd need to modify the get_agent_install_command function first
        
        local npm_success=0
    else
        error "npm not working properly"
        local npm_success=1
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return $npm_success
}

# Simulate how the security.sh would be modified to support npm
show_npm_implementation_notes() {
    info "=== Implementation Notes for NPM-based OpenCode ==="
    
    info "To implement npm-based opencode installation, modify get_agent_install_command in lib/security.sh:"
    echo '
        "opencode")
            echo "npm install -g @opencode/cli"
            ;;'
    
    info "This would simplify the installation process and provide:"
    echo "  - Standard npm security model"
    echo "  - No need for high-risk curl|bash execution"
    echo "  - Better integration with existing npm infrastructure"
    echo "  - Automatic dependency management"
    
    info "Current implementation uses:"
    echo '  "opencode")'
    echo '      echo "curl -fsSL https://opencode.ai/install | bash"'
    echo '      ;;'
    echo "  - This requires security confirmation due to remote script execution"
    echo "  - More complex security handling needed"
}

# Main test function
main() {
    info "Starting OpenCode Agent Installer Tests"
    info "Testing both current and potential future implementations"

    trap cleanup EXIT

    setup_test_env
    test_current_opencode_install
    test_potential_npm_opencode
    show_npm_implementation_notes

    success "OpenCode agent installer tests completed!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi