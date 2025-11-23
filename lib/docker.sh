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

# Optional userprobe support
if [ -f "$(dirname "${BASH_SOURCE[0]}")/userprobe.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/userprobe.sh"
fi

# Optional merging support
if [ -f "$(dirname "${BASH_SOURCE[0]}")/merging.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/merging.sh"
fi

# Optional integration support
if [ -f "$(dirname "${BASH_SOURCE[0]}")/integration.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/integration.sh"
fi

# Optional advanced features support
if [ -f "$(dirname "${BASH_SOURCE[0]}")/advanced.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/advanced.sh"
fi

# Optional features support
if [ -f "$(dirname "${BASH_SOURCE[0]}")/features.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/features.sh"
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

# Helper to find the container name for a project by label; falls back to default
get_container_name_for_project() {
    local project_dir="${1:-$PROJECT_DIR}"
    if [ -z "$project_dir" ]; then
        echo ""
        return 1
    fi

    # Look for a container with a matching label first
    local container_name
    container_name=$(docker ps -a --filter "label=devcontainer.local_folder=$project_dir" --format "{{.Names}}" 2>/dev/null | head -1 || true)
    if [ -n "$container_name" ]; then
        echo "$container_name"
        return 0
    fi

    # Fallback to deterministic name
    echo "dcutil-$(basename "$project_dir")"
    return 0
}

# Helper to rename a conflicting container to avoid name collisions
rename_conflicting_container() {
    local name="$1"
    local ts
    ts=$(date +%s)
    local new_name="${name}-orphan-${ts}"
    info "Stopping existing container $name to avoid collisions"
    if docker ps -q --filter "name=^${name}$" | grep -q .; then
        docker stop "$name" 2>/dev/null || true
    fi
    info "Renaming existing container $name to $new_name to avoid name collision"
    if docker rename "$name" "$new_name" 2>/dev/null; then
        info "Renamed $name -> $new_name"
        return 0
    else
        # If rename failed (maybe due to removal race), attempt to force remove
        info "Failed to rename $name; attempting to remove it"
        docker rm -f "$name" 2>/dev/null || true
        return 0
    fi
    return 1
}

# Check container daemon availability (Docker or Podman)
check_container_daemon() {
    # Check if Podman backend is enabled and available
    if [ "${PODMAN_BACKEND_ENABLED:-false}" = true ] && command -v podman >/dev/null 2>&1; then
        if podman info &> /dev/null; then
            info "Using Podman container engine"
            return 0
        fi
    fi
    
    # Fallback to Docker
    if command -v docker >/dev/null 2>&1 && docker info &> /dev/null; then
        info "Using Docker container engine"
        return 0
    fi
    
    error_exit "No container engine found or accessible. Please install Docker or Podman." "$EXIT_DOCKER_ERROR"
}

# Backward compatibility alias
check_docker_daemon() {
    check_container_daemon "$@"
}

# Parse devcontainer.json configuration
parse_devcontainer_config() {
    local config_file=""
    
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    elif [ -f ".devcontainer/devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer/devcontainer.json"
    else
        error_exit "No devcontainer configuration found. Run 'dcutil init' first." "$EXIT_CONFIG_ERROR"
    fi
    
    DEVCONTAINER_CONFIG_FILE=$(realpath -m "$config_file" 2>/dev/null || echo "$config_file")
    
    # Validate JSON
    validate_json_if_available "$DEVCONTAINER_CONFIG_FILE"
    
    # Check if this is a Docker Compose configuration
    if command -v jq &> /dev/null && parse_compose_config 2>/dev/null; then
        info "Using Docker Compose configuration"
        return 0
    fi
    
    # Fall back to standard configuration
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
            # Expand known placeholders in workspace folder
            workspace_from_config="${workspace_from_config//\$\{localWorkspaceFolder\}/$PROJECT_DIR}"
            workspace_from_config="${workspace_from_config//\$\{localWorkspaceFolderBasename\}/${PROJECT_DIR##*/}}"
            WORKSPACE_FOLDER="$workspace_from_config"
        fi
        CONTAINER_USER=$(jq -r '.containerUser // "vscode"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "$CONTAINER_USER")
        REMOTE_USER=$(jq -r '.remoteUser // .containerUser // "vscode"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "$REMOTE_USER")

        # mounts
        if jq -e '.mounts' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS= read -r mount_spec; do
                # Expand variables in mount specification
                local expanded_mount="$mount_spec"
                expanded_mount="${expanded_mount//\$\{localWorkspaceFolder\}/$PROJECT_DIR}"
                expanded_mount="${expanded_mount//\$\{localWorkspaceFolderBasename\}/${PROJECT_DIR##*/}}"
                MOUNTS+=("$expanded_mount")
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
    
    # Check if enhanced build configuration is available
    if command -v parse_build_config >/dev/null 2>&1 && parse_build_config >/dev/null 2>&1; then
        # Use enhanced build for custom configurations
        docker_build_enhanced
    else
        # Fall back to standard image pull/build
        if [ -n "${IMAGE_NAME:-}" ]; then
            info "Pulling image: $IMAGE_NAME"
            if command -v execute_container_command >/dev/null 2>&1; then
                if execute_container_command pull "$IMAGE_NAME"; then
                    success "Image pulled successfully: $IMAGE_NAME"
                else
                    error_exit "Failed to pull image: $IMAGE_NAME" "$EXIT_DEVCONTAINER_ERROR"
                fi
            else
                if docker pull "$IMAGE_NAME"; then
                    success "Image pulled successfully: $IMAGE_NAME"
                else
                    error_exit "Failed to pull image: $IMAGE_NAME" "$EXIT_DEVCONTAINER_ERROR"
                fi
            fi
        else
            error_exit "No image or build configuration specified" "$EXIT_CONFIG_ERROR"
        fi
    fi
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

    # Debug summary
    info "DEVCONTAINER_CONFIG_FILE: ${DEVCONTAINER_CONFIG_FILE:-<none>}"
    info "Working dir: $PROJECT_DIR"
    info "Looking for compose: $(command -v is_compose_mode >/dev/null 2>&1 && is_compose_mode && echo yes || echo no)"

    # Parse build configuration first (if available)
    if command -v parse_build_config >/dev/null 2>&1; then
        info "Parsing build configuration..."
        parse_build_config >/dev/null 2>&1 || true
        info "parse_build_config completed"
    fi


    parse_devcontainer_config
    info "parse_devcontainer_config completed"

    info "Image: $IMAGE_NAME"
    info "ContainerUser: $CONTAINER_USER, RemoteUser: $REMOTE_USER, Workspace: $WORKSPACE_FOLDER"
    info "MOUNT_COUNT: ${#MOUNTS[@]}"
    info "TMPFS_COUNT: ${#TMPFS_LIST[@]}"
    
    # Merge image metadata with devcontainer.json if needed
    if command -v merge_image_metadata >/dev/null 2>&1 && needs_metadata_merging >/dev/null 2>&1; then
        merge_image_metadata
    fi
    
    # Check if we're in Docker Compose mode
    if command -v is_compose_mode >/dev/null 2>&1 && is_compose_mode 2>/dev/null; then
        docker_compose_up
        success "Devcontainer started successfully"
        return 0
    fi
    
# Override image name for custom builds
    if command -v is_custom_build >/dev/null 2>&1 && is_custom_build; then
        # Generate image name from project directory
        IMAGE_NAME="dcutil-${PWD##*/}:custom"
        info "Using custom build image: $IMAGE_NAME"
        
        # Build the custom image first
        info "Building custom devcontainer image..."
        if command -v execute_container_command >/dev/null 2>&1; then
            if ! execute_container_command build -t "$IMAGE_NAME" .; then
                error_exit "Failed to build custom devcontainer image" "$EXIT_DEVCONTAINER_ERROR"
            fi
        else
            if ! docker build -t "$IMAGE_NAME" .; then
                error_exit "Failed to build custom devcontainer image" "$EXIT_DEVCONTAINER_ERROR"
            fi
        fi
        success "Custom image built successfully: $IMAGE_NAME"
    fi
    
    # Generate container name from project directory (resolve existing container first)
    CONTAINER_NAME=$(get_container_name_for_project "$PROJECT_DIR")
    info "Using container name: $CONTAINER_NAME"

    info "Devcontainer config summary: image=$IMAGE_NAME workspace=$WORKSPACE_FOLDER containerUser=$CONTAINER_USER mounts=${#MOUNTS[@]}"

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
    # Default SSH port mapping - publish container port 2222 to a random host port to avoid collisions
    PORT_ARGS+=("-p" "2222")
    # Add any app ports from devcontainer.json
    for p in "${APP_PORTS[@]}"; do
        if [ -n "$p" ]; then
            PORT_ARGS+=("-p" "$p")
        fi
    done

    # Create container
    info "Creating container: $CONTAINER_NAME"

    # Build additional mount args for optional paths
    local OPTIONAL_MOUNTS=()
    if [ -d "/run/user/1000/keyring" ]; then
        OPTIONAL_MOUNTS+=("-v" "/run/user/1000/keyring:/run/user/1000/keyring")
    fi
    if [ -d "/tmp/.X11-unix" ]; then
        OPTIONAL_MOUNTS+=("-v" "/tmp/.X11-unix:/tmp/.X11-unix")
    fi

    # Create container in background to avoid hanging
    # If a container already exists with the intended name, attempt to rename it to avoid collisions
    if docker ps -a --filter "name=^${CONTAINER_NAME}$" --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$" 2>/dev/null; then
        info "Container name $CONTAINER_NAME already exists; renaming existing container to avoid collision"
        if ! rename_conflicting_container "$CONTAINER_NAME"; then
            warning "Failed to rename existing container; will attempt to create with a unique name"
            CONTAINER_NAME="${CONTAINER_NAME}-new-$(date +%s)"
            info "Using new container name: $CONTAINER_NAME"
        fi
    fi

    # If there are any containers for this project, remove them to avoid name and port conflicts
    local existing_cids
    existing_cids=$(docker ps -a --filter "label=devcontainer.local_folder=$PROJECT_DIR" --format '{{.ID}}' 2>/dev/null || true)
    if [ -n "$existing_cids" ]; then
        info "Removing existing container(s) for project to avoid conflicts: $existing_cids"
        for cid in $existing_cids; do
            docker rm -f "$cid" 2>/dev/null || true
        done
    fi

    # Also remove stale orphan containers matching the naming pattern (free ports)
    docker ps -a --filter "name=${CONTAINER_NAME}-orphan-" --format "{{.ID}} {{.Names}} {{.Status}}" | while read -r id name status; do
        if echo "$status" | grep -qE "Exited|Created|Dead"; then
            info "Removing stale orphan container: $name ($id)"
            docker rm -f "$id" 2>/dev/null || true
        else
            info "Stopping and removing running orphan container: $name ($id)"
            docker rm -f "$id" 2>/dev/null || true
        fi
    done || true

    docker create \
        --name "$CONTAINER_NAME" \
        --hostname "${PROJECT_DIR##*/}" \
        --user "$CONTAINER_USER" \
        --workdir "$WORKSPACE_FOLDER" \
        --label "devcontainer.local_folder=$PROJECT_DIR" \
        --label "devcontainer=true" \
        --cap-add=SYS_PTRACE \
        --security-opt="seccomp=unconfined" \
        "${OPTIONAL_MOUNTS[@]}" \
        "${PORT_ARGS[@]}" \
        "${ENV_ARGS[@]}" \
        "${MOUNT_ARGS[@]}" \
        "$IMAGE_NAME" \
        /bin/sh -c "while sleep 1000; do :; done" &
    local create_pid=$!
    wait $create_pid
    local create_result=$?

    if [ $create_result -ne 0 ]; then
        error "Failed to create devcontainer (docker create exited with $create_result)"
        # Try to get more info about the failure
        docker logs "$CONTAINER_NAME" 2>/dev/null || true
        error_exit "Failed to create devcontainer" "$EXIT_DEVCONTAINER_ERROR"
    fi
    
    # Get the container ID
    local container_id
    container_id=$(docker inspect -f '{{.Id}}' "$CONTAINER_NAME" 2>/dev/null)
    
    info "Container created: $container_id"
    
    # Start container
    if ! docker start "$CONTAINER_NAME" 2>/dev/null; then
        # If start failed because container already exists and is running, consider it OK
        if docker container inspect "$CONTAINER_NAME" &>/dev/null && docker container inspect "$CONTAINER_NAME" | grep -q '"Running": true'; then
            warning "Container $CONTAINER_NAME is already running; proceeding"
        else
            error_exit "Failed to start devcontainer" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi
    
    # Wait for container to be ready
    sleep 2

    # Finalize container start
    finalize_container_start "$CONTAINER_NAME" true
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

finalize_container_start() {
    local cont_name="$1"
    local was_created="${2:-false}"

    info "Finalizing container start: $cont_name (was_created=$was_created)"

    if [ "$was_created" = true ]; then
        run_post_create_commands
    fi

    if command -v execute_lifecycle_commands >/dev/null 2>&1; then
        execute_lifecycle_commands
    fi

    if command -v install_features >/dev/null 2>&1 && has_features >/dev/null 2>&1; then
        info "Installing Devcontainer Features..."
        install_features
    fi

    if command -v apply_advanced_features >/dev/null 2>&1 && has_advanced_features >/dev/null 2>&1; then
        info "Applying advanced features..."
        apply_advanced_features
    fi

    if command -v execute_post_start_command >/dev/null 2>&1; then
        execute_post_start_command
    fi

    if command -v apply_remote_environment >/dev/null 2>&1; then
        parse_environment_config
        apply_remote_environment "$cont_name"
    fi

    if command -v setup_user_environment >/dev/null 2>&1; then
        parse_environment_config
        setup_user_environment "$cont_name"
    fi

    if command -v execute_post_attach_command >/dev/null 2>&1; then
        execute_post_attach_command
    fi

    if command -v apply_tool_integration >/dev/null 2>&1 && has_tool_integration >/dev/null 2>&1; then
        info "Applying tool integration features..."
        apply_tool_integration
    fi

    if command -v apply_user_env_probe >/dev/null 2>&1 && has_user_env_probe >/dev/null 2>&1; then
        info "Applying user environment probing..."
        apply_user_env_probe
    fi

    success "Devcontainer started successfully"
}

# Stop devcontainer
docker_down() {
    info "Stopping devcontainer..."
    
    # Check if we're in Docker Compose mode
    if command -v is_compose_mode >/dev/null 2>&1 && is_compose_mode 2>/dev/null; then
        docker_compose_down
        return 0
    fi
    
    # Check if container exists
    if command -v execute_container_command >/dev/null 2>&1; then
        if ! execute_container_command container inspect "$CONTAINER_NAME" &>/dev/null; then
            info "No running devcontainer found"
            success "Devcontainer stopped"
            return 0
        fi
        
        # Stop container
        if ! execute_container_command stop "$CONTAINER_NAME" &>/dev/null; then
            error_exit "Failed to stop devcontainer" "$EXIT_DEVCONTAINER_ERROR"
        fi
    else
        if ! docker container inspect "$CONTAINER_NAME" &>/dev/null; then
            info "No running devcontainer found"
            success "Devcontainer stopped"
            return 0
        fi
        
        # Stop container
        if ! docker stop "$CONTAINER_NAME" &>/dev/null; then
            error_exit "Failed to stop devcontainer" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi
    
    success "Devcontainer stopped"
}

# Restart devcontainer
docker_restart() {
    info "Restarting devcontainer..."
    
    # Check if we're in Docker Compose mode
    if command -v is_compose_mode >/dev/null 2>&1 && is_compose_mode 2>/dev/null; then
        docker_compose_restart
        return 0
    fi
    
    # Check if container exists
    if command -v execute_container_command >/dev/null 2>&1; then
        if ! execute_container_command container inspect "$CONTAINER_NAME" &>/dev/null; then
            error_exit "No devcontainer found to restart. Run 'dcutil up' first." "$EXIT_DEVCONTAINER_ERROR"
        fi
        
        # Restart container
        if ! execute_container_command restart "$CONTAINER_NAME" &>/dev/null; then
            error_exit "Failed to restart devcontainer" "$EXIT_DEVCONTAINER_ERROR"
        fi
    else
        if ! docker container inspect "$CONTAINER_NAME" &>/dev/null; then
            error_exit "No devcontainer found to restart. Run 'dcutil up' first." "$EXIT_DEVCONTAINER_ERROR"
        fi
        
        # Restart container
        if ! docker restart "$CONTAINER_NAME" &>/dev/null; then
            error_exit "Failed to restart devcontainer" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi
    
    success "Devcontainer restarted successfully"
}

# Enter devcontainer
docker_enter() {
    info "Entering container..."
    
# Check if we're in Docker Compose mode
    if command -v is_compose_mode >/dev/null 2>&1 && is_compose_mode 2>/dev/null; then
        if [ -t 0 ]; then
            docker_compose_exec /bin/bash
        else
            docker_compose_exec sh
        fi
        return 0
    fi
    
    # Check if container exists and is running
    if command -v execute_container_command >/dev/null 2>&1; then
        if ! execute_container_command container inspect "$CONTAINER_NAME" &>/dev/null; then
            error_exit "No devcontainer found. Run 'dcutil up' first." "$EXIT_DEVCONTAINER_ERROR"
        fi
        
        if ! execute_container_command container inspect "$CONTAINER_NAME" | grep -q '"Running": true'; then
            error_exit "Devcontainer is not running. Run 'dcutil up' first." "$EXIT_DEVCONTAINER_ERROR"
        fi
        
        # Enter container
        if [ -t 0 ]; then
            execute_container_command exec -it "$CONTAINER_NAME" /bin/bash
        else
            execute_container_command exec -i "$CONTAINER_NAME" /bin/sh
        fi
    else
        if ! docker container inspect "$CONTAINER_NAME" &>/dev/null; then
            error_exit "No devcontainer found. Run 'dcutil up' first." "$EXIT_DEVCONTAINER_ERROR"
        fi
        
        if ! docker container inspect "$CONTAINER_NAME" | grep -q '"Running": true'; then
            error_exit "Devcontainer is not running. Run 'dcutil up' first." "$EXIT_DEVCONTAINER_ERROR"
        fi
        
        # Enter container
        if [ -t 0 ]; then
            docker exec -it "$CONTAINER_NAME" /bin/bash
        else
            docker exec -i "$CONTAINER_NAME" /bin/sh
        fi
    fi
}

# Check devcontainer status
docker_status() {
    info "Checking container status..."
    
    # Check if we're in Docker Compose mode
    if command -v is_compose_mode >/dev/null 2>&1 && is_compose_mode 2>/dev/null; then
        docker_compose_status
        return 0
    fi
    
# Check if container exists
    if command -v execute_container_command >/dev/null 2>&1; then
        if ! execute_container_command container inspect "$CONTAINER_NAME" &>/dev/null; then
            echo "Container is not running"
            return 0
        fi
        
        # Check if container is running
        if execute_container_command container inspect "$CONTAINER_NAME" | grep -q '"Running": true'; then
            echo "Container is running"
            
            # Show container details
            local container_ip
            container_ip=$(execute_container_command inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME" 2>/dev/null)
            if [ -n "$container_ip" ]; then
                echo "Container IP: $container_ip"
            fi
            
            # Show exposed ports
            local port_info
            port_info=$(execute_container_command inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}}{{end}}' "$CONTAINER_NAME" 2>/dev/null)
            if [ -n "$port_info" ] && [ "$port_info" != "<no value>" ]; then
                echo "Port mappings: $port_info"
            fi
        else
            echo "Container is stopped"
        fi
    else
        if ! docker container inspect "$CONTAINER_NAME" &>/dev/null; then
            echo "Container is not running"
            return 0
        fi
        
        # Check if container is running
        if docker container inspect "$CONTAINER_NAME" | grep -q '"Running": true'; then
            echo "Container is running"
            
            # Show container details
            local container_ip
            container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME" 2>/dev/null)
            if [ -n "$container_ip" ]; then
                echo "Container IP: $container_ip"
            fi
            
            # Show exposed ports
            local port_info
            port_info=$(docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}}{{end}}' "$CONTAINER_NAME" 2>/dev/null)
            if [ -n "$port_info" ] && [ "$port_info" != "<no value>" ]; then
                echo "Port mappings: $port_info"
            fi
        else
            echo "Container is stopped"
        fi
    fi
    
    # Check if container is running
    if docker container inspect "$CONTAINER_NAME" | grep -q '"Running": true'; then
        echo "Container is running"
        
        # Show container details
        local container_ip
        container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME" 2>/dev/null)
        if [ -n "$container_ip" ]; then
            echo "Container IP: $container_ip"
        fi
        
        # Show exposed ports
        local port_info
        port_info=$(docker port "$CONTAINER_NAME" 2>/dev/null)
        if [ -n "$port_info" ]; then
            echo "Exposed ports:"
            echo "$port_info"
        fi
    else
        echo "Container exists but is not running"
    fi
}

# Show devcontainer logs
docker_logs() {
    info "Showing container logs..."
    
    # Check if we're in Docker Compose mode
    if command -v is_compose_mode >/dev/null 2>&1 && is_compose_mode 2>/dev/null; then
        docker_compose_logs
        return 0
    fi
    
    # Check if container exists
    if command -v execute_container_command >/dev/null 2>&1; then
        if ! execute_container_command container inspect "$CONTAINER_NAME" &>/dev/null; then
            error_exit "No devcontainer found. Run 'dcutil up' first." "$EXIT_DEVCONTAINER_ERROR"
        fi
        
        # Show logs
        execute_container_command logs -f "$CONTAINER_NAME"
    else
        if ! docker container inspect "$CONTAINER_NAME" &>/dev/null; then
            error_exit "No devcontainer found. Run 'dcutil up' first." "$EXIT_DEVCONTAINER_ERROR"
        fi
        
        # Show logs
        docker logs -f "$CONTAINER_NAME"
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
    info "Cleaning up devcontainer..."
    
    # Check if we're in Docker Compose mode
    if command -v is_compose_mode >/dev/null 2>&1 && is_compose_mode 2>/dev/null; then
        docker_compose_clean
        return 0
    fi
    
    # Determine container name(s) for this project if not set
    local container_ids
    if [ -z "${CONTAINER_NAME:-}" ]; then
        container_ids=$(docker ps -a --filter "label=devcontainer.local_folder=$PROJECT_DIR" --format '{{.ID}}' 2>/dev/null || true)
    else
        container_ids=$(docker ps -a --filter "name=^${CONTAINER_NAME}$" --format '{{.ID}}' 2>/dev/null || true)
        # Also include any running orphans for this container name
        if [ -n "$CONTAINER_NAME" ]; then
            container_ids+=$" $(docker ps -a --filter "name=${CONTAINER_NAME}-orphan-" --format '{{.ID}}' 2>/dev/null || true)"
        fi
    fi

    # Remove all found containers for this project
    if [ -n "$container_ids" ]; then
        for cid in $container_ids; do
            if [ -n "$cid" ]; then
                if docker container inspect "$cid" &>/dev/null; then
                    if docker container inspect "$cid" | grep -q '"Running": true'; then
                        docker stop "$cid" &>/dev/null || true
                    fi
                    docker rm -f "$cid" &>/dev/null || true
                fi
            fi
        done
    fi
    
    # Remove volumes if requested
    if [ "${2:-}" = "--remove-volumes" ] || [ "${1:-}" = "--remove-volumes" ]; then
        # Find volumes associated with project containers
        local volume_names
        volume_names=$(docker ps -a --filter "label=devcontainer.local_folder=$PROJECT_DIR" --format '{{range .Mounts}}{{.Name}} {{end}}' 2>/dev/null || echo "")
        for volume in $volume_names; do
            if [ -n "$volume" ]; then
                docker volume rm "$volume" 2>/dev/null || true
            fi
        done
    fi
    
    # Remove orphan containers matching the naming scheme to keep CI clean
    if [ -n "${CONTAINER_NAME:-}" ]; then
        docker ps -a --filter "name=${CONTAINER_NAME}-orphan-" --format "{{.ID}} {{.Names}} {{.Status}}" | while read -r id name status; do
            info "Removing orphan container if exists: $name ($id)"
            docker rm -f "$id" 2>/dev/null || true
        done || true
    fi
    
    success "Devcontainer cleaned up"
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

# Rebuild devcontainer with preservation options
devcontainer_rebuild() {
    local force=false
    local preserve_volumes=false
    local preserve_ssh=false
    local preserve_agents=false
    local preserve_all=false
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --force|-f)
                force=true
                shift
                ;;
            --preserve-volumes)
                preserve_volumes=true
                shift
                ;;
            --preserve-ssh)
                preserve_ssh=true
                shift
                ;;
            --preserve-agents)
                preserve_agents=true
                shift
                ;;
            --preserve-all)
                preserve_all=true
                shift
                ;;
            --help|-h)
                echo "Usage: dcutil rebuild [options]"
                echo ""
                echo "Options:"
                echo "  --force, -f           Force rebuild without confirmation"
                echo "  --preserve-volumes    Preserve volume data"
                echo "  --preserve-ssh        Preserve SSH keys"
                echo "  --preserve-agents     Preserve installed agents"
                echo "  --preserve-all        Preserve all data (volumes, SSH, agents)"
                echo "  --help, -h           Show this help"
                exit $EXIT_SUCCESS
                ;;
            *)
                error_exit "Unknown rebuild option: $1. Use 'dcutil rebuild --help' for usage." 1
                ;;
        esac
    done
    
    info "Rebuilding devcontainer..."
    
    # Check preservation options
    if [ "$preserve_all" = true ]; then
        preserve_volumes=true
        preserve_ssh=true
        preserve_agents=true
    fi
    
    # Show what will be preserved
    info "Preservation options:"
    if [ "$preserve_volumes" = true ]; then
        info "  ✓ Volumes will be preserved"
    else
        info "  ✗ Volumes will be cleaned"
    fi
    
    if [ "$preserve_ssh" = true ]; then
        info "  ✓ SSH keys will be preserved"
    else
        info "  ✗ SSH keys will be cleaned"
    fi
    
    if [ "$preserve_agents" = true ]; then
        info "  ✓ AI agents will be preserved"
    else
        info "  ✗ AI agents will be cleaned"
    fi
    
    # Confirmation unless forced
    if [ "$force" != true ]; then
        echo ""
        read -r -p "Continue with rebuild? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy] ]]; then
            info "Rebuild cancelled"
            return 0
        fi
    fi
    
    # Stop existing container
    info "Stopping existing devcontainer..."
    devcontainer_down
    
    # Clean up based on preservation options
    if [ "$preserve_volumes" != true ]; then
        info "Cleaning volumes..."
        if command -v cleanup_volumes >/dev/null 2>&1; then
            cleanup_volumes
        fi
    fi
    
    if [ "$preserve_ssh" != true ]; then
        info "Cleaning SSH configuration..."
        if command -v cleanup_ssh >/dev/null 2>&1; then
            cleanup_ssh
        fi
    fi
    
    if [ "$preserve_agents" != true ]; then
        info "Cleaning AI agents..."
        if command -v cleanup_agents >/dev/null 2>&1; then
            cleanup_agents
        fi
    fi
    
    # Start new container
    info "Starting new devcontainer..."
    devcontainer_up
    
    success "Devcontainer rebuilt successfully"
}

# Wrapper functions that call Docker-native operations directly
devcontainer_up() {
    info "Starting devcontainer setup..."
    docker_up "$PROJECT_DIR"
    success "Devcontainer started successfully"
}

# Execute container command with backend support
execute_container_command() {
    local cmd="$1"
    shift
    
    if command -v execute_podman_command >/dev/null 2>&1 && [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command "$cmd" "$@"
    else
        docker "$cmd" "$@"
    fi
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
    if [ $# -eq 0 ]; then
        error_exit "run command requires a command to execute. Usage: dcutil run [project_path] <command>" "$EXIT_INVALID_ARGS"
    fi
    docker_run "$PROJECT_DIR" "$@"
}

devcontainer_build() {
    info "Building devcontainer image..."
    docker_build "$PROJECT_DIR"
    success "Devcontainer image built successfully"
}

devcontainer_clean() {
    info "Cleaning up devcontainer..."
    docker_clean "$PROJECT_DIR"
    success "Devcontainer cleaned up successfully"
}

# Docker Compose wrapper functions
devcontainer_compose_up() {
    info "Starting Docker Compose devcontainer..."
    docker_compose_up
    success "Docker Compose devcontainer started successfully"
}

devcontainer_compose_down() {
    info "Stopping Docker Compose devcontainer..."
    docker_compose_down
    success "Docker Compose devcontainer stopped successfully"
}

devcontainer_compose_restart() {
    info "Restarting Docker Compose devcontainer..."
    docker_compose_restart
    success "Docker Compose devcontainer restarted successfully"
}

devcontainer_compose_logs() {
    info "Showing Docker Compose devcontainer logs..."
    docker_compose_logs
}

devcontainer_compose_exec() {
    if [ $# -eq 0 ]; then
        error_exit "exec command requires a command to execute. Usage: dcutil compose exec <command>" "$EXIT_INVALID_ARGS"
    fi
    docker_compose_exec "$@"
}

devcontainer_compose_status() {
    info "Checking Docker Compose devcontainer status..."
    docker_compose_status
}

devcontainer_compose_build() {
    info "Building Docker Compose images..."
    docker_compose_build
}

devcontainer_compose_clean() {
    info "Cleaning up Docker Compose devcontainer..."
    docker_compose_clean
    success "Docker Compose devcontainer cleaned up successfully"
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

# Devcontainer Features wrapper functions
devcontainer_features_install() {
    info "Installing Devcontainer Features..."
    if command -v install_features >/dev/null 2>&1; then
        install_features
        success "Features installation completed"
    else
        error_exit "Features module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_features_info() {
    info "Showing Devcontainer Features information..."
    if command -v show_features_info >/dev/null 2>&1; then
        show_features_info
    else
        error_exit "Features module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_features_validate() {
    info "Validating Devcontainer Features configuration..."
    if command -v validate_features_config >/dev/null 2>&1; then
        validate_features_config
    else
        error_exit "Features module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_features_clean() {
    info "Cleaning Devcontainer Features cache..."
    if command -v clean_features_cache >/dev/null 2>&1; then
        clean_features_cache
        success "Features cache cleaned"
    else
        error_exit "Features module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_features_update() {
    info "Updating Devcontainer Features..."
    if command -v update_features >/dev/null 2>&1; then
        update_features
        success "Features update completed"
    else
        error_exit "Features module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_features_check_updates() {
    info "Checking for Devcontainer Features updates..."
    if command -v check_features_updates >/dev/null 2>&1; then
        check_features_updates
    else
        error_exit "Features module not available" "$EXIT_CONFIG_ERROR"
    fi
}

# Advanced Features wrapper functions
devcontainer_advanced_info() {
    info "Showing advanced features information..."
    if command -v show_advanced_features_info >/dev/null 2>&1; then
        show_advanced_features_info
    else
        error_exit "Advanced features module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_advanced_validate() {
    info "Validating advanced features configuration..."
    if command -v validate_advanced_features_config >/dev/null 2>&1; then
        validate_advanced_features_config
    else
        error_exit "Advanced features module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_advanced_apply() {
    info "Applying advanced features to running container..."
    if command -v apply_advanced_features >/dev/null 2>&1; then
        apply_advanced_features
        success "Advanced features applied successfully"
    else
        error_exit "Advanced features module not available" "$EXIT_CONFIG_ERROR"
    fi
}

# Integration wrapper functions
devcontainer_integration_info() {
    info "Showing integration information..."
    if command -v show_tool_integration_info >/dev/null 2>&1; then
        show_tool_integration_info
    else
        error_exit "Integration module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_integration_validate() {
    info "Validating integration configuration..."
    if command -v validate_tool_integration_config >/dev/null 2>&1; then
        validate_tool_integration_config
    else
        error_exit "Integration module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_integration_apply() {
    info "Applying integration features to running container..."
    if command -v apply_tool_integration >/dev/null 2>&1; then
        apply_tool_integration
        success "Integration features applied successfully"
    else
        error_exit "Integration module not available" "$EXIT_CONFIG_ERROR"
    fi
}

# Merging wrapper functions
devcontainer_merging_show() {
    info "Showing merged configuration..."
    if command -v show_merged_config >/dev/null 2>&1; then
        show_merged_config
    else
        error_exit "Merging module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_merging_validate() {
    info "Validating merged configuration..."
    if command -v validate_merged_config >/dev/null 2>&1; then
        validate_merged_config
    else
        error_exit "Merging module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_merging_cleanup() {
    info "Cleaning up merged configuration..."
    if command -v cleanup_merged_config >/dev/null 2>&1; then
        cleanup_merged_config
        success "Merged configuration cleaned up"
    else
        error_exit "Merging module not available" "$EXIT_CONFIG_ERROR"
    fi
}

# Userprobe wrapper functions
devcontainer_userprobe_probe() {
    info "Probing user environment..."
    if command -v probe_user_environment >/dev/null 2>&1; then
        probe_user_environment
        success "Environment probing completed"
    else
        error_exit "Userprobe module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_userprobe_show() {
    info "Showing probed environment..."
    if command -v show_probed_environment >/dev/null 2>&1; then
        show_probed_environment
    else
        error_exit "Userprobe module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_userprobe_apply() {
    info "Applying probed environment to container..."
    if command -v apply_probed_environment >/dev/null 2>&1; then
        apply_probed_environment
        success "Probed environment applied to container"
    else
        error_exit "Userprobe module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_userprobe_validate() {
    info "Validating userEnvProbe configuration..."
    if command -v validate_user_env_probe_config >/dev/null 2>&1; then
        validate_user_env_probe_config
    else
        error_exit "Userprobe module not available" "$EXIT_CONFIG_ERROR"
    fi
}

devcontainer_userprobe_cleanup() {
    info "Cleaning up probed environment..."
    if command -v cleanup_probed_environment >/dev/null 2>&1; then
        cleanup_probed_environment
        success "Probed environment cleaned up"
    else
        error_exit "Userprobe module not available" "$EXIT_CONFIG_ERROR"
    fi
}

# Initialize Podman backend on startup
if command -v init_podman_backend >/dev/null 2>&1; then
    init_podman_backend
fi