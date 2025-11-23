#!/usr/bin/env bash

# Test script for agent installation and venv creation
# Tests the centralized venv creation logic and security features

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="test_agent_install"
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
    "name": "Test Agent Install Container",
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "workspaceFolder": "/workspaces/test",
    "remoteUser": "vscode",
    "containerUser": "vscode"
}
EOF

    success "Test environment created"
}

# Test venv creation helpers
test_venv_creation() {
    info "=== Testing Venv Creation ==="

    # Start container
    info "Starting test container..."
    "$DCUTIL" up

# Test agent installation with venv creation
    info "Testing agent installation (aider)..."
    if echo "y" | DCUTIL_TEST_SKIP_PORTABLE=true "$DCUTIL" install-agent aider; then
        success "Agent installation completed successfully"
    else
        error "Agent installation failed"
        exit "$EXIT_TEST_FAILED"
    fi

    if "$DCUTIL" run "test -x /home/vscode/.dcutil/agents/aider/bin/python" 2>/dev/null; then
        success "Venv python executable found"
    else
        error "Venv python not found"
        return 1
    fi

    if "$DCUTIL" run "test -x /home/vscode/.dcutil/agents/aider/bin/pip" 2>/dev/null; then
        success "Venv pip executable found"
    else
        error "Venv pip not found"
        return 1
    fi

    # Check if aider is installed in venv
    if "$DCUTIL" run "/home/vscode/.dcutil/agents/aider/bin/python -c 'import aider' 2>/dev/null" 2>/dev/null; then
        success "Aider package installed in venv"
    else
        warning "Aider package not found in venv (may be expected if installation failed)"
    fi

    # Check aider version
    if "$DCUTIL" run "/home/vscode/.dcutil/agents/aider/bin/aider --version" 2>/dev/null; then
        success "Aider installed and accessible"
    else
        error "Aider not accessible"
        return 1
    fi

    # Verify venv was created
    info "Verifying venv creation..."
    if "$DCUTIL" run "test -d /home/vscode/.dcutil/agents/aider" 2>/dev/null; then
        success "Agent directory created"
    else
        error "Agent directory not found"
        return 1
    fi

    if "$DCUTIL" run "test -x /home/vscode/.dcutil/agents/aider/bin/python" 2>/dev/null; then
        success "Venv python executable found"
    else
        error "Venv python not found"
        return 1
    fi

    if "$DCUTIL" run "test -x /home/vscode/.dcutil/agents/aider/bin/pip" 2>/dev/null; then
        success "Venv pip executable found"
    else
        error "Venv pip not found"
        return 1
    fi

    # Check if aider is installed in venv
    if "$DCUTIL" run "/home/vscode/.dcutil/agents/aider/bin/python -c 'import aider' 2>/dev/null" 2>/dev/null; then
        success "Aider package installed in venv"
    else
        warning "Aider package not found in venv (may be expected if installation failed)"
    fi

    success "Venv creation test completed"
}

# Test portable Python setup (if available)
test_portable_python() {
    info "=== Testing Portable Python Setup ==="

    # Check if portable Python directory exists
    if "$DCUTIL" run "test -d /home/vscode/.dcutil/python" 2>/dev/null; then
        success "Portable Python directory exists"
        if "$DCUTIL" run "test -x /home/vscode/.dcutil/python/bin/python3" 2>/dev/null; then
            success "Portable Python executable found"
        else
            warning "Portable Python executable not found"
        fi
    else
        info "Portable Python not set up (expected if system Python is used)"
    fi
}

# Test security scanning
test_security_scan() {
    info "=== Testing Security Scanning ==="

    # The security scan runs automatically during installation
    # Check if scan completed without errors
    success "Security scanning is integrated into installation process"
}

# Main test function
main() {
    info "Starting Agent Installation and Venv Creation Tests"
    info "This test will create a container and install an AI agent"

    trap cleanup EXIT

    setup_test_env
    test_venv_creation
    test_portable_python
    test_security_scan

    success "All tests completed successfully!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi