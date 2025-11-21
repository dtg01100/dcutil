#!/bin/bash

# Docker-native devcontainer operations for dcutil
# Replaces devcontainer CLI dependency with direct Docker operations

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables
CONTAINER_NAME=""
IMAGE_NAME=""

# Check Docker daemon availability
check_docker_daemon() {
    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not running or not accessible. Please start Docker." "$EXIT_DOCKER_ERROR"
    fi
}

# Parse devcontainer.json configuration
parse_devcontainer_config() {
    local config_file=""
    
    # Find devcontainer configuration
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    else
        error_exit "No devcontainer configuration found. Run 'dcutil init' first." "$EXIT_CONFIG_ERROR"
    fi

    # Validate JSON
    validate_json_if_available "$config_file"

    # Parse configuration using jq if available
    if command -v jq &> /dev/null; then
        CONTAINER_NAME="devcontainer_${PROJECT_DIR//\//_}_$(date +%s)"
        
        # Extract basic configuration
        IMAGE_NAME=$(jq -r '.image // "mcr.microsoft.com/devcontainers/base:ubuntu"' "$config_file")
        WORKSPACE_FOLDER=$(jq -r '.workspaceFolder // "/workspaces/${PWD##*/}"' "$config_file")
        CONTAINER_USER=$(jq -r '.containerUser // "vscode"' "$config_file")
        REMOTE_USER=$(jq -r '.remoteUser // .containerUser // "vscode"' "$config_file")
        
        # Extract mounts
        MOUNTS=()
        if jq -e '.mounts' "$config_file" >/dev/null 2>&1; then
            # Parse mounts from JSON array
            while IFS= read -r mount_spec; do
                if [ -n "$mount_spec" ] && [ "$mount_spec" != "null" ]; then
                    # The mount spec is already in Docker format: "source=...,target=...,type=..."
                    MOUNTS+=("$mount_spec")
                fi
            done < <(jq -r '.mounts[]' "$config_file" 2>/dev/null || echo "")
        fi
        
        # Extract features and other configurations
        FEATURES=()
        if jq -e '.features' "$config_file" >/dev/null 2>&1; then
            while IFS= read -r feature; do
                if [ -n "$feature" ]; then
                    FEATURES+=("$feature")
                fi
            done < <(jq -r 'to_entries[] | "\(.key)=\(.value|tostring)"' "$config_file" | grep "^features=" | cut -d= -f2-)
        fi
        
    else
        # Fallback parsing without jq
        IMAGE_NAME=$(grep -o '"image": *"[^"]*"' "$config_file" | sed 's/.*: *"\([^"]*\)".*/\1/' | head -1)
        IMAGE_NAME=${IMAGE_NAME:-"mcr.microsoft.com/devcontainers/base:ubuntu"}
        WORKSPACE_FOLDER=$(grep -o '"workspaceFolder": *"[^"]*"' "$config_file" | sed 's/.*: *"\([^"]*\)".*/\1/' | head -1)
        WORKSPACE_FOLDER=${WORKSPACE_FOLDER:-"/workspaces/${PWD##*/}"}
        CONTAINER_USER=$(grep -o '"containerUser": *"[^"]*"' "$config_file" | sed 's/.*: *"\([^"]*\)".*/\1/' | head -1)
        CONTAINER_USER=${CONTAINER_USER:-"vscode"}
        REMOTE_USER=$(grep -o '"remoteUser": *"[^"]*"' "$config_file" | sed 's/.*: *"\([^"]*\)".*/\1/' | head -1)
        REMOTE_USER=${REMOTE_USER:-"$CONTAINER_USER"}
    fi
}

# Build devcontainer image
docker_build() {
    info "Building devcontainer image..."
    check_docker_daemon
    parse_devcontainer_config
    
    # Check if there's a Dockerfile in .devcontainer
    if [ -f ".devcontainer/Dockerfile" ]; then
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
    if command -v jq &> /dev/null && jq -e '.postCreateCommand' "$config_file" >/dev/null 2>&1; then
        POST_CREATE_CMD=$(jq -r '.postCreateCommand' "$config_file")
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
        info "Using current directory as PROJECT_DIR"
    fi
    
    PROJECT_DIR="$project_dir"
    
    # Generate a valid container name
    local safe_name
    safe_name=$(basename "$PROJECT_DIR" | sed 's/[^a-zA-Z0-9_-]/_/g')
    CONTAINER_NAME="devcontainer_${safe_name}_$(date +%s)"
    
    info "Starting devcontainer setup..."
    check_docker_daemon
    parse_devcontainer_config
    
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
    
    # Build environment variables
    ENV_ARGS=()
    ENV_ARGS+=("-e" "REMOTE_USER=$REMOTE_USER")
    ENV_ARGS+=("-e" "WORKSPACE_FOLDER=$WORKSPACE_FOLDER")
    
    # Add VS Code server environment
    ENV_ARGS+=("-e" "GITHUB_TOKEN=${GITHUB_TOKEN:-}")
    ENV_ARGS+=("-e" "NODE_OPTIONS=${NODE_OPTIONS:---max-old-space-size=4096}")
    
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
    
    # Wait for container to be ready
    sleep 2
    
    # Run post-create commands if specified
    run_post_create_commands
    
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
    
    if [ -n "$config_file" ] && command -v jq &> /dev/null && jq -e '.postCreateCommand' "$config_file" >/dev/null 2>&1; then
        POST_CREATE_CMD=$(jq -r '.postCreateCommand' "$config_file")
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
    info "Restarting devcontainer..."
    docker_down
    sleep 1
    docker_up
    success "Devcontainer restarted successfully"
}

# Enter devcontainer
docker_enter() {
    info "Entering container..."
    check_docker_daemon
    
    # Check if container is running
    local container_id
    container_id=$(docker ps --filter "label=devcontainer.local_folder=$PROJECT_DIR" --format "{{.ID}}" 2>/dev/null | head -1)
    
    if [ -z "$container_id" ]; then
        warning "Container is not running. Starting it..."
        docker_up
        container_id=$(docker ps --filter "label=devcontainer.local_folder=$PROJECT_DIR" --format "{{.ID}}" 2>/dev/null | head -1)
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
    
    info "docker_status received project_dir: '$project_dir'"
    
    info "Checking container status..."
    check_docker_daemon
    
    local container_id
    container_id=$(docker ps --filter "label=devcontainer.local_folder=$project_dir" --format "{{.ID}}" 2>/dev/null | head -1)
    
    info "Looking for container with label: devcontainer.local_folder=$project_dir"
    
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
    info "Showing container logs..."
    check_docker_daemon
    
    local container_id
    container_id=$(docker ps --filter "label=devcontainer.local_folder=$PROJECT_DIR" --format "{{.ID}}" 2>/dev/null | head -1)
    
    if [ -z "$container_id" ]; then
        error_exit "No running devcontainer found for $PROJECT_DIR" "$EXIT_DEVCONTAINER_ERROR"
    fi
    
    if ! docker logs "$container_id" 2>/dev/null; then
        error_exit "Failed to show container logs" "$EXIT_DEVCONTAINER_ERROR"
    fi
}

# List running devcontainers
docker_list() {
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
    info "Cleaning up devcontainer..."
    check_docker_daemon
    
    # Stop and remove container
    docker down 2>/dev/null || true
    
    # Remove image if it's a custom build
    local config_file=""
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    fi
    
    if [ -n "$config_file" ] && [ -f ".devcontainer/Dockerfile" ]; then
        parse_devcontainer_config
        docker rmi "$IMAGE_NAME" 2>/dev/null || true
    fi
    
    success "Cleanup completed"
}

# Check if devcontainer CLI is available (for backward compatibility)
check_devcontainer_cli() {
    if command -v devcontainer &> /dev/null; then
        info "Using devcontainer CLI (available)"
        return 0
    else
        info "Using Docker-native operations (devcontainer CLI not available)"
        return 1
    fi
}