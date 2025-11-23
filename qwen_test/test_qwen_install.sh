#!/usr/bin/env bash

# Script to test qwen installation with config mounting using dcutil

set -euo pipefail

SCRIPT_DIR="$(pwd)"
PROJECT_DIR="/var/home/dlafreniere/bin/dcutil-files/qwen_test"

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

# Create qwen configuration directory and file in home directory
setup_local_config() {
    info "Setting up local qwen configuration..."
    
    # Create .qwen directory in user home
    mkdir -p "$HOME/.qwen"
    
    # Create a sample config file
    cat > "$HOME/.qwen/config.json" << EOF
{
    "api_key": "test-key-12345",
    "model": "qwen2.5-72b",
    "temperature": 0.7,
    "max_tokens": 2048
}
EOF
    
    success "Local qwen configuration created at $HOME/.qwen"
}

# Start the devcontainer using dcutil
start_container() {
    info "Starting devcontainer with dcutil..."
    
    cd "$PROJECT_DIR"
    
    if /var/home/dlafreniere/bin/dcutil-files/dcutil up; then
        success "Container started successfully"
    else
        error "Failed to start container"
        return 1
    fi
}

# Install qwen agent using dcutil
install_qwen_agent() {
    info "Installing qwen agent using dcutil install-agent command..."
    
    # Use dcutil to install the qwen agent (now using npm)
    if DCUTIL_ASSUME_YES=1 /var/home/dlafreniere/bin/dcutil-files/dcutil install-agent qwen-cli; then
        success "Qwen agent installed successfully"
    else
        error "Failed to install qwen agent"
        return 1
    fi
}

# Test config mounting by checking if the configuration is accessible in the container
test_config_mounting() {
    info "Testing if qwen configuration is mounted in container..."
    
    # Check if the config directory exists in the container
    if /var/home/dlafreniere/bin/dcutil-files/dcutil run "test -d /home/vscode/.qwen" 2>/dev/null; then
        success "Qwen config directory exists in container: /home/vscode/.qwen"
        
        # Check if the config file exists
        if /var/home/dlafreniere/bin/dcutil-files/dcutil run "test -f /home/vscode/.qwen/config.json" 2>/dev/null; then
            success "Qwen config file exists in container: /home/vscode/.qwen/config.json"
            
            # Show the content of the config file in the container
            info "Content of qwen config file in container:"
            /var/home/dlafreniere/bin/dcutil-files/dcutil run "cat /home/vscode/.qwen/config.json" 2>/dev/null | sed 's/^/  /'
        else
            error "Qwen config file does not exist in container"
            return 1
        fi
    else
        error "Qwen config directory does not exist in container"
        return 1
    fi
}

# Verify qwen cli is working in the container
verify_qwen_functionality() {
    info "Verifying qwen CLI functionality in container..."
    
    # Check if qwen command is available
    if /var/home/dlafreniere/bin/dcutil-files/dcutil run "command -v qwen-cli" 2>/dev/null; then
        success "qwen-cli command is available"
        
        # Try to run qwen with help to see if it works
        if /var/home/dlafreniere/bin/dcutil-files/dcutil run "qwen-cli --help" 2>/dev/null | head -5; then
            success "qwen-cli is functional"
        else
            error "qwen-cli exists but doesn't work properly"
            return 1
        fi
    else
        warning "qwen-cli command not found, checking if @qwen/cli npm package exists"
        
        if /var/home/dlafreniere/bin/dcutil-files/dcutil run "npx @qwen/cli --help" 2>/dev/null | head -5; then
            success "qwen is available via npx"
        else
            error "qwen is not accessible via command or npx"
            return 1
        fi
    fi
}

# Clean up the container
cleanup_container() {
    info "Cleaning up container..."
    
    cd "$PROJECT_DIR"
    
    /var/home/dlafreniere/bin/dcutil-files/dcutil clean 2>/dev/null || true
    success "Container cleaned up"
}

# Main test function
main() {
    info "Starting Qwen Agent Installation and Config Mounting Test"
    info "Using dcutil to install qwen and mount configuration"

    setup_local_config

    if start_container; then
        if install_qwen_agent; then
            if test_config_mounting; then
                verify_qwen_functionality
            else
                error "Config mounting test failed"
            fi
        else
            error "Qwen agent installation failed"
        fi
    else
        error "Failed to start container"
    fi

    cleanup_container

    success "Qwen installation and config mounting test completed!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi