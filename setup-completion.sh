#!/bin/bash

# Auto-setup completion for dcutil
# This script detects your shell and sets up completion automatically

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Detect shell
detect_shell() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    else
        # Check default shell
        case "$SHELL" in
            */zsh)
                echo "zsh"
                ;;
            */bash)
                echo "bash"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    fi
}

# Setup bash completion
setup_bash_completion() {
    local dcutil_path="$1"
    local bashrc="$HOME/.bashrc"
    local completion_line="eval \"\$($dcutil_path completion bash)\""
    
    # Check if completion is already set up
    if grep -q "dcutil completion bash" "$bashrc" 2>/dev/null; then
        warning "Bash completion for dcutil is already configured"
        return 0
    fi
    
    # Add completion to .bashrc
    if echo "" >> "$bashrc" && echo "# dcutil completion" >> "$bashrc" && echo "$completion_line" >> "$bashrc"; then
        success "Bash completion added to ~/.bashrc"
        info "Run 'source ~/.bashrc' or restart your shell to enable completion"
    else
        error "Failed to add completion to ~/.bashrc"
        return 1
    fi
}

# Setup zsh completion
setup_zsh_completion() {
    local dcutil_path="$1"
    local zshrc="$HOME/.zshrc"
    local completion_line="eval \"\$($dcutil_path completion zsh)\""
    
    # Check if completion is already set up
    if grep -q "dcutil completion zsh" "$zshrc" 2>/dev/null; then
        warning "Zsh completion for dcutil is already configured"
        return 0
    fi
    
    # Add completion to .zshrc
    if echo "" >> "$zshrc" && echo "# dcutil completion" >> "$zshrc" && echo "$completion_line" >> "$zshrc"; then
        success "Zsh completion added to ~/.zshrc"
        info "Run 'source ~/.zshrc' or restart your shell to enable completion"
    else
        error "Failed to add completion to ~/.zshrc"
        return 1
    fi
}

# Main setup
main() {
    local dcutil_path="$1"
    
    if [ -z "$dcutil_path" ]; then
        # Try to find dcutil in PATH
        if command -v dcutil >/dev/null 2>&1; then
            dcutil_path="$(command -v dcutil)"
        else
            error "dcutil not found in PATH. Please provide the path to dcutil."
            echo "Usage: $0 /path/to/dcutil"
            exit 1
        fi
    fi
    
    if [ ! -f "$dcutil_path" ]; then
        error "dcutil not found at: $dcutil_path"
        exit 1
    fi
    
    local shell_type
    shell_type=$(detect_shell)
    
    info "Detected shell: $shell_type"
    info "Setting up completion for dcutil at: $dcutil_path"
    
    case "$shell_type" in
        "bash")
            setup_bash_completion "$dcutil_path"
            ;;
        "zsh")
            setup_zsh_completion "$dcutil_path"
            ;;
        "unknown")
            error "Unsupported shell. Please manually add completion:"
            echo ""
            echo "For bash:  eval \"\$(dcutil completion bash)\""
            echo "For zsh:   eval \"\$(dcutil completion zsh)\""
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"