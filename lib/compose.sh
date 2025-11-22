#!/bin/bash

# Docker Compose support for dcutil
# Handles docker-compose.yml based devcontainer configurations

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for Docker Compose
DOCKER_COMPOSE_FILE=""
COMPOSE_SERVICE=""
RUN_SERVICES=()
COMPOSE_PROJECT_NAME=""

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
            
            # Generate project name
            COMPOSE_PROJECT_NAME="dcutil-$(basename "$PROJECT_DIR")"
            
            info "Docker Compose configuration found:"
            info "  Files: $DOCKER_COMPOSE_FILE"
            info "  Service: $COMPOSE_SERVICE"
            info "  Project: $COMPOSE_PROJECT_NAME"
            if [ ${#RUN_SERVICES[@]} -gt 0 ]; then
                info "  Run services: ${RUN_SERVICES[*]}"
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
    
    # Build images
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            $compose_cmd -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" build ${COMPOSE_SERVICE:+$COMPOSE_SERVICE}
        else
            # Single compose file
            $compose_cmd -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" build ${COMPOSE_SERVICE:+$COMPOSE_SERVICE}
        fi
    else
        $compose_cmd -p "$COMPOSE_PROJECT_NAME" build ${COMPOSE_SERVICE:+$COMPOSE_SERVICE}
    fi
    
    if [ $? -eq 0 ]; then
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
            if [[ ! " ${services_to_start[@]} " =~ " ${service} " ]]; then
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
                $compose_cmd -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" up -d "${services_to_start[@]}"
            else
                # Single compose file
                $compose_cmd -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d "${services_to_start[@]}"
            fi
        else
            $compose_cmd -p "$COMPOSE_PROJECT_NAME" up -d "${services_to_start[@]}"
        fi
    else
        # Start all services
        if [ -n "$DOCKER_COMPOSE_FILE" ]; then
            if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
                # Multiple compose files
                $compose_cmd -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" up -d
            else
                # Single compose file
                $compose_cmd -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
            fi
        else
            $compose_cmd -p "$COMPOSE_PROJECT_NAME" up -d
        fi
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
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            $compose_cmd -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" down
        else
            # Single compose file
            $compose_cmd -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down
        fi
    else
        $compose_cmd -p "$COMPOSE_PROJECT_NAME" down
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
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            $compose_cmd -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" logs -f $service_arg
        else
            # Single compose file
            $compose_cmd -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" logs -f $service_arg
        fi
    else
        $compose_cmd -p "$COMPOSE_PROJECT_NAME" logs -f $service_arg
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
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            $compose_cmd -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" exec "$COMPOSE_SERVICE" $cmd
        else
            # Single compose file
            $compose_cmd -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" exec "$COMPOSE_SERVICE" $cmd
        fi
    else
        $compose_cmd -p "$COMPOSE_PROJECT_NAME" exec "$COMPOSE_SERVICE" $cmd
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
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            $compose_cmd -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" ps
        else
            # Single compose file
            $compose_cmd -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps
        fi
    else
        $compose_cmd -p "$COMPOSE_PROJECT_NAME" ps
    fi
}

# Clean up Docker Compose environment
docker_compose_clean() {
    if ! is_compose_mode; then
        return 1
    fi
    
    info "Cleaning up Docker Compose environment..."
    docker_compose_down
    
    # Remove volumes and images
    local compose_cmd
    compose_cmd=$(get_compose_command)
    
    if [ -n "$DOCKER_COMPOSE_FILE" ]; then
        if [[ "$DOCKER_COMPOSE_FILE" == *"-f "* ]]; then
            # Multiple compose files
            $compose_cmd -f $DOCKER_COMPOSE_FILE -p "$COMPOSE_PROJECT_NAME" down -v --remove-orphans
        else
            # Single compose file
            $compose_cmd -f "$DOCKER_COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down -v --remove-orphans
        fi
    else
        $compose_cmd -p "$COMPOSE_PROJECT_NAME" down -v --remove-orphans
    fi
    
    # Remove unused images
    docker image prune -f
    
    success "Docker Compose environment cleaned up"
}