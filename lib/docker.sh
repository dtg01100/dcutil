#!/usr/bin/env bash

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
            while IFS= read -r docker_mount; do
                if [ -n "$docker_mount" ]; then
                    # Expand variables in mount specification
                    local expanded_mount="$docker_mount"
                    expanded_mount="${expanded_mount//\$\{localWorkspaceFolder\}/$PROJECT_DIR}"
                    expanded_mount="${expanded_mount//\$\{localWorkspaceFolderBasename\}/${PROJECT_DIR##*/}}"
                    MOUNTS+=("$expanded_mount")
                fi
            done < <(jq -r '.mounts[] | if type == "object" then "type=\(.type),source=\(.source),target=\(.target)" else . end' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
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



# Start devcontainer
docker_up() {
    local project_dir="${1:-}"
    shift 1  # Remove project_dir from arguments

    # If project_dir is not provided, use current working directory
    if [ -z "$project_dir" ]; then
        project_dir="$(pwd)"
    fi

    PROJECT_DIR="$project_dir"

    info "Using official devcontainer CLI with dcutil enhancements..."
    devcontainer_cli_up "$project_dir" "$@"
    return $?
}

# Stop devcontainer
docker_down() {
    info "Using official devcontainer CLI to stop container with dcutil enhancements..."
    devcontainer_cli_down "$PROJECT_DIR"
    return $?
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

    # Execute post-start lifecycle commands (handles postStartCommand)
    if command -v execute_post_start_lifecycle_commands >/dev/null 2>&1; then
        execute_post_start_lifecycle_commands
    fi

    success "Devcontainer restarted successfully"
}

# Enter devcontainer
docker_enter() {
    local project_dir="${1:-}"

    info "(Using dcutil's enhanced entry UX with containers started via official CLI)"

    info "Entering container (using dcutil implementation)..."

    # Check if we're in Docker Compose mode
    if command -v is_compose_mode >/dev/null 2>&1 && is_compose_mode 2>/dev/null; then
        if [ -t 0 ]; then
            docker_compose_exec /bin/bash
        else
            docker_compose_exec sh
        fi
        return 0
    fi

    # Set container name for this project
    CONTAINER_NAME=$(get_container_name_for_project "$project_dir")
    info "Using container name: $CONTAINER_NAME"

    # Check if container exists and is running
    local container_exists=false
    local container_running=false

    if command -v execute_container_command >/dev/null 2>&1; then
        if execute_container_command container inspect "$CONTAINER_NAME" &>/dev/null; then
            container_exists=true
            if execute_container_command container inspect "$CONTAINER_NAME" | grep -q '"Running": true'; then
                container_running=true
    fi



    # If container exists but is not running, offer to start it
    if [ "$container_exists" = true ] && [ "$container_running" = false ]; then
        if [ -t 0 ]; then
            echo ""
            warning "Devcontainer exists but is not running."
            read -r -p "Would you like to start it? (y/N): " start_container
            if [[ "$start_container" =~ ^[Yy] ]]; then
                info "Starting devcontainer..."
                devcontainer_restart
                container_running=true
            else
                info "Devcontainer not started. Run 'dcutil up' to start it."
                return 0
            fi
        else
            error_exit "Devcontainer is not running. Run 'dcutil up' first." "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi
        fi
    else
        if docker container inspect "$CONTAINER_NAME" &>/dev/null; then
            container_exists=true
            if docker container inspect "$CONTAINER_NAME" | grep -q '"Running": true'; then
                container_running=true
            fi
        fi
    fi

    # If container doesn't exist, offer to create it
    if [ "$container_exists" = false ]; then
        if [ -t 0 ]; then
            echo ""
            warning "No devcontainer found for this project."
            read -r -p "Would you like to start the devcontainer first? (y/N): " start_container
            if [[ "$start_container" =~ ^[Yy] ]]; then
                info "Starting devcontainer..."
                docker_up "$project_dir"
                # After starting, the container should exist and be running
                container_exists=true
                container_running=true
            else
                info "Devcontainer not started. Run 'dcutil up' to start it."
                return 0
            fi
        else
            error_exit "No devcontainer found. Run 'dcutil up' first." "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi

    # If container exists but is not running, offer to start it
    if [ "$container_exists" = true ] && [ "$container_running" = false ]; then
        if [ -t 0 ]; then
            echo ""
            warning "Devcontainer exists but is not running."
            read -r -p "Would you like to start it? (y/N): " start_container
            if [[ "$start_container" =~ ^[Yy] ]]; then
                info "Starting devcontainer..."
                devcontainer_restart
                container_running=true
            else
                info "Devcontainer not started. Run 'dcutil up' to start it."
                return 0
            fi
        else
            error_exit "Devcontainer is not running. Run 'dcutil up' first." "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi

    # Now enter the running container
    if [ "$container_running" = true ]; then
        # Execute postAttachCommand if configured (runs when client connects to container)
        if command -v execute_post_attach_command >/dev/null 2>&1; then
            info "Running postAttachCommand for container attachment..."
            execute_post_attach_command
        fi

        if command -v execute_container_command >/dev/null 2>&1; then
            if [ -t 0 ]; then
                execute_container_command exec -it "$CONTAINER_NAME" /bin/bash
            else
                execute_container_command exec -i "$CONTAINER_NAME" /bin/sh
            fi
        else
            if [ -t 0 ]; then
                docker exec -it "$CONTAINER_NAME" /bin/bash
            else
                docker exec -i "$CONTAINER_NAME" /bin/sh
            fi
        fi
    fi
}

# Check devcontainer status
docker_status() {
    local project_dir="${1:-}"
    info "Checking container status..."

    # Set project directory
    if [ -z "$project_dir" ]; then
        project_dir="$(pwd)"
    fi
    PROJECT_DIR="$project_dir"

    # Set container name for this project
    CONTAINER_NAME=$(get_container_name_for_project "$project_dir")

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

    # Additional validation for the command string
    local cmd_string
    cmd_string=$(validate_user_input "$*" "command")
    info "Running command in container: $*"
    check_docker_daemon
    
    local container_id
    container_id=$(docker ps --filter "label=devcontainer.local_folder=$project_dir" --format "{{.ID}}" 2>/dev/null | head -1)
    
    if [ -z "$container_id" ]; then
        error_exit "No running devcontainer found for $project_dir" "$EXIT_DEVCONTAINER_ERROR"
    fi
    
    if ! docker exec "$container_id" /bin/sh -c "$*"; then
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

    # Remove devcontainer configuration files
    if [ -d "$PROJECT_DIR/.devcontainer" ]; then
        info "Removing devcontainer configuration directory..."
        rm -rf "$PROJECT_DIR/.devcontainer" 2>/dev/null || true
    fi

    if [ -f "$PROJECT_DIR/devcontainer.json" ]; then
        info "Removing devcontainer.json file..."
        rm -f "$PROJECT_DIR/devcontainer.json" 2>/dev/null || true
    fi

    if [ -f "$PROJECT_DIR/.devcontainer.json" ]; then
        info "Removing .devcontainer.json file..."
        rm -f "$PROJECT_DIR/.devcontainer.json" 2>/dev/null || true
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
                exit "$EXIT_SUCCESS"
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

# Execute a command inside the devcontainer: prefer devcontainer CLI, fall back to docker/podman exec
exec_in_container() {
    local cmd="$*"
    if command -v devcontainer >/dev/null 2>&1; then
        devcontainer exec --workspace-folder . /bin/bash -lc "$cmd"
        return $?
    fi

    local container_name
    container_name=$(get_container_name_for_project "${PROJECT_DIR:-$(pwd)}")
    if [ -z "${container_name}" ]; then
        error "Unable to determine container name for project"
        return 1
    fi

    # Prefer docker/podman via execute_container_command wrapper
    if command -v execute_container_command >/dev/null 2>&1; then
        execute_container_command exec -i "$container_name" /bin/sh -lc "$cmd"
        return $?
    else
        docker exec -i "$container_name" /bin/sh -lc "$cmd"
        return $?
    fi
}

# Backwards-compatible alias used across the codebase
run_in_container() {
    exec_in_container "$@"
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

    if ! ensure_container_running; then
        return 1
    fi

    docker_run "$PROJECT_DIR" "$@"
}

ensure_container_running() {
    # Get container name
    local container_name
    container_name=$(get_container_name_for_project "$PROJECT_DIR")

    if [ -z "$container_name" ]; then
        error "No container name determined for this project"
        return 1
    fi

    # Check if container exists and is running
    local container_exists=false
    local container_running=false

    if docker container inspect "$container_name" &>/dev/null; then
        container_exists=true
        if docker container inspect "$container_name" | grep -q '"Running": true'; then
            container_running=true
        fi
    fi

    if [ "$container_running" = false ]; then
        if [ "$container_exists" = true ]; then
            # Container exists but not running
            if [ -t 0 ]; then
                warning "Container exists but is not running."
                read -r -p "Start the container? (Y/n): " start_choice
                start_choice=${start_choice:-Y}
                if [[ "$start_choice" =~ ^[Yy] ]]; then
                    info "Starting container..."
                    docker start "$container_name" >/dev/null
                    success "Container started"
                    return 0
                else
                    error "Container not started. Command cancelled."
                    return 1
                fi
            else
                error "Container is not running. Run 'dcutil up' first."
                return 1
            fi
        else
            # Container doesn't exist
            if [ -t 0 ]; then
                warning "No container found for this project."
                read -r -p "Create and start the container? (Y/n): " create_choice
                create_choice=${create_choice:-Y}
                if [[ "$create_choice" =~ ^[Yy] ]]; then
                    info "Creating and starting container..."
                    docker_up "$PROJECT_DIR"
                    success "Container created and started"
                    return 0
                else
                    error "Container not created. Command cancelled."
                    return 1
                fi
            else
                error "No container found. Run 'dcutil up' first."
                return 1
            fi
        fi
    fi

    return 0
}

devcontainer_check() {
    info "Checking devcontainer configuration..."
    check_devcontainer_config
}

check_devcontainer_config() {
    local config_file=""
    local issues_found=false

    # Find config file
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    else
        error "No devcontainer configuration found. Run 'dcutil init' first."
        return 1
    fi

    info "Found configuration file: $config_file"

    # Check JSON syntax
    if ! jq empty "$config_file" 2>/dev/null; then
        error "Invalid JSON in $config_file"
        issues_found=true
    else
        success "JSON syntax is valid"
    fi

    # Check for duplicate mounts
    if jq -e '.mounts' "$config_file" >/dev/null 2>&1; then
        local mount_targets
        mount_targets=$(jq -r '.mounts[]?.target // empty' "$config_file" 2>/dev/null | sort | uniq -d)
        if [ -n "$mount_targets" ]; then
            error "Duplicate mount targets found: $mount_targets"
            issues_found=true
        else
            success "No duplicate mount targets"
        fi
    fi

    # Check container status
    local container_name
    container_name=$(get_container_name_for_project "$PROJECT_DIR")
    if [ -n "$container_name" ]; then
        if docker ps -a --filter "name=^${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"; then
            local container_status
            container_status=$(docker inspect "$container_name" --format "{{.State.Status}}" 2>/dev/null)
            if [ "$container_status" = "running" ]; then
                success "Container $container_name is running"
            else
                warning "Container $container_name exists but is $container_status"
            fi
        else
            info "No container found for this project"
        fi
    fi

    # Check for common issues
    if jq -e '.image' "$config_file" >/dev/null 2>&1; then
        success "Image specified in configuration"
    elif jq -e '.build.dockerfile' "$config_file" >/dev/null 2>&1; then
        success "Custom build specified in configuration"
    else
        warning "No image or build configuration specified in devcontainer.json"
    fi

    if [ "$issues_found" = true ]; then
        error "Issues found in devcontainer configuration"
        return 1
    else
        success "Devcontainer configuration looks good"
        return 0
    fi
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
    info "Using official devcontainer CLI for build with dcutil enhancements..."
    devcontainer_cli_build "$PROJECT_DIR"
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