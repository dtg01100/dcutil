#!/usr/bin/env bash

# Podman backend support for dcutil
# Provides Podman compatibility layer for Docker-native operations

# Source core functionality
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for Podman backend
PODMAN_AVAILABLE=false
PODMAN_VERSION=""
PODMAN_BACKEND_ENABLED=false
PODMAN_FALLBACK_ENABLED=false

# Check if Podman is available and functional
check_podman_availability() {
    if command -v podman >/dev/null 2>&1; then
        info "Podman found, checking functionality..."
        
        # Test basic Podman functionality
        if podman info >/dev/null 2>&1; then
            PODMAN_AVAILABLE=true
            local version_output
            version_output=$(podman --version)
            PODMAN_VERSION="${version_output##* }"
            PODMAN_VERSION="${PODMAN_VERSION#v}"
            success "Podman available: version $PODMAN_VERSION"
            return 0
        else
            warning "Podman command found but not functional (check permissions/daemon)"
            return 1
        fi
    else
        info "Podman not found in PATH"
        return 1
    fi
}

# Auto-detect backend preference
auto_detect_backend() {
    local preference="docker"
    
    # Check environment variable first
    if [ -n "${DCUTIL_BACKEND:-}" ]; then
        case "$DCUTIL_BACKEND" in
            "podman"|"true"|"1")
                if check_podman_availability; then
                    PODMAN_BACKEND_ENABLED=true
                    preference="podman"
                else
                    warning "Podman requested but not available, falling back to Docker"
                fi
                ;;
            "docker"|"false"|"0")
                PODMAN_BACKEND_ENABLED=false
                preference="docker"
                ;;
            *)
                warning "Unknown backend '$DCUTIL_BACKEND', using auto-detection"
                ;;
        esac
    fi
    
    # Auto-detection logic
    if [ "$PODMAN_BACKEND_ENABLED" = false ]; then
        if check_podman_availability && [ "$PODMAN_AVAILABLE" = true ]; then
            # Check if Docker is available for fallback
            if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
                PODMAN_FALLBACK_ENABLED=true
            else
                PODMAN_FALLBACK_ENABLED=false
            fi
        fi
        
        # Default to Docker if neither Podman nor Docker are preferred
        if [ "$PODMAN_AVAILABLE" = false ]; then
            :
        fi
    fi
    
    export DCUTIL_BACKEND="$preference"
    return 0
}

# Execute Podman command with Docker-compatible syntax
execute_podman_command() {
    local cmd="$1"
    shift
    
    # Convert Docker syntax to Podman syntax
    local podman_args=()
    
    # Process arguments for Podman compatibility
    while [ $# -gt 0 ]; do
        case "$1" in
            --platform)
                # Podman handles platform differently
                if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then
                    # Only add if not already handled by Podman
                    if [[ "$2" != "linux/amd64" && "$2" != "linux/arm64" ]]; then
                        podman_args+=(--platform "$2")
                    fi
                    shift 2
                else
                    podman_args+=("$1")
                    shift
                fi
                ;;
            --shm-size)
                # Podman uses --shm-size but syntax may differ
                if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then
                    podman_args+=(--shm-size "$2")
                    shift 2
                else
                    podman_args+=("$1")
                    shift
                fi
                ;;
            --add-host)
                # Podman supports --add-host
                if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then
                    podman_args+=(--add-host "$2")
                    shift 2
                else
                    podman_args+=("$1")
                    shift
                fi
                ;;
            --security-opt)
                # Convert Docker security options to Podman equivalents
                if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then
                    case "$2" in
                        "no-new-privileges")
                            podman_args+=(--security-opt "$2")
                            ;;
                        "apparmor="*)
                            # Podman may not support all AppArmor profiles
                            warning "AppArmor profiles may not be fully supported in Podman"
                            podman_args+=(--security-opt "$2")
                            ;;
                        "seccomp="*)
                            # Podman seccomp support
                            podman_args+=(--security-opt "$2")
                            ;;
                        *)
                            warning "Unknown security option for Podman: $2"
                            ;;
                    esac
                    shift 2
                else
                    podman_args+=("$1")
                    shift
                fi
                ;;
            --cap-add)
                # Podman capability support
                if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then
                    podman_args+=(--cap-add "$2")
                    shift 2
                else
                    podman_args+=("$1")
                    shift
                fi
                ;;
            --cap-drop)
                # Podman capability drop
                if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then
                    podman_args+=(--cap-drop "$2")
                    shift 2
                else
                    podman_args+=("$1")
                    shift
                fi
                ;;
            --device)
                # Podman device support
                if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then
                    podman_args+=(--device "$2")
                    shift 2
                else
                    podman_args+=("$1")
                    shift
                fi
                ;;
            --userns)
                # Podman user namespace support
                if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then
                    podman_args+=(--userns "$2")
                    shift 2
                else
                    podman_args+=("$1")
                    shift
                fi
                ;;
            *)
                # Pass through other arguments
                podman_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Execute the command
    info "Executing Podman: $cmd ${podman_args[*]}"
    if podman "$cmd" "${podman_args[@]}"; then
        return 0
    else
        local exit_code=$?
        
        # Try fallback to Docker if enabled
        if [ "$PODMAN_FALLBACK_ENABLED" = true ]; then
            warning "Podman command failed, attempting Docker fallback..."
            if docker "$cmd" "${@:1}"; then
                info "Docker fallback successful"
                return 0
            fi
        fi
        
        return $exit_code
    fi
}

# Podman-specific container operations
podman_docker_info() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        info "Podman backend: Getting system information..."
        execute_podman_command info
    else
        docker info "$@"
    fi
}

podman_docker_ps() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command ps "$@"
    else
        docker ps "$@"
    fi
}

podman_docker_images() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command images "$@"
    else
        docker images "$@"
    fi
}

podman_docker_pull() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command pull "$@"
    else
        docker pull "$@"
    fi
}

podman_docker_build() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command build "$@"
    else
        docker build "$@"
    fi
}

podman_docker_run() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command run "$@"
    else
        docker run "$@"
    fi
}

podman_docker_start() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command start "$@"
    else
        docker start "$@"
    fi
}

podman_docker_stop() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command stop "$@"
    else
        docker stop "$@"
    fi
}

podman_docker_kill() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command kill "$@"
    else
        docker kill "$@"
    fi
}

podman_docker_restart() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command restart "$@"
    else
        docker restart "$@"
    fi
}

podman_docker_rm() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command rm "$@"
    else
        docker rm "$@"
    fi
}

podman_docker_rmi() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command rmi "$@"
    else
        docker rmi "$@"
    fi
}

podman_docker_exec() {
    # Prefer official devcontainer CLI for exec
    if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
        execute_command_in_devcontainer "$PROJECT_DIR" "$@"
    elif [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command exec "$@"
    else
        docker exec "$@"
    fi
}

podman_docker_logs() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command logs "$@"
    else
        docker logs "$@"
    fi
}

podman_docker_inspect() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        execute_podman_command inspect "$@"
    else
        docker inspect "$@"
    fi
}

podman_docker_compose() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        info "Podman backend: Using podman-compose or podman play..."
        
        # Check if podman-compose is available
        if command -v podman-compose >/dev/null 2>&1; then
            info "Using podman-compose"
            podman-compose "$@"
        elif podman play kube >/dev/null 2>&1; then
            # Use podman play kube for Kubernetes YAML files
            warning "podman-compose not available, consider converting docker-compose.yml to Kubernetes format for podman play"
            return 1
        else
            error "Podman compose functionality not available"
            return 1
        fi
    else
        docker-compose "$@"
    fi
}

# Backend status and information
show_backend_status() {
    echo "Backend Configuration:"
    echo "====================="
    echo "Current Backend: $([ "$PODMAN_BACKEND_ENABLED" = true ] && echo "Podman" || echo "Docker")"
    echo "Podman Available: $PODMAN_AVAILABLE"
    echo "Podman Version: ${PODMAN_VERSION:-Not available}"
    echo "Docker Fallback: $([ "$PODMAN_FALLBACK_ENABLED" = true ] && echo "Enabled" || echo "Disabled")"
    echo "Backend Preference: ${DCUTIL_BACKEND:-auto}"
    
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        echo ""
        echo "Podman Features:"
        echo "- Rootless containers (if configured)"
        echo "- OCI runtime compatibility"
        echo "- Kubernetes YAML support via 'podman play kube'"
        echo "- Buildah integration for builds"
        
        if [ "$PODMAN_FALLBACK_ENABLED" = true ]; then
            echo "- Docker fallback for unsupported features"
        fi
    fi
}

# Validate backend configuration
validate_backend_config() {
    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        if [ "$PODMAN_AVAILABLE" = false ]; then
            error_exit "Podman backend requested but Podman is not available" "$EXIT_DOCKER_ERROR"
        fi
        
        # Check for required Podman features
        if ! podman info >/dev/null 2>&1; then
            error_exit "Podman is not running or accessible" "$EXIT_DOCKER_ERROR"
        fi
        
        success "Podman backend validated successfully"
    else
        # Validate Docker backend
        check_docker_daemon
        success "Docker backend validated successfully"
    fi
}

# Initialize Podman backend
init_podman_backend() {
    info "Initializing Podman backend support..."

    # Auto-detect backend preference
    auto_detect_backend

    # Validate configuration
    validate_backend_config

    if [ "$PODMAN_BACKEND_ENABLED" = true ]; then
        success "Podman backend initialized successfully"
        info "Using Podman version $PODMAN_VERSION"

        # Offer to apply Podman-specific tweaks to devcontainer.json
        offer_podman_tweaks
    fi
}

# Offer to apply Podman-specific tweaks to devcontainer.json
offer_podman_tweaks() {
    local config_file=""

    # Find devcontainer.json
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    elif [ -f "devcontainer.json" ]; then
        config_file="devcontainer.json"
    else
        # No devcontainer.json found, skip offering tweaks
        return 0
    fi

    # Check if tweaks are already applied
    if command -v jq >/dev/null 2>&1; then
        local has_security_opts
        local has_run_args
        has_security_opts=$(jq -e '.securityOpt // empty' "$config_file" 2>/dev/null || echo "false")
        has_run_args=$(jq -e '.runArgs // empty' "$config_file" 2>/dev/null || echo "false")

        if [ "$has_security_opts" != "false" ] || [ "$has_run_args" != "false" ]; then
            # Tweaks already appear to be applied
            return 0
        fi
    fi

    # Offer to apply Podman tweaks
    if confirm_prompt "Podman detected. Apply Podman-specific tweaks to $config_file? (recommended for better compatibility)"; then
        apply_podman_tweaks "$config_file"
    fi

    # Find devcontainer.json
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    elif [ -f "devcontainer.json" ]; then
        config_file="devcontainer.json"
    else
        # No devcontainer.json found, skip offering tweaks
        return 0
    fi

    # Check if tweaks are already applied
    if command -v jq >/dev/null 2>&1; then
        local has_security_opts
        local has_run_args
        has_security_opts=$(jq -e '.securityOpt // empty' "$config_file" 2>/dev/null || echo "false")
        has_run_args=$(jq -e '.runArgs // empty' "$config_file" 2>/dev/null || echo "false")
        info "has_security_opts: $has_security_opts, has_run_args: $has_run_args"

        if [ "$has_security_opts" != "false" ] || [ "$has_run_args" != "false" ]; then
            # Tweaks already appear to be applied
            info "Tweaks already applied, skipping"
            return 0
        fi
    else
        info "jq not available, will offer tweaks anyway"
    fi

    # Offer to apply Podman tweaks
    info "About to prompt for tweaks..."
    if confirm_prompt "Podman detected. Apply Podman-specific tweaks to $config_file? (recommended for better compatibility)"; then
        apply_podman_tweaks "$config_file"
    fi
}

# Apply Podman-specific tweaks to devcontainer.json
apply_podman_tweaks() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        warning "Config file $config_file not found"
        return 1
    fi

    info "Applying Podman-specific tweaks to $config_file..."

    if command -v jq >/dev/null 2>&1; then
        # Create backup
        cp "$config_file" "${config_file}.backup" 2>/dev/null || true

        # Apply tweaks using jq
        if jq '. + {
            "securityOpt": ["label:disable"],
            "runArgs": ["--userns=keep-id"]
        }' "$config_file" > "${config_file}.tmp" 2>/dev/null; then
            mv "${config_file}.tmp" "$config_file"
            success "Applied Podman tweaks: disabled SELinux labeling and enabled user namespace keep-id"
            # Validate with devcontainer CLI instead of strict JSON validation to handle comments
            if command -v devcontainer >/dev/null 2>&1; then
                devcontainer read-configuration --config "$config_file" >/dev/null 2>&1 || error_exit "Modified devcontainer config is invalid" "$EXIT_CONFIG_ERROR"
            else
                error_exit "devcontainer CLI not available for configuration validation" "$EXIT_DEVCONTAINER_ERROR"
            fi
        else
            warning "Failed to apply Podman tweaks with jq"
            # Restore backup if it exists
            [ -f "${config_file}.backup" ] && mv "${config_file}.backup" "$config_file" 2>/dev/null || true
            return 1
        fi

        # Clean up backup file
        rm -f "${config_file}.backup" 2>/dev/null || true
    else
        warning "jq not available, cannot apply Podman tweaks to $config_file"
        return 1
    fi
}

# Cleanup Podman backend state
cleanup_podman_backend() {
    PODMAN_AVAILABLE=false
    PODMAN_VERSION=""
    PODMAN_BACKEND_ENABLED=false
    PODMAN_FALLBACK_ENABLED=false
    info "Podman backend state cleaned up"
}