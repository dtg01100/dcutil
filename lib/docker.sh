#!/bin/bash

# Docker and devcontainer operations for dcutil
# Supports both devcontainer CLI (preferred) and Docker-native fallback

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables
USE_DOCKER_NATIVE=false

# Check what devcontainer solution is available
is_docker_native_mode() {
    if ! command -v devcontainer &> /dev/null; then
        return 0  # Docker-native mode
    else
        return 1  # devcontainer CLI mode
    fi
}

# Dependency checking functions
check_devcontainer_cli() {
    if ! check_devcontainer_availability; then
        error_exit "Neither devcontainer CLI nor Docker is available" "$EXIT_DEP_NOT_FOUND"
    fi
    # If we get here, either devcontainer CLI is available OR Docker-native mode is set up
    return 0
}

check_docker_daemon() {
    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not running or not accessible. Please start Docker." "$EXIT_DOCKER_ERROR"
    fi
}

# Safe execution functions
safe_devcontainer_command() {
    local cmd="$1"
    shift

    if ! check_devcontainer_cli; then
        return $EXIT_DEP_NOT_FOUND
    fi

    if [ "$USE_DOCKER_NATIVE" = true ]; then
        # Use Docker-native operations
        case "$cmd" in
            "up")
                docker_up "$@"
                ;;
            "down")
                docker_down "$@"
                ;;
            "build")
                docker_build "$@"
                ;;
            "exec")
                docker_run "$@"
                ;;
            "ps")
                docker_status "$@"
                ;;
            "delete")
                docker_clean "$@"
                ;;
            *)
                error_exit "Unsupported command in Docker-native mode: $cmd" "$EXIT_INVALID_ARGS"
                ;;
        esac
    else
        # Use devcontainer CLI
        if ! check_docker_daemon; then
            return $EXIT_DOCKER_ERROR
        fi

        if ! devcontainer "$cmd" --workspace-folder "$PROJECT_DIR" "$@" 2>/dev/null; then
            # If there are temporary config files, restore them on failure
            if [ -f ".dcutil_temp_devcontainer.json" ]; then
                mv .dcutil_temp_devcontainer.json .devcontainer/devcontainer.json
            elif [ -f ".dcutil_temp_devcontainer_root.json" ]; then
                mv .dcutil_temp_devcontainer_root.json .devcontainer.json
            fi
            error_exit "Devcontainer command failed: devcontainer $cmd $*" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi
}

# Wrapper functions that support both modes
devcontainer_up() {
    info "Starting devcontainer setup..."
    
    if is_docker_native_mode; then
        # Pass PROJECT_DIR as parameter to docker_native function
        info "Using Docker-native operations (devcontainer CLI not available)"
        docker_up "$PROJECT_DIR"
    else
        info "Using devcontainer CLI"
        # Original devcontainer CLI logic
        # Check if project-home option is enabled
        if [ "${DCUTIL_PROJECT_HOME_ENABLED:-false}" = true ]; then
            info "Setting container home folder to project directory..."

            # Check if devcontainer.json exists
            if [ -f ".devcontainer/devcontainer.json" ]; then
                # Create a temporary devcontainer.json with home folder mapping
                backup_config=".dcutil_temp_devcontainer.json"
                cp .devcontainer/devcontainer.json "$backup_config"

                # Add mount configuration to map project directory to home directory
                if command -v jq &> /dev/null; then
                    # Use jq to properly modify the JSON file
                    jq '
                    .mounts = (.mounts // []) + [
                        {
                            "source": "'"$PROJECT_DIR"'",
                            "target": "/home/vscode",
                            "type": "bind"
                        }
                    ] |
                    .containerUser = "vscode" |
                    .remoteUser = "vscode"
                    ' "$backup_config" > .devcontainer/devcontainer.json
                else
                    # Fallback approach using sed for JSON modification
                    warning "jq not available, using basic mount configuration..."

                    devcontainer_config=$(cat "$backup_config")

                    # Check if mounts key exists
                    if echo "$devcontainer_config" | grep -q '"mounts"'; then
                        # Add mount to existing mounts array
                        sed -i "s/\(\"mounts\":\s*\[\)/\1\n            {\"source\": \"$PROJECT_DIR\", \"target\": \"\/home\/vscode\", \"type\": \"bind\"},/g" .devcontainer/devcontainer.json
                    else
                        # Insert mounts key after the opening brace
                        sed -i "s/{/{\n    \"mounts\": [\n        {\"source\": \"$PROJECT_DIR\", \"target\": \"\/home\/vscode\", \"type\": \"bind\"}\n    ],/g" .devcontainer/devcontainer.json
                    fi
                fi
            elif [ -f ".devcontainer.json" ]; then
                # Handle the case where the config is in the root directory
                backup_config=".dcutil_temp_devcontainer_root.json"
                cp .devcontainer.json "$backup_config"

                if command -v jq &> /dev/null; then
                    jq '
                    .mounts = (.mounts // []) + [
                        {
                            "source": "'"$PROJECT_DIR"'",
                            "target": "/home/vscode",
                            "type": "bind"
                        }
                    ] |
                    .containerUser = "vscode" |
                    .remoteUser = "vscode"
                    ' "$backup_config" > .devcontainer.json
                else
                    warning "jq not available, using basic mount configuration for root config..."
                    devcontainer_config=$(cat "$backup_config")

                    if echo "$devcontainer_config" | grep -q '"mounts"'; then
                        sed -i "s/\(\"mounts\":\s*\[\)/\1\n            {\"source\": \"$PROJECT_DIR\", \"target\": \"\/home\/vscode\", \"type\": \"bind\"},/g" .devcontainer.json
                    else
                        sed -i "s/{/{\n    \"mounts\": [\n        {\"source\": \"$PROJECT_DIR\", \"target\": \"\/home\/vscode\", \"type\": \"bind\"}\n    ],/g" .devcontainer.json
                    fi
                fi
            else
                error_exit "No devcontainer configuration found. Run 'dcutil init' first." "$EXIT_CONFIG_ERROR"
            fi

            # Run the devcontainer up command
            safe_devcontainer_command "up"

            # Restore original configuration after container starts
            if [ -f ".dcutil_temp_devcontainer.json" ]; then
                mv .dcutil_temp_devcontainer.json .devcontainer/devcontainer.json
            elif [ -f ".dcutil_temp_devcontainer_root.json" ]; then
                mv .dcutil_temp_devcontainer_root.json .devcontainer.json
            fi

            success "Devcontainer started with project directory as home folder"
        else
            # Normal devcontainer up command
            safe_devcontainer_command "up"
            success "Devcontainer started successfully"
        fi
    fi
}

# Simplified wrapper functions for other operations
devcontainer_down() {
    info "Stopping devcontainer..."
    if is_docker_native_mode; then
        docker_down "$PROJECT_DIR"
    else
        safe_devcontainer_command "down"
    fi
    success "Devcontainer stopped"
}

devcontainer_restart() {
    info "Restarting devcontainer..."
    # Stop if running (ignore errors)
    if is_docker_native_mode; then
        docker_down "$PROJECT_DIR" 2>/dev/null || true
        devcontainer_up
    else
        safe_devcontainer_command "down" 2>/dev/null || true
        safe_devcontainer_command "up"
    fi
    success "Devcontainer restarted successfully"
}

devcontainer_enter() {
    info "Entering container..."
    if is_docker_native_mode; then
        docker_enter "$PROJECT_DIR"
    else
        check_devcontainer_cli
        check_docker_daemon

        # Check if container is running, start it if needed
        if ! devcontainer ps --workspace-folder . 2>/dev/null | grep -q "Running"; then
            warning "Container is not running. Starting it..."

            # If project home is desired, we need to make sure it would be started with the right configuration
            if [ "${DCUTIL_PROJECT_HOME_ENABLED:-false}" = true ]; then
                info "Starting devcontainer with project directory as home folder..."
                # For enter command, if user wants project-home behavior, they should start with up --project-home first
                # So we just enter the existing container if it exists
                if [ -f ".devcontainer/devcontainer.json" ]; then
                    if ! devcontainer up --workspace-folder . 2>/dev/null; then
                        error_exit "Failed to start devcontainer" "$EXIT_DEVCONTAINER_ERROR"
                    fi
                elif [ -f ".devcontainer.json" ]; then
                    if ! devcontainer up --workspace-folder . 2>/dev/null; then
                        error_exit "Failed to start devcontainer" "$EXIT_DEVCONTAINER_ERROR"
                    fi
                else
                    error_exit "No devcontainer configuration found. Run 'dcutil init' first." "$EXIT_CONFIG_ERROR"
                fi
            else
                if ! devcontainer up --workspace-folder . 2>/dev/null; then
                    error_exit "Failed to start devcontainer" "$EXIT_DEVCONTAINER_ERROR"
                fi
            fi
        fi

        if ! devcontainer exec --workspace-folder . /bin/bash; then
            error_exit "Failed to enter container" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi
}

devcontainer_status() {
    info "Checking container status..."
    if is_docker_native_mode; then
        docker_status "$PROJECT_DIR"
    else
        if devcontainer exec --workspace-folder . echo "Container is running" 2>/dev/null; then
            echo "Container is running"
        else
            echo "Container is not running"
        fi
    fi
}

devcontainer_logs() {
    info "Showing container logs..."
    if is_docker_native_mode; then
        docker_logs "$PROJECT_DIR"
    else
        check_docker_daemon

        # Get container ID using docker ps with devcontainer label
        CONTAINER_ID=$(docker ps --filter label=devcontainer.local_folder="$PROJECT_DIR" --format "{{.ID}}" 2>/dev/null | head -1)
        if [ -z "$CONTAINER_ID" ]; then
            error_exit "No running devcontainer found for $PROJECT_DIR" "$EXIT_DEVCONTAINER_ERROR"
        fi

        # Show logs
        if ! docker logs "$CONTAINER_ID" 2>/dev/null; then
            error_exit "Failed to show container logs" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi
}

devcontainer_list() {
    info "Listing running devcontainers..."
    if is_docker_native_mode; then
        docker_list "$PROJECT_DIR"
    else
        check_docker_daemon

        # List containers with devcontainer labels
        if ! docker ps --filter "label=devcontainer.local_folder" --format "table {{.ID}}\t{{.Image}}\t{{.Names}}" 2>/dev/null | grep -v "CONTAINER ID"; then
            echo "No running devcontainers found"
        fi
    fi
}

devcontainer_run() {
    validate_run_command "$@"
    info "Running command in container: $*"
    if is_docker_native_mode; then
        docker_run "$PROJECT_DIR" "$@"
    else
        check_devcontainer_cli
        check_docker_daemon

        if ! devcontainer exec --workspace-folder "$PROJECT_DIR" "$@"; then
            error_exit "Failed to run command in container" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi
}

devcontainer_build() {
    info "Building devcontainer image..."
    if is_docker_native_mode; then
        docker_build "$PROJECT_DIR"
    else
        safe_devcontainer_command "build"
    fi
    success "Build completed"
}

devcontainer_clean() {
    info "Cleaning up devcontainer..."
    if is_docker_native_mode; then
        docker_clean "$PROJECT_DIR"
    else
        check_devcontainer_cli
        check_docker_daemon

        # Stop container first (ignore if not running)
        safe_devcontainer_command "down" 2>/dev/null || true

        # Delete container
        if ! devcontainer delete --workspace-folder . --force 2>/dev/null; then
            warning "Failed to delete devcontainer (may not exist)"
        fi
    fi
    success "Cleanup completed"
}