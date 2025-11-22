#!/bin/bash

# shutdownAction handling for dcutil
# Implements shutdown actions per devcontainer specification

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for shutdown actions
SHUTDOWN_ACTION=""
SHUTDOWN_COMMANDS=()

# Check if shutdownAction is configured
has_shutdown_action() {
    if command -v jq &> /dev/null; then
        if jq -e '.shutdownAction' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Parse shutdownAction configuration
parse_shutdown_action() {
    if ! has_shutdown_action; then
        return 1
    fi
    
    info "Parsing shutdownAction configuration..."
    
    if command -v jq &> /dev/null; then
        SHUTDOWN_ACTION=$(jq -r '.shutdownAction // "stop"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        
        if [ -n "$SHUTDOWN_ACTION" ] && [ "$SHUTDOWN_ACTION" != "null" ]; then
            info "shutdownAction set to: $SHUTDOWN_ACTION"
            return 0
        fi
    fi
    
    return 1
}

# Execute shutdown action
execute_shutdown_action() {
    local container_name="$1"
    
    if ! parse_shutdown_action; then
        info "No shutdownAction configuration found, using default behavior"
        SHUTDOWN_ACTION="stop"
    fi
    
    info "Executing shutdown action: $SHUTDOWN_ACTION for container: $container_name"
    
    case "$SHUTDOWN_ACTION" in
        "stop")
            info "Stopping container gracefully..."
            if docker stop "$container_name" >/dev/null 2>&1; then
                success "Container stopped successfully"
                return 0
            else
                error "Failed to stop container"
                return 1
            fi
            ;;
        "kill")
            info "Killing container..."
            if docker kill "$container_name" >/dev/null 2>&1; then
                success "Container killed successfully"
                return 0
            else
                error "Failed to kill container"
                return 1
            fi
            ;;
        "none")
            info "No shutdown action configured (none)"
            return 0
            ;;
        "shutdown")
            info "Shutting down container..."
            if docker stop "$container_name" >/dev/null 2>&1; then
                success "Container shutdown successfully"
                return 0
            else
                error "Failed to shutdown container"
                return 1
            fi
            ;;
        *)
            # Handle custom shutdown commands
            if [[ "$SHUTDOWN_ACTION" =~ ^[^[:space:]] ]]; then
                info "Executing custom shutdown command: $SHUTDOWN_ACTION"
                
                # Execute shutdown command in container
                if docker exec "$container_name" sh -c "$SHUTDOWN_ACTION" >/dev/null 2>&1; then
                    success "Custom shutdown command executed successfully"
                    return 0
                else
                    error "Failed to execute custom shutdown command"
                    return 1
                fi
            else
                warning "Unknown shutdown action: $SHUTDOWN_ACTION, using default stop"
                execute_shutdown_action "$container_name"
            fi
            ;;
    esac
}

# Register shutdown handler for script cleanup
register_shutdown_handler() {
    local container_name="$1"
    
    if [ -n "$container_name" ]; then
        # Set up trap for script exit
        trap "info 'Script exiting, executing shutdown action...'; execute_shutdown_action '$container_name'; trap - EXIT; exit" EXIT
        info "Shutdown handler registered for container: $container_name"
    fi
}

# Show shutdown action configuration
show_shutdown_action_config() {
    if ! parse_shutdown_action; then
        echo "No shutdownAction configuration found."
        echo "Default behavior: stop container on exit"
        return 0
    fi
    
    echo "Shutdown Action Configuration:"
    echo "============================="
    echo "Action: $SHUTDOWN_ACTION"
    
    case "$SHUTDOWN_ACTION" in
        "stop")
            echo "Description: Stop container gracefully (default)"
            ;;
        "kill")
            echo "Description: Kill container immediately"
            ;;
        "none")
            echo "Description: No automatic shutdown (container continues running)"
            ;;
        "shutdown")
            echo "Description: Shutdown container"
            ;;
        *)
            echo "Description: Custom shutdown command"
            echo "Command: $SHUTDOWN_ACTION"
            ;;
    esac
}

# Validate shutdown action configuration
validate_shutdown_action_config() {
    if ! parse_shutdown_action; then
        info "No shutdownAction configuration found, using default behavior"
        return 0
    fi
    
    local errors=()
    local warnings=()
    
    # Validate shutdown action type
    case "$SHUTDOWN_ACTION" in
        "stop"|"kill"|"none"|"shutdown")
            info "Valid shutdown action: $SHUTDOWN_ACTION"
            ;;
        *)
            # Check if it's a valid command (basic validation)
            if [[ "$SHUTDOWN_ACTION" =~ ^[a-zA-Z0-9_/.-]+ ]]; then
                info "Custom shutdown command: $SHUTDOWN_ACTION"
            else
                errors+=("Invalid shutdown action format: $SHUTDOWN_ACTION")
            fi
            ;;
    esac
    
    # Report validation results
    if [ ${#errors[@]} -gt 0 ]; then
        echo "shutdownAction configuration validation errors:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo "shutdownAction configuration warnings:"
        for warning in "${warnings[@]}"; do
            echo "  - $warning"
        done
    fi
    
    if [ ${#errors[@]} -eq 0 ]; then
        success "shutdownAction configuration is valid"
    fi
    
    return 0
}

# Cleanup shutdown configuration
cleanup_shutdown_action() {
    SHUTDOWN_ACTION=""
    SHUTDOWN_COMMANDS=()
    # Remove any existing trap
    trap - EXIT
    info "Shutdown action configuration cleaned up"
}