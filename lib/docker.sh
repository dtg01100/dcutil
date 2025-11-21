#!/bin/bash

# Docker-native devcontainer operations for dcutil
# Direct Docker operations without external dependencies

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Source additional modules if available
if [ -f "$(dirname "${BASH_SOURCE[0]}")/compose.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/compose.sh"
fi

if [ -f "$(dirname "${BASH_SOURCE[0]}")/build.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/build.sh"
fi

# Optional lifecycle support
if [ -f "$(dirname "${BASH_SOURCE[0]}")/lifecycle.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/lifecycle.sh"
fi

# Optional environment support
if [ -f "$(dirname "${BASH_SOURCE[0]}")/environment.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/environment.sh"
fi

# Global variables
CONTAINER_NAME=""
IMAGE_NAME=""
PROJECT_DIR=""

# Check Docker daemon availability
check_docker_daemon() {
    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not running or not accessible. Please start Docker." "$EXIT_DOCKER_ERROR"
    fi
}

# Parse devcontainer.json configuration
parse_devcontainer_config() {
    local config_file=""

    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    else
        error_exit "No devcontainer configuration found. Run 'dcutil init' first." "$EXIT_CONFIG_ERROR"
    fi

    DEVCONTAINER_CONFIG_FILE="$config_file"

    # Validate JSON
    validate_json_if_available "$DEVCONTAINER_CONFIG_FILE"

    # Defaults
    IMAGE_NAME="mcr.microsoft.com/devcontainers/base:ubuntu"
    WORKSPACE_FOLDER="/workspaces/${PWD##*/}"
    CONTAINER_USER="vscode"
    REMOTE_USER="vscode"
    MOUNTS=()
    FEATURES=()
    CONTAINER_ENV=()
    REMOTE_ENV=()
    PRIVILEGED=false
    CAP_ADD=()
    SECURITY_OPT=()
    TMPFS_LIST=()
    WAIT_FOR=()
    APP_PORTS=()
    SHUTDOWN_ACTION="stopContainer"
    
    # Check if custom build is configured and generate image name
    if command -v is_custom_build >/dev/null 2>&1 && is_custom_build; then
        # Generate image name from project directory
        IMAGE_NAME="dcutil-${PWD##*/}:custom"
        info "Generated custom image name: $IMAGE_NAME"
    fi

    if command -v jq &> /dev/null; then
        # Only parse image if not using custom build
        if ! command -v is_custom_build >/dev/null 2>&1 || ! is_custom_build; then
            IMAGE_NAME=$(jq -r '.image // env.IMAGE_NAME' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "$IMAGE_NAME")
        fi
        # Only update WORKSPACE_FOLDER if it's not null
        local workspace_from_config
        workspace_from_config=$(jq -r '.workspaceFolder // empty' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        if [ -n "$workspace_from_config" ] && [ "$workspace_from_config" != "null" ]; then
            WORKSPACE_FOLDER="$workspace_from_config"
        fi
        CONTAINER_USER=$(jq -r '.containerUser // "vscode"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "$CONTAINER_USER")
        REMOTE_USER=$(jq -r '.remoteUser // .containerUser // "vscode"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "$REMOTE_USER")

        # mounts
        if jq -e '.mounts' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS= read -r mount_spec; do
                MOUNTS+=("$mount_spec")
            done < <(jq -r '.mounts[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
        fi

        # features
        if jq -e '.features' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS= read -r id; do
                local v
                v=$(jq -r --arg id "$id" '.features[$id]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
                if [ "$v" != "false" ]; then
                    FEATURES+=("$id")
                fi
            done < <(jq -r '.features | keys[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
        fi

        # envs
        if jq -e '.containerEnv' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS='=' read -r key val; do
                CONTAINER_ENV+=("$key=$val")
            done < <(jq -r '.containerEnv | to_entries[] | "\(.key)=\(.value|tostring)"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
        fi
        if jq -e '.remoteEnv' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS='=' read -r key val; do
                REMOTE_ENV+=("$key=$val")
            done < <(jq -r '.remoteEnv | to_entries[] | "\(.key)=\(.value|tostring)"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
        fi

        # security
        if jq -e '.privileged' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            PRIVILEGED=$(jq -r '.privileged' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "$PRIVILEGED")
        fi
        if jq -e '.capAdd' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS= read -r cap; do
                CAP_ADD+=("$cap")
            done < <(jq -r '.capAdd[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
        fi
        if jq -e '.securityOpt' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS= read -r opt; do
                SECURITY_OPT+=("$opt")
            done < <(jq -r '.securityOpt[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
        fi
        if jq -e '.tmpfs' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS= read -r t; do
                TMPFS_LIST+=("$t")
            done < <(jq -r '.tmpfs[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
        fi

        # services
        if jq -e '.waitFor' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS= read -r w; do
                WAIT_FOR+=("$w")
            done < <(jq -r '.waitFor[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
        fi
        if jq -e '.appPort' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS= read -r p; do
                APP_PORTS+=("$p")
            done < <(jq -r '.appPort[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
        fi

        SHUTDOWN_ACTION=$(jq -r '.shutdownAction // "stopContainer"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "$SHUTDOWN_ACTION")
    fi
}


# Build devcontainer image
docker_build() {
    info "Building devcontainer image..."
    check_docker_daemon
    parse_devcontainer_config

    # Check for custom build configuration
    if command -v is_custom_build >/dev/null 2>&1 && is_custom_build; then
        info "Using custom build configuration"
        build_custom_image "$IMAGE_NAME"
    elif [ -f ".devcontainer/Dockerfile" ]; then
        # Fallback: simple Dockerfile build
        info "Building custom Dockerfile..."
        if ! docker build -f .devcontainer/Dockerfile -t "$IMAGE_NAME" . 2>/dev/null; then
            error_exit "Failed to build devcontainer image" "$EXIT_DEVCONTAINER_ERROR"
        fi
    else
        info "Using base image: $IMAGE_NAME"
        # Pull the image to ensure it's available
        if ! docker pull "$IMAGE_NAME" 2>/dev/null; then
            error_exit "Failed to pull image: $IMAGE_NAME" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi
    
    # Run postCreateCommand if specified
    if command -v jq &> /dev/null && jq -e '.postCreateCommand' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
        POST_CREATE_CMD=$(jq -r '.postCreateCommand' "$DEVCONTAINER_CONFIG_FILE")
        info "Running post-create command..."
        # This would need to be run in a temporary container for full compatibility
    fi
    
    success "Build completed"
}

# Start devcontainer
docker_up() {
    local project_dir="${1:-}"

    # If project_dir is not provided, use current working directory
    if [ -z "$project_dir" ]; then
        project_dir="$(pwd)"
    fi

    PROJECT_DIR="$project_dir"
    info "Starting devcontainer setup..."
    check_docker_daemon

    # Parse build configuration first (if available)
    if command -v parse_build_config >/dev/null 2>&1; then
        parse_build_config
    fi

    parse_devcontainer_config
    
    # Override image name for custom builds
    if command -v is_custom_build >/dev/null 2>&1 && is_custom_build; then
        # Generate image name from project directory
        IMAGE_NAME="dcutil-${PWD##*/}:custom"
        info "Using custom build image: $IMAGE_NAME"
    fi

    # Build custom image if needed
    if command -v is_custom_build >/dev/null 2>&1 && is_custom_build; then
        docker_build
    fi

    # Check if project-home option is enabled
    if [ "${DCUTIL_PROJECT_HOME_ENABLED:-false}" = true ]; then
        info "Setting container home folder to project directory..."
        # Add project directory as home mount
        HOME_MOUNT="--mount type=bind,source=$PROJECT_DIR,target=/home/$CONTAINER_USER"
    fi
    
    # Build mount arguments from JSON config
    MOUNT_ARGS=()
    for mount in "${MOUNTS[@]}"; do
        # Mount is already in Docker format: "source=...,target=...,type=..."
        MOUNT_ARGS+=("--mount" "$mount")
    done
    
    # Only add default workspace mount if none are specified in config
    if [ ${#MOUNTS[@]} -eq 0 ] && [ "${DCUTIL_PROJECT_HOME_ENABLED:-false}" != true ]; then
        MOUNT_ARGS+=("--mount" "type=bind,source=$PROJECT_DIR,target=$WORKSPACE_FOLDER,consistency=cached")
    fi
    
    # Add home mount if enabled
    if [ -n "${HOME_MOUNT:-}" ]; then
        MOUNT_ARGS+=("$HOME_MOUNT")
    fi
    
    # Build environment variables using environment module if available
    ENV_ARGS=()
    if command -v build_container_env_args >/dev/null 2>&1; then
        # Use environment module for comprehensive environment handling
        parse_environment_config
        while IFS= read -r env_arg; do
            ENV_ARGS+=("$env_arg")
        done < <(build_container_env_args)
    else
        # Fallback to basic environment variables
        ENV_ARGS+=("-e" "REMOTE_USER=$REMOTE_USER")
        ENV_ARGS+=("-e" "WORKSPACE_FOLDER=$WORKSPACE_FOLDER")
        
        # Add container environment variables if parsed
        for env_var in "${CONTAINER_ENV[@]}"; do
            if [ -n "$env_var" ]; then
                ENV_ARGS+=("-e" "$env_var")
            fi
        done
        
        # Add VS Code server environment
        ENV_ARGS+=("-e" "GITHUB_TOKEN=${GITHUB_TOKEN:-}")
        ENV_ARGS+=("-e" "NODE_OPTIONS=${NODE_OPTIONS:---max-old-space-size=4096}")
    fi
    
    # Build port mappings
    PORT_ARGS=()
    # Default SSH port if not specified
    PORT_ARGS+=("-p" "2222:2222")
    
    # Create container
    info "Creating container: $CONTAINER_NAME"
    
    local container_id
    container_id=$(docker create \
        --name "$CONTAINER_NAME" \
        --hostname "${PROJECT_DIR##*/}" \
        --user "$CONTAINER_USER" \
        --workdir "$WORKSPACE_FOLDER" \
        --label "devcontainer.local_folder=$PROJECT_DIR" \
        --label "devcontainer=true" \
        --cap-add=SYS_PTRACE \
        --security-opt="seccomp=unconfined" \
        -v "/run/user/1000/keyring:/run/user/1000/keyring" \
        -v "/tmp/.X11-unix:/tmp/.X11-unix" \
        "${PORT_ARGS[@]}" \
        "${ENV_ARGS[@]}" \
        "${MOUNT_ARGS[@]}" \
        "$IMAGE_NAME" \
        /bin/sh -c "while sleep 1000; do :; done" 2>/dev/null)
    
    if [ -z "$container_id" ]; then
        error_exit "Failed to create devcontainer" "$EXIT_DEVCONTAINER_ERROR"
    fi
    
    info "Container created: $container_id"
    
    # Start container
    if ! docker start "$CONTAINER_NAME" 2>/dev/null; then
        error_exit "Failed to start devcontainer" "$EXIT_DEVCONTAINER_ERROR"
    fi
    
    # Wait for container to be ready
    sleep 2

    # Run post-create commands if specified
    run_post_create_commands

    # Run post-start command if specified
    if command -v execute_post_start_command >/dev/null 2>&1; then
        execute_post_start_command
    fi

    # Apply remote environment variables if specified
    if command -v apply_remote_environment >/dev/null 2>&1; then
        parse_environment_config
        apply_remote_environment "$CONTAINER_NAME"
    fi

    # Set up user environment if specified
    if command -v setup_user_environment >/dev/null 2>&1; then
        parse_environment_config
        setup_user_environment "$CONTAINER_NAME"
    fi

    success "Devcontainer started successfully"
}

# Run post-create commands
run_post_create_commands() {
    local config_file=""
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    fi
    
    if [ -n "$DEVCONTAINER_CONFIG_FILE" ] && command -v jq &> /dev/null && jq -e '.postCreateCommand' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
        POST_CREATE_CMD=$(jq -r '.postCreateCommand' "$DEVCONTAINER_CONFIG_FILE")
        info "Running post-create command..."
        if ! docker exec "$CONTAINER_NAME" /bin/sh -c "$POST_CREATE_CMD" 2>/dev/null; then
            warning "Post-create command failed (continuing anyway)"
        fi
    fi
}

# Stop devcontainer
docker_down() {
    local project_dir="${1:-}"
    
    # If project_dir is not provided, use current working directory
    if [ -z "$project_dir" ]; then
        project_dir="$(pwd)"
    fi
    
    info "Stopping devcontainer..."
    check_docker_daemon
    
    # Check if using Docker Compose
    if command -v is_compose_mode >/dev/null 2>&1 && command -v parse_compose_config >/dev/null 2>&1; then
        parse_compose_config
        if is_compose_mode; then
            compose_down "$project_dir"
            success "Devcontainer stopped successfully (Docker Compose mode)"
            return 0
        fi
    fi
    
    # Fall back to standard Docker container operations
    
    # Find container by project directory label
    local container_id
    container_id=$(docker ps --filter "label=devcontainer.local_folder=$project_dir" --format "{{.ID}}" 2>/dev/null | head -1)
    
    if [ -n "$container_id" ]; then
        if ! docker stop "$container_id" 2>/dev/null; then
            error_exit "Failed to stop devcontainer" "$EXIT_DEVCONTAINER_ERROR"
        fi
        # Remove container
        docker rm "$container_id" 2>/dev/null || true
    else
        info "No running devcontainer found"
    fi
    
    success "Devcontainer stopped"
}

# Restart devcontainer
docker_restart() {
    local project_dir="${1:-}"
    docker_down "$project_dir"
    sleep 1
    docker_up "$project_dir"
    success "Devcontainer restarted successfully"
}

# Enter devcontainer
docker_enter() {
    local project_dir="${1:-}"
    
    # If project_dir is not provided, use current working directory
    if [ -z "$project_dir" ]; then
        project_dir="$(pwd)"
    fi
    
    info "Entering container..."
    check_docker_daemon
    
    # Check if container is running
    local container_id
    container_id=$(docker ps --filter "label=devcontainer.local_folder=$project_dir" --format "{{.ID}}" 2>/dev/null | head -1)
    
    if [ -z "$container_id" ]; then
        warning "Container is not running. Starting it..."
        docker_up "$project_dir"
        container_id=$(docker ps --filter "label=devcontainer.local_folder=$project_dir" --format "{{.ID}}" 2>/dev/null | head -1)
    fi
    
    # Enter container
    if ! docker exec -it "$container_id" /bin/bash; then
        error_exit "Failed to enter container" "$EXIT_DEVCONTAINER_ERROR"
    fi
}

# Check devcontainer status
docker_status() {
    local project_dir="${1:-}"
    
    # If project_dir is not provided, use current working directory
    if [ -z "$project_dir" ]; then
        project_dir="$(pwd)"
    fi
    
    info "Checking container status..."
    check_docker_daemon
    
    # Check if using Docker Compose
    if command -v is_compose_mode >/dev/null 2>&1 && command -v parse_compose_config >/dev/null 2>&1; then
        parse_compose_config
        if is_compose_mode; then
            compose_status "$project_dir"
            return 0
        fi
    fi
    
    # Fall back to standard Docker container operations
    
    local container_id
    container_id=$(docker ps --filter "label=devcontainer.local_folder=$project_dir" --format "{{.ID}}" 2>/dev/null | head -1)
    
    if [ -n "$container_id" ]; then
        local status
        status=$(docker inspect "$container_id" --format='{{.State.Status}}' 2>/dev/null)
        if [ "$status" = "running" ]; then
            echo "Container is running"
        else
            echo "Container is $status"
        fi
    else
        echo "Container is not running"
    fi
}

# Show devcontainer logs
docker_logs() {
    local project_dir="${1:-}"
    
    # If project_dir is not provided, use current working directory
    if [ -z "$project_dir" ]; then
        project_dir="$(pwd)"
    fi
    
    info "Showing container logs..."
    check_docker_daemon
    
    local container_id
    container_id=$(docker ps --filter "label=devcontainer.local_folder=$project_dir" --format "{{.ID}}" 2>/dev/null | head -1)
    
    if [ -z "$container_id" ]; then
        error_exit "No running devcontainer found for $project_dir" "$EXIT_DEVCONTAINER_ERROR"
    fi
    
    if ! docker logs "$container_id" 2>/dev/null; then
        error_exit "Failed to show container logs" "$EXIT_DEVCONTAINER_ERROR"
    fi
}

# List running devcontainers
docker_list() {
    local project_dir="${1:-}"
    
    # If project_dir is not provided, use current working directory
    if [ -z "$project_dir" ]; then
        project_dir="$(pwd)"
    fi
    
    info "Listing running devcontainers..."
    check_docker_daemon
    
    if ! docker ps --filter "label=devcontainer=true" --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}" 2>/dev/null | grep -v "CONTAINER ID"; then
        echo "No running devcontainers found"
    fi
}

# Run command in devcontainer
docker_run() {
    local project_dir="$1"
    shift  # Remove project_dir from arguments
    validate_run_command "$@"
    info "Running command in container: $*"
    check_docker_daemon
    
    local container_id
    container_id=$(docker ps --filter "label=devcontainer.local_folder=$project_dir" --format "{{.ID}}" 2>/dev/null | head -1)
    
    if [ -z "$container_id" ]; then
        error_exit "No running devcontainer found for $project_dir" "$EXIT_DEVCONTAINER_ERROR"
    fi
    
    if ! docker exec "$container_id" "$@"; then
        error_exit "Failed to run command in container" "$EXIT_DEVCONTAINER_ERROR"
    fi
}

# Clean up devcontainer
docker_clean() {
    local project_dir="${1:-}"
    
    # If project_dir is not provided, use current working directory
    if [ -z "$project_dir" ]; then
        project_dir="$(pwd)"
    fi
    
    info "Cleaning up devcontainer..."
    check_docker_daemon
    
    # Stop and remove container
    docker_down "$project_dir" 2>/dev/null || true
    
    # Remove image if it's a custom build
    local config_file=""
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    fi
    
    if [ -n "$DEVCONTAINER_CONFIG_FILE" ] && [ -f ".devcontainer/Dockerfile" ]; then
        parse_devcontainer_config
        docker rmi "$IMAGE_NAME" 2>/dev/null || true
    fi
    
    success "Cleanup completed"
}

# Check if Docker is available (always true for this implementation)
check_devcontainer_cli() {
    check_docker_daemon
}

# Check what devcontainer solution is available (Docker-native only)
check_devcontainer_availability() {
    info "Using Docker-native operations (devcontainer CLI dependency removed)"
    return 0
}

# Dependency checking functions - simplified since we only support Docker
check_devcontainer_cli() {
    check_docker_daemon
}

# Wrapper functions that call Docker-native operations directly
devcontainer_up() {
    info "Starting devcontainer setup..."
    docker_up "$PROJECT_DIR"
    success "Devcontainer started successfully"
}

devcontainer_down() {
    info "Stopping devcontainer..."
    docker_down "$PROJECT_DIR"
    success "Devcontainer stopped"
}

devcontainer_restart() {
    info "Restarting devcontainer..."
    docker_restart "$PROJECT_DIR"
    success "Devcontainer restarted successfully"
}

devcontainer_enter() {
    info "Entering container..."
    docker_enter "$PROJECT_DIR"
}

devcontainer_status() {
    info "Checking container status..."
    docker_status "$PROJECT_DIR"
}

devcontainer_logs() {
    info "Showing container logs..."
    docker_logs "$PROJECT_DIR"
}

devcontainer_list() {
    info "Listing running devcontainers..."
    docker_list "$PROJECT_DIR"
}

devcontainer_run() {
    validate_run_command "$@"
    info "Running command in container: $*"
    docker_run "$PROJECT_DIR" "$@"
}

devcontainer_build() {
    info "Building devcontainer image..."
    docker_build "$PROJECT_DIR"
    success "Build completed"
}

devcontainer_clean() {
    info "Cleaning up devcontainer..."
    docker_clean "$PROJECT_DIR"
    success "Cleanup completed"
}