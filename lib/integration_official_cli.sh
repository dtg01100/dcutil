#!/usr/bin/env bash

# Devcontainer CLI integration for dcutil
# Provides compatibility and enhanced functionality using the official devcontainer CLI

# Source core functionality
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"


# Run devcontainer up command via official CLI
run_devcontainer_up() {
    local project_dir="${1:-$(pwd)}"

    info "Using official devcontainer CLI to create environment..."

    # Find devcontainer.json
    local config_file=""
    if [ -f "$project_dir/.devcontainer/devcontainer.json" ]; then
        config_file="$project_dir/.devcontainer/devcontainer.json"
    elif [ -f "$project_dir/.devcontainer.json" ]; then
        config_file="$project_dir/.devcontainer.json"
    else
        error_exit "No devcontainer.json found in project. Expected .devcontainer/devcontainer.json or .devcontainer.json" "$EXIT_CONFIG_ERROR"
    fi

    # Get workspace folder (parent of config file)
    local workspace_folder
    workspace_folder="$(dirname "$(dirname "$config_file")")"

    # Run the official devcontainer up command
    devcontainer up \
        --workspace-folder "$workspace_folder" \
        --config "$config_file" \
        --log-level info
}

# Run devcontainer down command via official CLI
run_devcontainer_down() {
    info "Using official devcontainer CLI to shut down environment..."

    # For down, we might need to get the container name that was used
    # For now, we'll use docker directly like before
    local container_name
    container_name=$(get_container_name_for_project "$(pwd)")

    if [ -n "$container_name" ]; then
        if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
            if docker stop "$container_name" && docker rm "$container_name"; then
                success "Devcontainer stopped and removed: $container_name"
            else
                error_exit "Failed to stop devcontainer: $container_name" "$EXIT_DEVCONTAINER_ERROR"
            fi
        else
            info "Container $container_name not found"
        fi
    else
        info "No container found for current project"
    fi
}

# Run command in container using official CLI
run_devcontainer_exec() {
    # Preserve argument boundaries and pass through to devcontainer
    # Use "$@" when forwarding multiple command arguments
    : # no-op, we forward "$@" directly below

    info "Executing command in devcontainer using official CLI..."

    # The devcontainer exec command works differently
    # We need to find the appropriate container
    devcontainer exec --workspace-folder . -- "$@"
}