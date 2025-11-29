#!/usr/bin/env bash

# Devcontainer CLI Interface for dcutil
# Provides a bridge to the official devcontainer CLI while adding enhanced UX

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variable to cache detected backend for the current project
# Defined in core.sh

# detect_cli_backend() moved to core.sh to avoid duplication

# Verify devcontainer CLI version compatibility
verify_devcontainer_cli() {
    if ! command -v devcontainer >/dev/null 2>&1; then
        error_exit "devcontainer CLI not found. dcutil requires devcontainer CLI as a hard dependency. Please install it with: brew install devcontainer" "$EXIT_DEVCONTAINER_ERROR"
    fi

    local version
    version=$(devcontainer --version 2>/dev/null)
    info "Using official devcontainer CLI version: $version"

    # Check minimum version requirement if needed
    return 0
}

# Execute devcontainer CLI command
execute_devcontainer_cli() {
    local subcommand="$1"
    shift

    # Verify CLI is available before executing
    verify_devcontainer_cli

    info "Executing: devcontainer $subcommand $*"
    devcontainer "$subcommand" "$@"
}

# Wrapper for devcontainer up
devcontainer_cli_up() {
    local project_dir="${1:-$PROJECT_DIR}"
    shift 1  # Remove project_dir from arguments
    
    if [ -z "$project_dir" ]; then
        project_dir="$(pwd)"
    fi
    
    verify_devcontainer_cli
    
    # Find devcontainer.json
    local config_path=""
    local workspace_folder="$project_dir"
    
    if [ -f "$project_dir/.devcontainer/devcontainer.json" ]; then
        config_path="$project_dir/.devcontainer/devcontainer.json"
    elif [ -f "$project_dir/.devcontainer.json" ]; then
        config_path="$project_dir/.devcontainer.json"
    else
        # If no config exists, we can create a basic one or use default behavior
        config_path=""
        info "No devcontainer.json found in standard locations"
    fi
    
    # Build arguments for devcontainer up
    local args=()
    
    # Add workspace folder
    args+=("--workspace-folder" "$workspace_folder")
    
    # Add config if found
    if [ -n "$config_path" ] && [ -f "$config_path" ]; then
        args+=("--config" "$config_path")
    fi
    
    # Add any additional arguments passed
    args+=("$@")
    
    info "Starting devcontainer using official CLI..."
    echo "⏳ This may take a few minutes on first run..."
    execute_devcontainer_cli "up" "${args[@]}"

    # Detect which backend the CLI used
    detect_cli_backend "$project_dir"
}

# Wrapper for devcontainer down
devcontainer_cli_down() {
    local project_dir="${1:-$PROJECT_DIR}"
    
    if [ -z "$project_dir" ]; then
        project_dir="$(pwd)"
    fi
    
    verify_devcontainer_cli
    
    # For down, we need to identify the container name based on the project
    # This might use id-labels to identify the right container
    local container_name
    container_name=$(get_container_name_for_project "$project_dir")
    
    info "Stopping devcontainer using official CLI..."
    
    # Use detected backend to stop the specific container
    # The devcontainer CLI may not have a direct down command
    if [ -n "$container_name" ]; then
        local backend_cmd="docker"
        if [ "$DETECTED_BACKEND" = "podman" ] && command -v podman >/dev/null 2>&1; then
            backend_cmd="podman"
        fi
        if $backend_cmd ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
            if $backend_cmd stop "$container_name" && $backend_cmd rm "$container_name"; then
                success "Container stopped and removed: $container_name"
            else
                error_exit "Failed to stop container: $container_name" "$EXIT_DEVCONTAINER_ERROR"
            fi
        else
            info "Container $container_name not running"
        fi
    else
        info "No container found for project $project_dir"
    fi
}

# Wrapper for devcontainer build
devcontainer_cli_build() {
    local project_dir="${1:-$PROJECT_DIR}"
    shift 1
    
    verify_devcontainer_cli
    
    if [ ! -d "$project_dir" ]; then
        error_exit "Project directory does not exist: $project_dir" "$EXIT_CONFIG_ERROR"
    fi
    
    # Find devcontainer.json
    local config_path=""
    if [ -f "$project_dir/.devcontainer/devcontainer.json" ]; then
        config_path="$project_dir/.devcontainer/devcontainer.json"
    elif [ -f "$project_dir/.devcontainer.json" ]; then
        config_path="$project_dir/.devcontainer.json"
    else
        error_exit "No devcontainer.json found in project directory $project_dir" "$EXIT_CONFIG_ERROR"
    fi
    
    # Build arguments
    local args=( "--workspace-folder" "$project_dir" )
    args+=( "--config" "$config_path" )
    args+=("$@")
    
    info "Building devcontainer image using official CLI..."
    echo "⏳ This may take several minutes depending on the image size..."
    execute_devcontainer_cli "build" "${args[@]}"
}

# Wrapper for devcontainer exec/run commands inside container
devcontainer_cli_exec() {
    local cmd=("$@")
    
    verify_devcontainer_cli
    
    # Execute command in the devcontainer using devcontainer CLI
    info "Executing command in devcontainer using official CLI..."
    
    # devcontainer CLI doesn't have direct exec command, so use backend exec
    # In future, we could use the devcontainer CLI's way to identify and access the container
    local container_name
    container_name=$(get_current_devcontainer_name)

    if [ -n "$container_name" ]; then
        local backend_cmd="docker"
        if [ "$DETECTED_BACKEND" = "podman" ] && command -v podman >/dev/null 2>&1; then
            backend_cmd="podman"
        fi
        if $backend_cmd ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            $backend_cmd exec -it "$container_name" "${cmd[@]}"
        else
            error_exit "Container not running: $container_name" "$EXIT_DEVCONTAINER_ERROR"
        fi
    else
        error_exit "Could not determine devcontainer name" "$EXIT_DEVCONTAINER_ERROR"
    fi
}

# Function to execute a command in the devcontainer using the official CLI
execute_command_in_devcontainer() {
    local project_dir="${1:-$PROJECT_DIR}"
    shift  # Remove project_dir from arguments

    # Verify CLI is available before executing
    verify_devcontainer_cli

    # The devcontainer CLI has an exec command that can run commands in the container
    # Find devcontainer.json for the project
    local config_path=""
    if [ -f "$project_dir/.devcontainer/devcontainer.json" ]; then
        config_path="$project_dir/.devcontainer/devcontainer.json"
    elif [ -f "$project_dir/.devcontainer.json" ]; then
        config_path="$project_dir/.devcontainer.json"
    fi

    local args=()
    args+=("--workspace-folder" "$project_dir")

    if [ -n "$config_path" ] && [ -f "$config_path" ]; then
        args+=("--config" "$config_path")
    fi

    # Add the command to execute
    # Don't wrap shell commands - pass them directly to devcontainer exec
    args+=("$@")

    info "Executing command in devcontainer using official CLI..."

    # Execute the command directly
    # The devcontainer exec command will handle TTY allocation automatically
    devcontainer "exec" "${args[@]}"
    return $?
}

# Execute command in container using devcontainer CLI
execute_command_in_container_via_cli() {
    local project_dir="${1:-$PROJECT_DIR}"
    shift  # Remove project_dir from arguments

    # Verify CLI is available before executing
    verify_devcontainer_cli

    # Construct command to execute inside container using devcontainer CLI
    local config_path=""
    if [ -f "$project_dir/.devcontainer/devcontainer.json" ]; then
        config_path="$project_dir/.devcontainer/devcontainer.json"
    elif [ -f "$project_dir/.devcontainer.json" ]; then
        config_path="$project_dir/.devcontainer.json"
    fi

    local args=()
    args+=("--workspace-folder" "$project_dir")

    if [ -n "$config_path" ] && [ -f "$config_path" ]; then
        args+=("--config" "$config_path")
    fi

    # Add the command to execute
    args+=("$@")

    info "Executing command in container via devcontainer CLI..."
    devcontainer exec "${args[@]}"
}

# Get current devcontainer name based on project
get_current_devcontainer_name() {
    local project_dir="${1:-$PROJECT_DIR}"
    if [ -z "$project_dir" ]; then
        project_dir="$(pwd)"
    fi

    # Use project directory to generate container name (matching devcontainer CLI convention)
    # The devcontainer CLI uses a consistent naming scheme based on the workspace path
    local hash
    hash=$(python3 -c "import hashlib; print(hashlib.md5('$project_dir'.encode()).hexdigest())")
    echo "devcontainer_$(basename "$project_dir")_${hash:0:8}"
}

# Enhanced dcutil command that wraps official CLI with better UX
enhanced_dcutil_command() {
    local subcommand="$1"
    shift

    case "$subcommand" in
        "up")
            info "Starting devcontainer with enhanced UX..."
            devcontainer_cli_up "$PROJECT_DIR" "$@"
            ;;
        "down")
            info "Stopping devcontainer with enhanced UX..."
            devcontainer_cli_down "$PROJECT_DIR"
            ;;
        "build")
            info "Building devcontainer image with enhanced UX..."
            devcontainer_cli_build "$PROJECT_DIR" "$@"
            ;;
        "run")
            # Use devcontainer CLI exec for run commands
            info "Executing in container with dcutil's enhanced UX..."
            execute_command_in_devcontainer "$PROJECT_DIR" "$@"
            ;;
        *)
            # For other commands, continue with dcutil implementation
            return 1  # Indicate to use traditional dcutil methods
            ;;
    esac
    return 0
}