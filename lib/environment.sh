#!/bin/bash

# Environment management for dcutil
# Handles containerEnv, remoteEnv, and user management

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global environment variables
CONTAINER_ENV=()
REMOTE_ENV=()
CONTAINER_USER=""
REMOTE_USER=""

# Parse and validate environment variables from devcontainer.json
parse_environment_config() {
    local config_file=""
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    else
        return 0
    fi

    # Clear existing environment variables
    CONTAINER_ENV=()
    REMOTE_ENV=()

    if command -v jq >/dev/null 2>&1; then
        # Parse containerEnv
        if jq -e '.containerEnv' "$config_file" >/dev/null 2>&1; then
            while IFS='=' read -r key val; do
                if [ -n "$key" ] && [ -n "$val" ]; then
                    CONTAINER_ENV+=("$key=$val")
                    info "containerEnv: $key=$val"
                fi
            done < <(jq -r '.containerEnv | to_entries[] | "\(.key)=\(.value|tostring)"' "$config_file" 2>/dev/null || echo "")
        fi

        # Parse remoteEnv with variable expansion support
        if jq -e '.remoteEnv' "$config_file" >/dev/null 2>&1; then
            while IFS='=' read -r key val; do
                if [ -n "$key" ] && [ -n "$val" ]; then
                    # Expand environment variables in values (e.g., ${localEnv:default})
                    local expanded_val
                    expanded_val=$(expand_environment_variables "$val")
                    REMOTE_ENV+=("$key=$expanded_val")
                    info "remoteEnv: $key=$expanded_val"
                fi
            done < <(jq -r '.remoteEnv | to_entries[] | "\(.key)=\(.value|tostring)"' "$config_file" 2>/dev/null || echo "")
        fi

        # Parse user configuration
        CONTAINER_USER=$(jq -r '.containerUser // "vscode"' "$config_file" 2>/dev/null || echo "vscode")
        REMOTE_USER=$(jq -r '.remoteUser // .containerUser // "vscode"' "$config_file" 2>/dev/null || echo "vscode")
    else
        warning "jq not available, using default environment configuration"
        CONTAINER_USER="vscode"
        REMOTE_USER="vscode"
    fi

    return 0
}

# Expand environment variables in string values
expand_environment_variables() {
    local input="$1"
    local result="$input"
    
    # Handle ${localEnv:default} pattern
    while [[ "$result" =~ \$\{([^}:]+):([^}]*)\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local default_value="${BASH_REMATCH[2]}"
        local current_value="${!var_name:-$default_value}"
        result="${result/\$\{$var_name:$default_value\}/$current_value}"
    done
    
    # Handle ${localEnv} pattern
    while [[ "$result" =~ \$\{([^}]+)\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local current_value="${!var_name:-}"
        result="${result/\$\{$var_name\}/$current_value}"
    done
    
    # Handle $localEnv pattern
    while [[ "$result" =~ \$([a-zA-Z_][a-zA-Z0-9_]*) ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local current_value="${!var_name:-}"
        result="${result/\$$var_name/$current_value}"
    done
    
    echo "$result"
}

# Build Docker environment arguments from parsed configuration
build_container_env_args() {
    local env_args=()
    
    # Add standard environment variables
    env_args+=("-e" "REMOTE_USER=$REMOTE_USER")
    env_args+=("-e" "WORKSPACE_FOLDER=${WORKSPACE_FOLDER:-/workspaces/${PWD##*/}}")
    
    # Add container environment variables
    for env_var in "${CONTAINER_ENV[@]}"; do
        if [ -n "$env_var" ]; then
            env_args+=("-e" "$env_var")
            info "Adding container environment: $env_var"
        fi
    done
    
    # Add development environment variables
    env_args+=("-e" "GITHUB_TOKEN=${GITHUB_TOKEN:-}")
    env_args+=("-e" "NODE_OPTIONS=${NODE_OPTIONS:---max-old-space-size=4096}")
    
    printf '%s\n' "${env_args[@]}"
}

# Apply remote environment variables to running container
apply_remote_environment() {
    local container_id="$1"
    
    if [ -z "$container_id" ]; then
        error_exit "Container ID is required for applying remote environment" "$EXIT_INVALID_ARGS"
    fi
    
    if [ ${#REMOTE_ENV[@]} -eq 0 ]; then
        info "No remote environment variables to apply"
        return 0
    fi
    
    info "Applying remote environment variables to container..."
    
    # Apply environment variables directly to container
    for env_var in "${REMOTE_ENV[@]}"; do
        if [ -n "$env_var" ]; then
            local key="${env_var%%=*}"
            local value="${env_var#*=}"
            
            info "Remote environment: $env_var"
            
            # Add to user's bash profile for persistence
            docker exec "$container_id" /bin/sh -c "
                if [ -f /home/vscode/.bashrc ]; then
                    echo 'export $key=\"$value\"' >> /home/vscode/.bashrc
                elif [ -f /home/developer/.bashrc ]; then
                    echo 'export $key=\"$value\"' >> /home/developer/.bashrc
                fi
            " || true
        fi
    done
    
    success "Remote environment variables applied successfully"
}

# Validate environment variable names and values
validate_environment_variables() {
    local env_array=("$@")
    local invalid_vars=()
    
    for env_var in "${env_array[@]}"; do
        if [[ "$env_var" =~ ^[a-zA-Z_][a-zA-Z0-9_]*=.*$ ]]; then
            # Check for potentially dangerous values
            local value="${env_var#*=}"
            if [[ "$value" =~ [\$] ]] || [[ "$value" =~ [\`] ]] || [[ "$value" =~ [\(] ]] || [[ "$value" =~ [\)] ]]; then
                warning "Environment variable contains potentially unsafe characters: $env_var"
            fi
        else
            invalid_vars+=("$env_var")
        fi
    done
    
    if [ ${#invalid_vars[@]} -gt 0 ]; then
        error_exit "Invalid environment variable format: ${invalid_vars[*]}" "$EXIT_CONFIG_ERROR"
    fi
    
    return 0
}

# Set up user permissions and home directory
setup_user_environment() {
    local container_id="$1"
    
    if [ -z "$container_id" ]; then
        error_exit "Container ID is required for user environment setup" "$EXIT_INVALID_ARGS"
    fi
    
    info "Setting up user environment for $CONTAINER_USER..."
    
    # Check if user exists and set up home directory
    docker exec "$container_id" /bin/sh -c "
        # Check if user exists
        if id -u $CONTAINER_USER >/dev/null 2>&1; then
            # Set up home directory permissions
            if [ -d /home/$CONTAINER_USER ]; then
                chown -R $CONTAINER_USER:$CONTAINER_USER /home/$CONTAINER_USER 2>/dev/null || true
            fi
            
            # Add user to sudo group if needed and possible
            if command -v usermod >/dev/null 2>&1; then
                usermod -aG sudo $CONTAINER_USER 2>/dev/null || true
            fi
        else
            # User doesn't exist, check if we can create it
            if [ \$(id -u) -eq 0 ]; then
                useradd -m -s /bin/bash $CONTAINER_USER 2>/dev/null || true
            else
                echo 'Cannot create user $CONTAINER_USER: not running as root'
            fi
        fi
    " || warning "Failed to set up user environment"
    
    return 0
}

# List current environment configuration
list_environment_config() {
    local config_file=""
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    else
        echo "No devcontainer configuration found"
        return 0
    fi
    
    echo "Environment Configuration:"
    echo "========================="
    
    if command -v jq >/dev/null 2>&1; then
        echo "Container User: $(jq -r '.containerUser // "vscode"' "$config_file")"
        echo "Remote User: $(jq -r '.remoteUser // .containerUser // "vscode"' "$config_file")"
        
        if jq -e '.containerEnv' "$config_file" >/dev/null 2>&1; then
            echo ""
            echo "Container Environment Variables:"
            jq -r '.containerEnv | to_entries[] | "  \(.key)=\(.value)"' "$config_file"
        fi
        
        if jq -e '.remoteEnv' "$config_file" >/dev/null 2>&1; then
            echo ""
            echo "Remote Environment Variables:"
            jq -r '.remoteEnv | to_entries[] | "  \(.key)=\(.value)"' "$config_file"
        fi
    else
        echo "  jq not available for parsing configuration"
    fi
}

# CLI interface for environment management
environment_cli() {
    local cmd="$1"
    shift || true

    case "$cmd" in
        "list")
            list_environment_config
            ;;
        "validate")
            parse_environment_config
            validate_environment_variables "${CONTAINER_ENV[@]}" "${REMOTE_ENV[@]}"
            success "Environment variables are valid"
            ;;
        "apply-remote")
            local container_id="$1"
            if [ -z "$container_id" ]; then
                # Find running container by project label
                container_id=$(docker ps --filter "label=devcontainer.local_folder=$PROJECT_DIR" --format "{{.ID}}" | head -1)
            fi
            parse_environment_config
            apply_remote_environment "$container_id"
            ;;
        "setup-user")
            local container_id="$1"
            if [ -z "$container_id" ]; then
                # Find running container by project label
                container_id=$(docker ps --filter "label=devcontainer.local_folder=$PROJECT_DIR" --format "{{.ID}}" | head -1)
            fi
            parse_environment_config
            setup_user_environment "$container_id"
            ;;
        "help"|"-h"|"--help")
            echo "Usage: dcutil environment <command>"
            echo ""
            echo "Commands:"
            echo "  list                    List environment configuration"
            echo "  validate                Validate environment variables"
            echo "  apply-remote [cid]      Apply remote environment to container"
            echo "  setup-user [cid]        Set up user environment in container"
            echo "  help                    Show this help"
            ;;
        *)
            error_exit "Unknown environment command: $cmd" "$EXIT_INVALID_ARGS"
            ;;
    esac
}