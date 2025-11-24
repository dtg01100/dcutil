#!/usr/bin/env bash

# Docker Compose support for dcutil
# Handles docker-compose.yml based devcontainer configurations

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for Docker Compose
DOCKER_COMPOSE_FILE=""
COMPOSE_SERVICE=""
RUN_SERVICES=()
COMPOSE_PROJECT_NAME=""
COMPOSE_PROFILES=()
COMPOSE_PROFILES_STR=""
COMPOSE_RESTART_POLICY=""
COMPOSE_DEPENDENCIES=()

# Check if Docker Compose is available
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error_exit "Docker Compose is not available. Please install Docker Compose." "$EXIT_DOCKER_ERROR"
    fi
}

# Get the preferred Docker Compose command
get_compose_command() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null; then
        echo "docker compose"
    else
        error_exit "Docker Compose is not available." "$EXIT_DOCKER_ERROR"
    fi
}

# Parse Docker Compose configuration from devcontainer.json
parse_compose_config() {
    if command -v jq &> /dev/null; then
        # Check if dockerComposeFile is specified
        local compose_files
        compose_files=$(jq -r '.dockerComposeFile // empty' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        
        if [ -n "$compose_files" ] && [ "$compose_files" != "null" ]; then
            # Handle both string and array types for dockerComposeFile
            if [ "$(jq -r '.dockerComposeFile | type' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)" = "array" ]; then
                # Array of compose files
                DOCKER_COMPOSE_FILE=""
                while IFS= read -r file; do
                    if [ -n "$file" ] && [ "$file" != "null" ]; then
                        local expanded_file
                        expanded_file=$(echo "$file" | sed "s|\${workspaceFolder}|$PROJECT_DIR|g" | sed "s|\${localWorkspaceFolder}|$PROJECT_DIR|g")
                        if [ -f "$expanded_file" ]; then
                            if [ -z "$DOCKER_COMPOSE_FILE" ]; then
                                DOCKER_COMPOSE_FILE="$expanded_file"
                            else
                                DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_FILE -f $expanded_file"
                            fi
                        else
                            warning "Docker Compose file not found: $expanded_file"
                        fi
                    fi
                done < <(jq -r '.dockerComposeFile[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
            else
                # Single compose file
                DOCKER_COMPOSE_FILE=$(echo "$compose_files" | sed "s|\${workspaceFolder}|$PROJECT_DIR|g" | sed "s|\${localWorkspaceFolder}|$PROJECT_DIR|g")
            fi
            
            # Check if service is specified
            COMPOSE_SERVICE=$(jq -r '.service // empty' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
            if [ -z "$COMPOSE_SERVICE" ] || [ "$COMPOSE_SERVICE" = "null" ]; then
                error_exit "Docker Compose configuration requires 'service' property to be specified." "$EXIT_CONFIG_ERROR"
            fi
            
            # Parse runServices if specified
            if jq -e '.runServices' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
                while IFS= read -r service; do
                    if [ -n "$service" ] && [ "$service" != "null" ]; then
                        RUN_SERVICES+=("$service")
                    fi
                done < <(jq -r '.runServices[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
            fi
            
            # Parse composeProfiles if specified (Devcontainer spec extension)
            if jq -e '.composeProfiles' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
                while IFS= read -r profile; do
                    if [ -n "$profile" ] && [ "$profile" != "null" ]; then
                        COMPOSE_PROFILES+=("$profile")
                    fi
                done < <(jq -r '.composeProfiles[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
                if [ ${#COMPOSE_PROFILES[@]} -gt 0 ]; then
                    COMPOSE_PROFILES_STR=$(IFS=,; echo "${COMPOSE_PROFILES[*]}")
                    info "Compose profiles specified: $COMPOSE_PROFILES_STR"
                fi
            fi
            
            # Parse restart policy from devcontainer.json (for individual service)
            COMPOSE_RESTART_POLICY=$(jq -r '.restartPolicy // "unless-stopped"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
            
            # Parse depends_on configuration
            if jq -e '.dependsOn' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
                while IFS= read -r dependency; do
                    if [ -n "$dependency" ] && [ "$dependency" != "null" ]; then
                        COMPOSE_DEPENDENCIES+=("$dependency")
                    fi
                done < <(jq -r '.dependsOn[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
                if [ ${#COMPOSE_DEPENDENCIES[@]} -gt 0 ]; then
                    info "Service dependencies: ${COMPOSE_DEPENDENCIES[*]}"
                fi
            fi
            
            # Generate project name
            COMPOSE_PROJECT_NAME="dcutil-$(basename "$PROJECT_DIR")"
            
            # Add timestamp to avoid conflicts
            COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}-$(date +%Y%m%d)"
            
            info "Docker Compose configuration found:"
            info "  Files: $DOCKER_COMPOSE_FILE"
            info "  Service: $COMPOSE_SERVICE"
            info "  Project: $COMPOSE_PROJECT_NAME"
            if [ ${#RUN_SERVICES[@]} -gt 0 ]; then
                info "  Run services: ${RUN_SERVICES[*]}"
            fi
            if [ ${#COMPOSE_PROFILES[@]} -gt 0 ]; then
                info "  Profiles: ${COMPOSE_PROFILES[*]}"
            fi
            if [ -n "${COMPOSE_RESTART_POLICY:-}" ]; then
                info "  Restart policy: $COMPOSE_RESTART_POLICY"
            fi
            
            return 0
        fi
    fi
    return 1
}

# Check if we're using Docker Compose mode
is_compose_mode() {
    if [ -n "${DOCKER_COMPOSE_FILE:-}" ]; then
        return 0
    else
        return 1
    fi
}

# Build Docker Compose images
docker_compose_build() {
    if ! is_compose_mode; then
        return 1
    fi
    
    info "Building Docker Compose images..."
    check_docker_compose
    
    local compose_cmd
    compose_cmd=$(get_compose_command)
    
    # Build images with profiles support
    local build_args=()
    if [ -n "${COMPOSE_PROFILES_STR:-}" ]; then
        build_args+=(--profile "$COMPOSE_PROFILES_STR")
    fi
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            "$compose_cmd" "${build_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" build ${COMPOSE_SERVICE:+$COMPOSE_SERVICE}
        else
            # Single compose file
            "$compose_cmd" "${build_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" build ${COMPOSE_SERVICE:+$COMPOSE_SERVICE}
        fi
    else
        "$compose_cmd" "${build_args[@]}" -p "$COMPOSE_PROJECT_NAME" build ${COMPOSE_SERVICE:+$COMPOSE_SERVICE}
    fi
    
    local build_cmd=("$compose_cmd" "${build_args[@]}" -p "$COMPOSE_PROJECT_NAME" build ${COMPOSE_SERVICE:+$COMPOSE_SERVICE})

    if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
        build_cmd+=(-f "$DOCKER_COMPOSE_FILE")
    else
        build_cmd+=(-f "$DOCKER_COMPOSE_FILE")
    fi

    if "${build_cmd[@]}"; then
        success "Docker Compose images built successfully"
    else
        error_exit "Failed to build Docker Compose images" "$EXIT_DEVCONTAINER_ERROR"
    fi
}

# Start Docker Compose environment
docker_compose_up() {
    if ! is_compose_mode; then
        return 1
    fi
    
    info "Starting Docker Compose environment..."
    check_docker_compose
    
    local compose_cmd
    compose_cmd=$(get_compose_command)
    
    # Prepare compose arguments
    local up_args=()
    
    # Add profiles if specified
    if [ ${#COMPOSE_PROFILES[@]} -gt 0 ]; then
        up_args+=(--profile "$COMPOSE_PROFILES_STR")
        info "Using compose profiles: $COMPOSE_PROFILES_STR"
    fi
    
    # Add dependencies first if specified
    if [ ${#COMPOSE_DEPENDENCIES[@]} -gt 0 ]; then
        info "Starting dependencies first: ${COMPOSE_DEPENDENCIES[*]}"
        if [ -n "$DOCKER_COMPOSE_FILE" ]; then
            if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
                "$compose_cmd" "${up_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d "${COMPOSE_DEPENDENCIES[@]}"
            else
                "$compose_cmd" "${up_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d "${COMPOSE_DEPENDENCIES[@]}"
            fi
            # Wait a moment for dependencies to be ready
            sleep 3
        else
            "$compose_cmd" "${up_args[@]}" -p "$COMPOSE_PROJECT_NAME" up -d "${COMPOSE_DEPENDENCIES[@]}"
            sleep 3
        fi
    fi
    
    # Determine which services to start
    local services_to_start=()
    
    # Always start the main service
    if [ -n "$COMPOSE_SERVICE" ]; then
        services_to_start+=("$COMPOSE_SERVICE")
    fi
    
    # Add runServices if specified
    if [ ${#RUN_SERVICES[@]} -gt 0 ]; then
        for service in "${RUN_SERVICES[@]}"; do
            # Avoid duplicates
            if [[ ! " ${services_to_start[*]} " =~ $service ]]; then
                services_to_start+=("$service")
            fi
        done
    fi
    
    # Start services
    if [ ${#services_to_start[@]} -gt 0 ]; then
        info "Starting services: ${services_to_start[*]}"
        
        if [ -n "$DOCKER_COMPOSE_FILE" ]; then
            if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
                # Multiple compose files
                $compose_cmd "${up_args[@]}" -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" up -d "${services_to_start[@]}"
            else
                # Single compose file
                $compose_cmd "${up_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d "${services_to_start[@]}"
            fi
        else
            $compose_cmd "${up_args[@]}" -p "$COMPOSE_PROJECT_NAME" up -d "${services_to_start[@]}"
        fi
    else
        # Start all services
        if [ -n "$DOCKER_COMPOSE_FILE" ]; then
            if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
                # Multiple compose files
                $compose_cmd "${up_args[@]}" -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" up -d
            else
                # Single compose file
                $compose_cmd "${up_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
            fi
        else
            $compose_cmd "${up_args[@]}" -p "$COMPOSE_PROJECT_NAME" up -d
        fi
    fi
    
    # Apply restart policy configuration if specified
    if [ -n "${COMPOSE_RESTART_POLICY:-}" ] && [ "$COMPOSE_RESTART_POLICY" != "unless-stopped" ]; then
        info "Configuring restart policy: $COMPOSE_RESTART_POLICY"
        # Note: Restart policy would typically be defined in docker-compose.yml
        # This is here for future enhancement
    fi
    
    if [ $? -eq 0 ]; then
        success "Docker Compose environment started successfully"
    else
        error_exit "Failed to start Docker Compose environment" "$EXIT_DEVCONTAINER_ERROR"
    fi
}

# Stop Docker Compose environment
docker_compose_down() {
    if ! is_compose_mode; then
        return 1
    fi
    
    info "Stopping Docker Compose environment..."
    check_docker_compose
    
    local compose_cmd
    compose_cmd=$(get_compose_command)
    
    # Prepare compose arguments
    local down_args=()
    
    # Add profiles if specified
    if [ ${#COMPOSE_PROFILES[@]} -gt 0 ]; then
        down_args+=(--profile "$COMPOSE_PROFILES_STR")
    fi
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            $compose_cmd "${down_args[@]}" -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" down
        else
            # Single compose file
            $compose_cmd "${down_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down
        fi
    else
        $compose_cmd "${down_args[@]}" -p "$COMPOSE_PROJECT_NAME" down
    fi
    
    if [ $? -eq 0 ]; then
        success "Docker Compose environment stopped successfully"
    else
        error_exit "Failed to stop Docker Compose environment" "$EXIT_DEVCONTAINER_ERROR"
    fi
}

# Restart Docker Compose environment
docker_compose_restart() {
    if ! is_compose_mode; then
        return 1
    fi
    
    info "Restarting Docker Compose environment..."
    docker_compose_down
    sleep 2
    docker_compose_up
}

# Show Docker Compose configuration
docker_compose_config() {
    if ! is_compose_mode; then
        return 1
    fi
    
    info "Showing Docker Compose configuration..."
    check_docker_compose
    
    local compose_cmd
    compose_cmd=$(get_compose_command)
    
    # Prepare compose arguments
    local config_args=()
    
    # Add profiles if specified
    if [ ${#COMPOSE_PROFILES[@]} -gt 0 ]; then
        config_args+=(--profile "$COMPOSE_PROFILES_STR")
    fi
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            $compose_cmd "${config_args[@]}" -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" config
        else
            # Single compose file
            $compose_cmd "${config_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" config
        fi
    else
        $compose_cmd "${config_args[@]}" -p "$COMPOSE_PROJECT_NAME" config
    fi
}

# Show Docker Compose logs
docker_compose_logs() {
    if ! is_compose_mode; then
        return 1
    fi
    
    info "Showing Docker Compose logs..."
    check_docker_compose
    
    local compose_cmd
    compose_cmd=$(get_compose_command)
    
    local service_arg=""
    if [ -n "$COMPOSE_SERVICE" ]; then
        service_arg="$COMPOSE_SERVICE"
    fi
    
    # Prepare compose arguments
    local logs_args=()
    
    # Add profiles if specified
    if [ ${#COMPOSE_PROFILES[@]} -gt 0 ]; then
        logs_args+=(--profile "$COMPOSE_PROFILES_STR")
    fi
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            $compose_cmd "${logs_args[@]}" -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" logs -f $service_arg
        else
            # Single compose file
            $compose_cmd "${logs_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" logs -f $service_arg
        fi
    else
        $compose_cmd "${logs_args[@]}" -p "$COMPOSE_PROJECT_NAME" logs -f $service_arg
    fi
}

# Execute command in Docker Compose service
docker_compose_exec() {
    if ! is_compose_mode; then
        return 1
    fi
    
    local cmd="${1:-}"
    if [ -z "$cmd" ]; then
        error_exit "Command required for exec. Usage: dcutil compose exec <command>" "$EXIT_INVALID_ARGS"
    fi
    
    info "Executing command in service $COMPOSE_SERVICE..."
    check_docker_compose
    
    local compose_cmd
    compose_cmd=$(get_compose_command)
    
    # Prepare compose arguments
    local exec_args=()
    
    # Add profiles if specified
    if [ ${#COMPOSE_PROFILES[@]} -gt 0 ]; then
        exec_args+=(--profile "$COMPOSE_PROFILES_STR")
    fi
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            "$compose_cmd" "${exec_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" exec "$COMPOSE_SERVICE" "$cmd"
        else
            # Single compose file
            "$compose_cmd" "${exec_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" exec "$COMPOSE_SERVICE" "$cmd"
        fi
    else
        "$compose_cmd" "${exec_args[@]}" -p "$COMPOSE_PROJECT_NAME" exec "$COMPOSE_SERVICE" "$cmd"
    fi
}

# Show Docker Compose status
docker_compose_status() {
    if ! is_compose_mode; then
        return 1
    fi
    
    info "Docker Compose status..."
    check_docker_compose
    
    local compose_cmd
    compose_cmd=$(get_compose_command)
    
    # Prepare compose arguments
    local ps_args=()
    
    # Add profiles if specified
    if [ ${#COMPOSE_PROFILES[@]} -gt 0 ]; then
        ps_args+=(--profile "$COMPOSE_PROFILES_STR")
    fi
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            $compose_cmd "${ps_args[@]}" -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" ps
        else
            # Single compose file
            $compose_cmd "${ps_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps
        fi
    else
        $compose_cmd "${ps_args[@]}" -p "$COMPOSE_PROJECT_NAME" ps
    fi
}

# Clean up Docker Compose environment
docker_compose_clean() {
    if ! is_compose_mode; then
        return 1
    fi

    info "Cleaning up Docker Compose environment..."

    # Confirm cleanup
    echo ""
    warning "This will stop and remove the Docker Compose environment, including volumes and orphaned containers"
    local confirm=""
    if [ -t 0 ]; then
        read -r -p "Are you sure? (y/N): " confirm
    elif [ "${DCUTIL_FORCE:-}" = "1" ]; then
        # Non-interactive with force flag: assume confirmation
        confirm="y"
    else
        # Non-interactive without force: cancel
        error_exit "Compose clean operation requires DCUTIL_FORCE=1 in non-interactive mode" "$EXIT_INVALID_ARGS"
    fi
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        info "Compose cleanup cancelled"
        return 0
    fi

    docker_compose_down
    
    # Remove volumes and images
    local compose_cmd
    compose_cmd=$(get_compose_command)
    
    # Prepare compose arguments
    local clean_args=()
    
    # Add profiles if specified
    if [ ${#COMPOSE_PROFILES[@]} -gt 0 ]; then
        clean_args+=(--profile "$COMPOSE_PROFILES_STR")
    fi
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            $compose_cmd "${clean_args[@]}" -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" down -v --remove-orphans
        else
            # Single compose file
            $compose_cmd "${clean_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down -v --remove-orphans
        fi
    else
        $compose_cmd "${clean_args[@]}" -p "$COMPOSE_PROJECT_NAME" down -v --remove-orphans
    fi
    
    # Remove unused images
    docker image prune -f
    
    success "Docker Compose environment cleaned up"
}

# Scale services
docker_compose_scale() {
    local service_name="$1"
    local replicas="$2"
    
    if ! is_compose_mode; then
        error_exit "Not in Docker Compose mode" "$EXIT_CONFIG_ERROR"
    fi
    
    if [ -z "$service_name" ] || [ -z "$replicas" ]; then
        error_exit "Usage: docker_compose_scale <service> <replicas>" "$EXIT_INVALID_ARGS"
    fi
    
    info "Scaling service '$service_name' to $replicas replicas..."
    check_docker_compose
    
    local compose_cmd
    compose_cmd=$(get_compose_command)
    
    # Prepare compose arguments
    local scale_args=()
    
    # Add profiles if specified
    if [ ${#COMPOSE_PROFILES[@]} -gt 0 ]; then
        scale_args+=(--profile "$COMPOSE_PROFILES_STR")
    fi
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            $compose_cmd "${scale_args[@]}" -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" up -d --scale "$service_name=$replicas"
        else
            # Single compose file
            $compose_cmd "${scale_args[@]}" -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d --scale "$service_name=$replicas"
        fi
    else
        $compose_cmd "${scale_args[@]}" -p "$COMPOSE_PROJECT_NAME" up -d --scale "$service_name=$replicas"
    fi
    
    if [ $? -eq 0 ]; then
        success "Service '$service_name' scaled to $replicas replicas"
    else
        error_exit "Failed to scale service '$service_name'" "$EXIT_DEVCONTAINER_ERROR"
    fi
}