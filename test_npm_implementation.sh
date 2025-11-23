#!/usr/bin/env bash

# Test script to validate the updated npm-based agent installations
# Tests that the get_agent_install_command function returns correct npm commands

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the security module to test the function
source "$SCRIPT_DIR/lib/security.sh"

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

# Test the get_agent_install_command function for all agents
test_get_agent_install_command() {
    info "=== Testing get_agent_install_command function ==="
    
    local agents=(
        "opencode"
        "aider"
        "copilot-cli"
        "cody"
        "tabnine"
        "qwen-cli"
        "gemini"
        "claude-cli"
        "openai-cli"
    )
    
    local all_passed=true
    local npm_agents=0
    local non_npm_agents=0
    
    for agent in "${agents[@]}"; do
        local cmd
        cmd=$(get_agent_install_command "$agent")
        
        info "Agent: $agent -> Command: $cmd"
        
        if [[ "$cmd" == npm* ]]; then
            success "  ✓ $agent uses npm: $cmd"
            ((npm_agents++))
        else
            error "  ✗ $agent does not use npm: $cmd"
            all_passed=false
            ((non_npm_agents++))
        fi
    done
    
    info "\nSummary:"
    info "  Total agents tested: ${#agents[@]}"
    info "  Using npm: $npm_agents"
    info "  Not using npm: $non_npm_agents"
    
    if [ "$all_passed" = true ]; then
        success "All agents use npm for installation!"
        return 0
    else
        error "Some agents do not use npm!"
        return 1
    fi
}

# Test security functions
test_security_functions() {
    info "=== Testing updated security functions ==="
    
    # Test that the security check doesn't trigger for opencode anymore
    local result
    result=$(check_agent_security_risk "opencode" "npm install -g @opencode/cli" 2>&1)
    
    if [ -z "$result" ]; then
        success "Security check for opencode returns no output (as expected with npm)"
    else
        warning "Security check for opencode returned: $result"
    fi
    
    # Test with another agent
    result=$(check_agent_security_risk "aider" "npm install -g aider-chat" 2>&1)
    
    if [ -z "$result" ]; then
        success "Security check for aider returns no output (as expected)"
    else
        warning "Security check for aider returned: $result"
    fi
}

# Main test function
main() {
    info "Starting validation of npm-based agent installation updates"
    
    local exit_code=0
    
    if test_get_agent_install_command; then
        success "get_agent_install_command tests passed"
    else
        error "get_agent_install_command tests failed"
        exit_code=1
    fi
    
    test_security_functions
    success "Security function tests completed"
    
    if [ $exit_code -eq 0 ]; then
        success "All validation tests passed!"
    else
        error "Some validation tests failed!"
    fi
    
    exit $exit_code
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi