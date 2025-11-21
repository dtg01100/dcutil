#!/bin/bash

# Lifecycle management for dcutil
# Implements onCreateCommand, updateContentCommand, postStartCommand execution

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Run lifecycle command in a temporary container from the image
run_lifecycle_command() {
    local cmd="$1"
    local image="$2"
    local user="${3:-root}"
    local workdir="${4:-/}"

    if [ -z "$cmd" ] || [ -z "$image" ]; then
        error_exit "Lifecycle command and image are required" "$EXIT_INVALID_ARGS"
    fi

    info "Running lifecycle command: $cmd on image: $image"

    local cid
    cid=$(docker create \
        --user "$user" \
        --workdir "$workdir" \
        "$image" \
        /bin/sh -c "while sleep 1000; do :; done")
    if [ -z "$cid" ]; then
        error_exit "Failed to create temporary container for lifecycle command" "$EXIT_DEVCONTAINER_ERROR"
    fi

    if ! docker start "$cid" >/dev/null; then
        error_exit "Failed to start temporary container for lifecycle command" "$EXIT_DEVCONTAINER_ERROR"
    fi

    # Wait a moment for container to be ready
    sleep 1

    if ! docker exec "$cid" /bin/sh -c "$cmd"; then
        warning "Lifecycle command failed: $cmd"
        docker stop "$cid" >/dev/null || true
        docker rm "$cid" >/dev/null || true
        return 1
    fi

    docker stop "$cid" >/dev/null || true
    docker rm "$cid" >/dev/null || true

    success "Lifecycle command executed successfully"
    return 0
}

# Run lifecycle command inside existing container
run_lifecycle_command_in_container() {
    local cmd="$1"
    local cid="$2"
    local user="${3:-}"
    local workdir="${4:-}"

    if [ -z "$cmd" ] || [ -z "$cid" ]; then
        error_exit "Lifecycle command and container id are required" "$EXIT_INVALID_ARGS"
    fi

    info "Running lifecycle command in container: $cmd"

    local exec_args=()
    if [ -n "$user" ]; then
        exec_args+=("--user" "$user")
    fi
    # Only add workdir if it's a valid absolute path
    if [ -n "$workdir" ] && [[ "$workdir" = /* ]]; then
        exec_args+=("--workdir" "$workdir")
    fi

    if ! docker exec "${exec_args[@]}" "$cid" /bin/sh -c "$cmd"; then
        warning "Lifecycle command failed in container: $cmd"
        return 1
    fi

    success "Lifecycle command executed inside container"
    return 0
}

# Execute lifecycle command with support for arrays and sudo
execute_lifecycle_command_with_config() {
    local config_key="$1"
    local execution_context="$2"  # "image" or "container"
    local image_or_container="$3"
    local user="${4:-}"
    local workdir="${5:-}"
    
    local config_file=""
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    fi

    if [ -z "$config_file" ]; then
        return 0
    fi

    # Check if command exists
    if ! command -v jq >/dev/null 2>&1 || ! jq -e ".$config_key" "$config_file" >/dev/null 2>&1; then
        return 0
    fi

    # Check for sudo variant
    local sudo_key="${config_key}Sudo"
    local use_sudo=false
    if jq -e ".$sudo_key" "$config_file" >/dev/null 2>&1; then
        use_sudo=$(jq -r ".$sudo_key" "$config_file")
    fi

    # Get command (handle both string and array)
    local cmd=""
    if jq -e ".$config_key | type" "$config_file" | grep -q "string"; then
        cmd=$(jq -r ".$config_key" "$config_file")
    elif jq -e ".$config_key | type" "$config_file" | grep -q "array"; then
        # Convert array to shell command string
        cmd=$(jq -r ".$config_key | join(\" \")" "$config_file")
    fi

    if [ -n "$cmd" ] && [ "$cmd" != "null" ]; then
        info "Executing $config_key..."
        
        # Add sudo if requested
        if [ "$use_sudo" = "true" ]; then
            cmd="sudo $cmd"
        fi
        
        # Execute based on context
        if [ "$execution_context" = "image" ]; then
            if ! run_lifecycle_command "$cmd" "$image_or_container" "$user" "$workdir"; then
                warning "$config_key failed, continuing..."
                return 1
            fi
        else
            if ! run_lifecycle_command_in_container "$cmd" "$image_or_container" "$user" "$workdir"; then
                warning "$config_key failed, continuing..."
                return 1
            fi
        fi
        
        success "$config_key executed successfully"
        return 0
    fi
}

# Execute onCreateCommand (runs during image build or container creation)
execute_on_create_command() {
    # Parse devcontainer config to get IMAGE_NAME
    parse_devcontainer_config || return 1
    execute_lifecycle_command_with_config "onCreateCommand" "image" "$IMAGE_NAME"
}

# Execute updateContentCommand (runs when content needs updating)
execute_update_content_command() {
    # Parse devcontainer config to get CONTAINER_USER and WORKSPACE_FOLDER
    parse_devcontainer_config || return 1
    # Find running container
    local container_id
    container_id=$(docker ps --filter "label=devcontainer.local_folder=$PROJECT_DIR" --format "{{.ID}}" | head -1)
    if [ -n "$container_id" ]; then
        execute_lifecycle_command_with_config "updateContentCommand" "container" "$container_id" "$CONTAINER_USER" "$WORKSPACE_FOLDER"
    else
        warning "No running container found for updateContentCommand"
    fi
}

# Execute postStartCommand (runs after container starts)
execute_post_start_command() {
    # Parse devcontainer config to get CONTAINER_USER and WORKSPACE_FOLDER
    parse_devcontainer_config || return 1
    # Find running container
    local container_id
    container_id=$(docker ps --filter "label=devcontainer.local_folder=$PROJECT_DIR" --format "{{.ID}}" | head -1)
    if [ -n "$container_id" ]; then
        execute_lifecycle_command_with_config "postStartCommand" "container" "$container_id" "$CONTAINER_USER" "$WORKSPACE_FOLDER"
    else
        warning "No running container found for postStartCommand"
    fi
}

# Execute postAttachCommand (runs when attaching to container)
execute_post_attach_command() {
    # Parse devcontainer config to get CONTAINER_USER and WORKSPACE_FOLDER
    parse_devcontainer_config || return 1
    # Find running container
    local container_id
    container_id=$(docker ps --filter "label=devcontainer.local_folder=$PROJECT_DIR" --format "{{.ID}}" | head -1)
    if [ -n "$container_id" ]; then
        execute_lifecycle_command_with_config "postAttachCommand" "container" "$container_id" "$CONTAINER_USER" "$WORKSPACE_FOLDER"
    else
        warning "No running container found for postAttachCommand"
    fi
}



# Parse lifecycle commands from devcontainer.json
parse_lifecycle_config() {
    local config_file=""
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    else
        return 0
    fi

    ON_CREATE_CMD=""
    if command -v jq >/dev/null 2>&1 && jq -e '.onCreateCommand' "$config_file" >/dev/null 2>&1; then
        ON_CREATE_CMD=$(jq -r '.onCreateCommand' "$config_file")
    fi

    UPDATE_CONTENT_CMD=""
    if command -v jq >/dev/null 2>&1 && jq -e '.updateContentCommand' "$config_file" >/dev/null 2>&1; then
        UPDATE_CONTENT_CMD=$(jq -r '.updateContentCommand' "$config_file")
    fi

    POST_START_CMD=""
    if command -v jq >/dev/null 2>&1 && jq -e '.postStartCommand' "$config_file" >/dev/null 2>&1; then
        POST_START_CMD=$(jq -r '.postStartCommand' "$config_file")
    fi

    return 0
}

# CLI interface
lifecycle_cli() {
    local cmd="$1"
    shift || true

    case "$cmd" in
        "run-on-create")
            execute_on_create_command
            ;;
        "run-update-content")
            execute_update_content_command
            ;;
        "run-post-start")
            execute_post_start_command
            ;;
        "run-post-attach")
            execute_post_attach_command
            ;;
        "list")
            local config_file=""
            if [ -f ".devcontainer/devcontainer.json" ]; then
                config_file=".devcontainer/devcontainer.json"
            elif [ -f ".devcontainer.json" ]; then
                config_file=".devcontainer.json"
            fi

            if [ -z "$config_file" ]; then
                echo "No devcontainer configuration found"
                return 0
            fi

            echo "Configured lifecycle commands:"
            if command -v jq >/dev/null 2>&1; then
                if jq -e '.onCreateCommand' "$config_file" >/dev/null 2>&1; then
                    echo "  onCreateCommand: $(jq -r '.onCreateCommand' "$config_file")"
                fi
                if jq -e '.updateContentCommand' "$config_file" >/dev/null 2>&1; then
                    echo "  updateContentCommand: $(jq -r '.updateContentCommand' "$config_file")"
                fi
                if jq -e '.postCreateCommand' "$config_file" >/dev/null 2>&1; then
                    echo "  postCreateCommand: $(jq -r '.postCreateCommand' "$config_file")"
                fi
                if jq -e '.postStartCommand' "$config_file" >/dev/null 2>&1; then
                    echo "  postStartCommand: $(jq -r '.postStartCommand' "$config_file")"
                fi
                if jq -e '.postAttachCommand' "$config_file" >/dev/null 2>&1; then
                    echo "  postAttachCommand: $(jq -r '.postAttachCommand' "$config_file")"
                fi
            else
                echo "  jq not available for parsing configuration"
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Usage: dcutil lifecycle <command>"
            echo ""
            echo "Commands:"
            echo "  list                    List configured lifecycle commands"
            echo "  run-on-create          Execute onCreateCommand"
            echo "  run-update-content     Execute updateContentCommand"
            echo "  run-post-start         Execute postStartCommand"
            echo "  run-post-attach        Execute postAttachCommand"
            echo "  help                   Show this help"
            ;;
        *)
            error_exit "Unknown lifecycle command: $cmd" "$EXIT_INVALID_ARGS"
            ;;
    esac
}
