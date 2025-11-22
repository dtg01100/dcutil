#!/bin/bash

# Lifecycle command support for dcutil
# Implements additional lifecycle hooks from devcontainer specification

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for lifecycle commands
ON_CREATE_COMMAND=""
UPDATE_CONTENT_COMMAND=""
POST_ATTACH_COMMAND=""
WAIT_FOR=""

# Parse lifecycle commands from devcontainer.json
parse_lifecycle_config() {
    if command -v jq &> /dev/null; then
        # Parse onCreateCommand
        if jq -e '.onCreateCommand' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            ON_CREATE_COMMAND=$(jq -r '.onCreateCommand' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
            info "onCreateCommand found"
        fi
        
        # Parse updateContentCommand
        if jq -e '.updateContentCommand' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            UPDATE_CONTENT_COMMAND=$(jq -r '.updateContentCommand' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
            info "updateContentCommand found"
        fi
        
        # Parse postAttachCommand
        if jq -e '.postAttachCommand' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            POST_ATTACH_COMMAND=$(jq -r '.postAttachCommand' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
            info "postAttachCommand found"
        fi
        
        # Parse waitFor
        WAIT_FOR=$(jq -r '.waitFor // "updateContentCommand"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        if [ -n "$WAIT_FOR" ] && [ "$WAIT_FOR" != "null" ]; then
            info "waitFor set to: $WAIT_FOR"
        fi
        
        return 0
    fi
    return 1
}

# Execute onCreateCommand
execute_on_create_command() {
    if [ -z "${ON_CREATE_COMMAND:-}" ]; then
        return 0
    fi
    
    info "Running onCreateCommand..."
    
    # Check if command is object (parallel execution)
    if command -v jq &> /dev/null && echo "$ON_CREATE_COMMAND" | jq -e 'type == "object"' >/dev/null 2>&1; then
        execute_parallel_commands "$ON_CREATE_COMMAND" "onCreateCommand"
    else
        # Single command or array
        execute_lifecycle_command "$ON_CREATE_COMMAND" "onCreateCommand"
    fi
    
    if [ $? -eq 0 ]; then
        success "onCreateCommand completed successfully"
    else
        warning "onCreateCommand failed (continuing anyway)"
    fi
}

# Execute updateContentCommand
execute_update_content_command() {
    if [ -z "${UPDATE_CONTENT_COMMAND:-}" ]; then
        return 0
    fi
    
    info "Running updateContentCommand..."
    
    # Check if command is object (parallel execution)
    if command -v jq &> /dev/null && echo "$UPDATE_CONTENT_COMMAND" | jq -e 'type == "object"' >/dev/null 2>&1; then
        execute_parallel_commands "$UPDATE_CONTENT_COMMAND" "updateContentCommand"
    else
        # Single command or array
        execute_lifecycle_command "$UPDATE_CONTENT_COMMAND" "updateContentCommand"
    fi
    
    if [ $? -eq 0 ]; then
        success "updateContentCommand completed successfully"
    else
        warning "updateContentCommand failed (continuing anyway)"
    fi
}

# Execute postAttachCommand
execute_post_attach_command() {
    if [ -z "${POST_ATTACH_COMMAND:-}" ]; then
        return 0
    fi
    
    info "Running postAttachCommand..."
    
    # Check if command is object (parallel execution)
    if command -v jq &> /dev/null && echo "$POST_ATTACH_COMMAND" | jq -e 'type == "object"' >/dev/null 2>&1; then
        execute_parallel_commands "$POST_ATTACH_COMMAND" "postAttachCommand"
    else
        # Single command or array
        execute_lifecycle_command "$POST_ATTACH_COMMAND" "postAttachCommand"
    fi
    
    if [ $? -eq 0 ]; then
        success "postAttachCommand completed successfully"
    else
        warning "postAttachCommand failed (continuing anyway)"
    fi
}

# Execute a lifecycle command (single command or array)
execute_lifecycle_command() {
    local command_json="$1"
    local command_name="$2"
    
    if [ -z "$command_json" ] || [ "$command_json" = "null" ]; then
        return 0
    fi
    
    # Check if it's an array
    if command -v jq &> /dev/null && echo "$command_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
        # Execute array of commands sequentially
        echo "$command_json" | jq -r '.[]' 2>/dev/null | while IFS= read -r cmd; do
            if [ -n "$cmd" ] && [ "$cmd" != "null" ]; then
                info "[$command_name] Executing: $cmd"
                if ! docker exec "$CONTAINER_NAME" /bin/sh -c "$cmd"; then
                    error "[$command_name] Command failed: $cmd"
                    return 1
                fi
            fi
        done
    else
        # Single command
        info "[$command_name] Executing: $command_json"
        if ! docker exec "$CONTAINER_NAME" /bin/sh -c "$command_json"; then
            error "[$command_name] Command failed: $command_json"
            return 1
        fi
    fi
    
    return 0
}

# Execute parallel commands from object
execute_parallel_commands() {
    local commands_json="$1"
    local command_name="$2"
    
    if [ -z "$commands_json" ] || [ "$commands_json" = "null" ]; then
        return 0
    fi
    
    info "[$command_name] Executing parallel commands..."
    
    # Extract command names and execute in parallel
    local pids=()
    local command_names=()
    
    # Get all command names
    if command -v jq &> /dev/null; then
        while IFS= read -r name; do
            if [ -n "$name" ] && [ "$name" != "null" ]; then
                command_names+=("$name")
            fi
        done < <(echo "$commands_json" | jq -r 'keys[]' 2>/dev/null || echo "")
    fi
    
    # Execute each command in parallel
    for cmd_name in "${command_names[@]}"; do
        if command -v jq &> /dev/null; then
            local cmd_value
            cmd_value=$(echo "$commands_json" | jq -r ".[\"$cmd_name\"]" 2>/dev/null)
            
            if [ -n "$cmd_value" ] && [ "$cmd_value" != "null" ]; then
                info "[$command_name] Starting parallel command: $cmd_name"
                
                # Execute command in background
                (
                    if echo "$cmd_value" | jq -e 'type == "array"' >/dev/null 2>&1; then
                        # Array command
                        echo "$cmd_value" | jq -r '.[]' 2>/dev/null | while IFS= read -r cmd; do
                            if [ -n "$cmd" ] && [ "$cmd" != "null" ]; then
                                docker exec "$CONTAINER_NAME" /bin/sh -c "$cmd"
                            fi
                        done
                    else
                        # Single command
                        docker exec "$CONTAINER_NAME" /bin/sh -c "$cmd_value"
                    fi
                ) &
                
                pids+=($!)
            fi
        fi
    done
    
    # Wait for all parallel commands to complete
    local failed_pids=()
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            failed_pids+=("$pid")
        fi
    done
    
    if [ ${#failed_pids[@]} -gt 0 ]; then
        error "[$command_name] Some parallel commands failed"
        return 1
    fi
    
    success "[$command_name] All parallel commands completed successfully"
    return 0
}

# Execute lifecycle commands based on waitFor policy
execute_lifecycle_commands() {
    if ! command -v parse_lifecycle_config >/dev/null 2>&1 || ! parse_lifecycle_config >/dev/null 2>&1; then
        return 0
    fi
    
    local wait_for_value="${WAIT_FOR:-updateContentCommand}"
    
    info "Executing lifecycle commands with waitFor=$wait_for_value"
    
    # Always execute onCreateCommand first
    execute_on_create_command
    
    # Execute updateContentCommand
    execute_update_content_command
    
    # Wait for specific command if waitFor is set
    case "$wait_for_value" in
        "onCreateCommand")
            # Wait after onCreateCommand (already done)
            ;;
        "updateContentCommand")
            # Wait after updateContentCommand (already done)
            ;;
        "postCreateCommand")
            # Wait will be handled by the main docker.sh script
            ;;
        *)
            warning "Unknown waitFor value: $wait_for_value"
            ;;
    esac
    
    return 0
}

# Show lifecycle configuration
show_lifecycle_info() {
    if ! command -v parse_lifecycle_config >/dev/null 2>&1 || ! parse_lifecycle_config >/dev/null 2>&1; then
        echo "No lifecycle configuration found."
        return 1
    fi
    
    echo "Lifecycle Configuration:"
    if [ -n "${ON_CREATE_COMMAND:-}" ]; then
        echo "  onCreateCommand: $ON_CREATE_COMMAND"
    fi
    if [ -n "${UPDATE_CONTENT_COMMAND:-}" ]; then
        echo "  updateContentCommand: $UPDATE_CONTENT_COMMAND"
    fi
    if [ -n "${POST_ATTACH_COMMAND:-}" ]; then
        echo "  postAttachCommand: $POST_ATTACH_COMMAND"
    fi
    echo "  waitFor: ${WAIT_FOR:-updateContentCommand}"
}

# Validate lifecycle configuration
validate_lifecycle_config() {
    if ! command -v parse_lifecycle_config >/dev/null 2>&1 || ! parse_lifecycle_config >/dev/null 2>&1; then
        return 0
    fi
    
    local errors=()
    
    # Validate waitFor value
    case "${WAIT_FOR:-updateContentCommand}" in
        "onCreateCommand"|"updateContentCommand"|"postCreateCommand")
            ;;
        *)
            errors+=("Invalid waitFor value: ${WAIT_FOR:-updateContentCommand}")
            ;;
    esac
    
    if [ ${#errors[@]} -gt 0 ]; then
        echo "Lifecycle configuration validation errors:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
    
    return 0
}