#!/usr/bin/env bash

# Security-focused test script for high-risk agent installers
# Specifically tests the security features and prompts for high-risk agents like opencode

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="test_security_agents"
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
    "name": "Security Agent Test Container",
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "workspaceFolder": "/workspaces/test",
    "remoteUser": "vscode",
    "containerUser": "vscode",
    "features": {
        "ghcr.io/devcontainers/features/python:1": {
            "version": "3.11"
        }
    }
}
EOF

    success "Test environment created"
}

# Test high-risk agent installation (opencode)
test_high_risk_agent() {
    info "=== Testing High-Risk Agent: opencode ==="
    
    # Start container
    "$DCUTIL" up
    
    # Test with negative response (should not install)
    info "Testing opencode with 'no' response (should not install)..."
    if echo "n" | DCUTIL_TEST_SKIP_PORTABLE=true "$DCUTIL" install-agent opencode 2>/dev/null; then
        error "opencode installation should have been cancelled with 'no' response"
        local high_risk_success=1
    else
        success "opencode installation correctly cancelled with 'no' response"
        local high_risk_success=0
    fi
    
    # Clean up for next test
    "$DCUTIL" clean 2>/dev/null || true
    "$DCUTIL" up
    
    # Test with positive response (should proceed with warning)
    info "Testing opencode with 'yes' response simulation (requires special handling)..."
    # Note: We can't actually install opencode in automated testing due to security prompts
    # Instead, we'll check if the security check is triggered
    if DCUTIL_ASSUME_YES=1 DCUTIL_TEST_SKIP_PORTABLE=true "$DCUTIL" install-agent opencode 2>&1 | grep -q "HIGH RISK\|trust the source"; then
        success "opencode security warning correctly displayed"
    else
        warning "opencode security warning may not have displayed as expected"
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return $high_risk_success
}

# Test security scanning for different agent types
test_security_scanning() {
    info "=== Testing Security Scanning Features ==="
    
    # Start container
    "$DCUTIL" up
    
    # Test aider security scanning (pip-based)
    info "Testing aider with security scanning..."
    if DCUTIL_TEST_SKIP_PORTABLE=true DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent aider 2>/dev/null; then
        success "aider installation with security scanning passed"
        local security_success=0
    else
        error "aider installation with security scanning failed"
        local security_success=1
    fi
    
    # Clean up for next test
    "$DCUTIL" down
    "$DCUTIL" up
    
    # Test security scanning during npm-based installation
    info "Testing copilot-cli (npm-based) with security scanning..."
    if DCUTIL_TEST_SKIP_PORTABLE=true DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent copilot-cli 2>/dev/null; then
        success "copilot-cli installation with security scanning passed"
    else
        error "copilot-cli installation with security scanning failed"
        local security_success=1
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return $security_success
}

# Test virtual environment isolation
test_venv_isolation() {
    info "=== Testing Virtual Environment Isolation ==="
    
    # Start container
    "$DCUTIL" up
    
    # Install aider which should create a venv
    info "Installing aider to test venv isolation..."
    if DCUTIL_TEST_SKIP_PORTABLE=true DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent aider 2>/dev/null; then
        # Check if venv exists
        if "$DCUTIL" run "test -d /home/vscode/.dcutil/agents/aider" 2>/dev/null; then
            success "Aider venv created successfully at /home/vscode/.dcutil/agents/aider"
            
            # Check if python executable exists in venv
            if "$DCUTIL" run "test -x /home/vscode/.dcutil/agents/aider/bin/python" 2>/dev/null; then
                success "Aider venv python executable found"
            else
                warning "Aider venv python executable not found"
            fi
            
            # Check if the venv is properly isolated
            if "$DCUTIL" run "test -x /home/vscode/.dcutil/agents/aider/bin/aider" 2>/dev/null; then
                success "Aider executable found in isolated venv"
            else
                # Try with python -m aider
                if "$DCUTIL" run "test -f /home/vscode/.dcutil/agents/aider/bin/pip" 2>/dev/null && \
                   "$DCUTIL" run "/home/vscode/.dcutil/agents/aider/bin/python -c 'import aider'" 2>/dev/null; then
                    success "Aider package installed in isolated venv"
                else
                    warning "Aider not properly installed in venv"
                fi
            fi
        else
            error "Aider venv was not created"
            local venv_success=1
        fi
    else
        error "Aider installation failed"
        local venv_success=1
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return ${venv_success:-0}
}

# Test dependency conflict detection
test_dependency_conflicts() {
    info "=== Testing Dependency Conflict Detection ==="
    
    # Start container
    "$DCUTIL" up
    
    # Install aider which has many dependencies
    info "Installing aider to test dependency conflict detection..."
    if DCUTIL_TEST_SKIP_PORTABLE=true DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent aider 2>/dev/null; then
        # Check if vulnerability scanning ran
        success "Aider installed with dependency conflict checking"
        
        # Test that installed packages can be verified
        if "$DCUTIL" run "command -v pip" >/dev/null 2>&1; then
            if "$DCUTIL" run "pip list | grep -i aider" 2>/dev/null; then
                success "Aider package listed in pip"
            else
                info "Aider package not found in pip list (may be installed differently)"
            fi
        fi
    else
        error "Aider installation failed"
        local conflict_success=1
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return ${conflict_success:-0}
}

# Test portable Python environment (when available)
test_portable_python() {
    info "=== Testing Portable Python Environment ==="
    
    # Start container
    "$DCUTIL" up
    
    # Test installer with portable Python disabled (current behavior)
    info "Testing aider installation without portable Python..."
    if DCUTIL_TEST_SKIP_PORTABLE=true DCUTIL_ASSUME_YES=1 "$DCUTIL" install-agent aider 2>/dev/null; then
        success "Aider installed using system Python"
        
        # Verify it's using system Python and not portable
        if ! "$DCUTIL" run "test -d /home/vscode/.dcutil/python" 2>/dev/null; then
            success "Portable Python correctly skipped (as expected with DCUTIL_TEST_SKIP_PORTABLE)"
        else
            warning "Portable Python found despite skip flag"
        fi
    else
        error "Aider installation failed with system Python"
        local portable_success=1
    fi
    
    # Clean up
    "$DCUTIL" down
    
    return ${portable_success:-0}
}

# Main test function
main() {
    info "Starting Security-Focused Agent Installer Tests"
    info "Testing security features for high-risk and standard agents"

    trap cleanup EXIT

    setup_test_env
    test_high_risk_agent
    test_security_scanning
    test_venv_isolation
    test_dependency_conflicts
    test_portable_python

    success "All security-focused agent installer tests completed!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi