#!/usr/bin/env bash

# Lifecycle command support for dcutil
# Implements additional lifecycle hooks from devcontainer specification

# Source core functionality
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for lifecycle commands
INITIALIZE_COMMAND=""
ON_CREATE_COMMAND=""
UPDATE_CONTENT_COMMAND=""
POST_CREATE_COMMAND=""
POST_START_COMMAND=""
POST_ATTACH_COMMAND=""
WAIT_FOR=""

# Parse lifecycle commands from devcontainer.json
parse_lifecycle_config() {
    if command -v jq &> /dev/null; then
        # Parse initializeCommand
        if jq -e '.initializeCommand' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            INITIALIZE_COMMAND=$(jq -r '.initializeCommand' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
            info "initializeCommand found"
        fi

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

        # Parse postCreateCommand
        if jq -e '.postCreateCommand' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            POST_CREATE_COMMAND=$(jq -r '.postCreateCommand' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
            info "postCreateCommand found"
        fi

        # Parse postStartCommand
        if jq -e '.postStartCommand' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            POST_START_COMMAND=$(jq -r '.postStartCommand' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
            info "postStartCommand found"
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

# Execute initializeCommand on the host system (not in container)
execute_initialize_command() {
    if [ -z "${INITIALIZE_COMMAND:-}" ]; then
        return 0
    fi

    info "Running initializeCommand on host system..."

    # For initializeCommand, execute on the host system, not in the container
    # Check if command is object (parallel execution)
    if command -v jq &> /dev/null && echo "$INITIALIZE_COMMAND" | jq -e 'type == "object"' >/dev/null 2>&1; then
        # For parallel commands, run them on host as well
        execute_parallel_commands_host "$INITIALIZE_COMMAND" "initializeCommand"
    else
        # Single command or array - run on host
        execute_lifecycle_command_host "$INITIALIZE_COMMAND" "initializeCommand"
    fi
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        success "initializeCommand completed successfully"
    else
        warning "initializeCommand failed (continuing anyway)"
    fi
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
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
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
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
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
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        success "postAttachCommand completed successfully"
    else
        warning "postAttachCommand failed (continuing anyway)"
    fi
}

# Execute postCreateCommand
execute_post_create_command() {
    if [ -z "${POST_CREATE_COMMAND:-}" ]; then
        return 0
    fi

    info "Running postCreateCommand..."

    # Check if command is object (parallel execution)
    if command -v jq &> /dev/null && echo "$POST_CREATE_COMMAND" | jq -e 'type == "object"' >/dev/null 2>&1; then
        execute_parallel_commands "$POST_CREATE_COMMAND" "postCreateCommand"
    else
        # Single command or array
        execute_lifecycle_command "$POST_CREATE_COMMAND" "postCreateCommand"
    fi
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        success "postCreateCommand completed successfully"
    else
        warning "postCreateCommand failed (continuing anyway)"
    fi
}

# Execute postStartCommand
execute_post_start_command() {
    if [ -z "${POST_START_COMMAND:-}" ]; then
        return 0
    fi

    info "Running postStartCommand..."

    # Check if command is object (parallel execution)
    if command -v jq &> /dev/null && echo "$POST_START_COMMAND" | jq -e 'type == "object"' >/dev/null 2>&1; then
        execute_parallel_commands "$POST_START_COMMAND" "postStartCommand"
    else
        # Single command or array
        execute_lifecycle_command "$POST_START_COMMAND" "postStartCommand"
    fi
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        success "postStartCommand completed successfully"
    else
        warning "postStartCommand failed (continuing anyway)"
    fi
}

# Execute a lifecycle command (single command or array) - in container when possible
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
                # If container is running, execute inside container; otherwise run locally
                if [ -n "${CONTAINER_NAME:-}" ] && docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                    if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
                        if ! execute_command_in_devcontainer "$PROJECT_DIR" /bin/sh -c "$cmd"; then
                            error "[$command_name] Command failed: $cmd"
                            return 1
                        fi
                    elif ! docker exec "$CONTAINER_NAME" /bin/sh -c "$cmd"; then
                        error "[$command_name] Command failed: $cmd"
                        return 1
                    fi
                else
                    if ! /bin/sh -c "$cmd"; then
                        error "[$command_name] Command failed: $cmd"
                        return 1
                    fi
                fi
            fi
        done
    else
        # Single command
        info "[$command_name] Executing: $command_json"
        if [ -n "${CONTAINER_NAME:-}" ] && docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
                if ! execute_command_in_devcontainer "$PROJECT_DIR" /bin/sh -c "$command_json"; then
                    error "[$command_name] Command failed: $command_json"
                    return 1
                fi
            elif ! docker exec "$CONTAINER_NAME" /bin/sh -c "$command_json"; then
                error "[$command_name] Command failed: $command_json"
                return 1
            fi
        else
            if ! /bin/sh -c "$command_json"; then
                error "[$command_name] Command failed: $command_json"
                return 1
            fi
        fi
    fi

    return 0
}

# Execute a lifecycle command (single command or array) - on host system
execute_lifecycle_command_host() {
    local command_json="$1"
    local command_name="$2"

    if [ -z "$command_json" ] || [ "$command_json" = "null" ]; then
        return 0
    fi

    # Check if it's an array
    if command -v jq &> /dev/null && echo "$command_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
        # Execute array of commands sequentially on host
        local commands=()
        local i=0
        while IFS= read -r cmd; do
            if [ -n "$cmd" ] && [ "$cmd" != "null" ]; then
                commands[i]="$cmd"
                ((i++))
            fi
        done < <(echo "$command_json" | jq -r '.[]' 2>/dev/null)

        for cmd in "${commands[@]}"; do
            info "[$command_name] Executing on host: $cmd"
            if ! /bin/sh -c "$cmd"; then
                error "[$command_name] Command failed on host: $cmd"
                return 1
            fi
        done
    else
        # Single command
        info "[$command_name] Executing on host: $command_json"
        if ! /bin/sh -c "$command_json"; then
            error "[$command_name] Command failed on host: $command_json"
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
                                if [ -n "${CONTAINER_NAME:-}" ] && docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                                    if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
                                        execute_command_in_devcontainer "$PROJECT_DIR" /bin/sh -c "$cmd"
                                    else
                                        docker exec "$CONTAINER_NAME" /bin/sh -c "$cmd"
                                    fi
                                else
                                    /bin/sh -c "$cmd"
                                fi
                            fi
                        done
                    else
                        # Single command
                        if [ -n "${CONTAINER_NAME:-}" ] && docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                            if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
                                execute_command_in_devcontainer "$PROJECT_DIR" /bin/sh -c "$cmd_value"
                            else
                                docker exec "$CONTAINER_NAME" /bin/sh -c "$cmd_value"
                            fi
                        else
                            /bin/sh -c "$cmd_value"
                        fi
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

# Execute parallel commands on host system
execute_parallel_commands_host() {
    local commands_json="$1"
    local command_name="$2"

    if [ -z "$commands_json" ] || [ "$commands_json" = "null" ]; then
        return 0
    fi

    info "[$command_name] Executing parallel commands on host..."

    # Extract command names and execute in parallel on host
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

    # Execute each command in parallel on host
    for cmd_name in "${command_names[@]}"; do
        if command -v jq &> /dev/null; then
            local cmd_value
            cmd_value=$(echo "$commands_json" | jq -r ".[\"$cmd_name\"]" 2>/dev/null)

            if [ -n "$cmd_value" ] && [ "$cmd_value" != "null" ]; then
                info "[$command_name] Starting parallel command on host: $cmd_name"

                # Execute command in background on host
                (
                    if echo "$cmd_value" | jq -e 'type == "array"' >/dev/null 2>&1; then
                        # Array command
                        echo "$cmd_value" | jq -r '.[]' 2>/dev/null | while IFS= read -r cmd; do
                            if [ -n "$cmd" ] && [ "$cmd" != "null" ]; then
                                /bin/sh -c "$cmd"
                            fi
                        done
                    else
                        # Single command
                        /bin/sh -c "$cmd_value"
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
        error "[$command_name] Some parallel commands failed on host"
        return 1
    fi

    success "[$command_name] All parallel commands completed successfully on host"
    return 0
}

# Execute lifecycle commands based on waitFor policy
execute_lifecycle_commands() {
    if ! command -v parse_lifecycle_config >/dev/null 2>&1 || ! parse_lifecycle_config >/dev/null 2>&1; then
        return 0
    fi

    local wait_for_value="${WAIT_FOR:-updateContentCommand}"

    info "Executing lifecycle commands with waitFor=$wait_for_value"

    # Execute initializeCommand first if configured
    execute_initialize_command

    # Always execute onCreateCommand first
    execute_on_create_command

    # Execute updateContentCommand
    execute_update_content_command

    # Execute postCreateCommand
    execute_post_create_command

    # Wait for specific command if waitFor is set
    case "$wait_for_value" in
        "onCreateCommand")
            # Wait after onCreateCommand
            ;;
        "updateContentCommand")
            # Wait after updateContentCommand
            ;;
        "postCreateCommand")
            # Wait after postCreateCommand
            ;;
        *)
            warning "Unknown waitFor value: $wait_for_value"
            ;;
    esac

    return 0
}

# Execute post start lifecycle commands
execute_post_start_lifecycle_commands() {
    if ! command -v parse_lifecycle_config >/dev/null 2>&1 || ! parse_lifecycle_config >/dev/null 2>&1; then
        return 0
    fi

    info "Executing post-start lifecycle commands"

    # Execute postStartCommand
    execute_post_start_command

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
    if [ -n "${POST_CREATE_COMMAND:-}" ]; then
        echo "  postCreateCommand: $POST_CREATE_COMMAND"
    fi
    if [ -n "${POST_START_COMMAND:-}" ]; then
        echo "  postStartCommand: $POST_START_COMMAND"
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