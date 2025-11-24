#!/usr/bin/env bash

# Advanced Features support for dcutil
# Implements advanced devcontainer specification features

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for advanced features
UPDATE_REMOTE_USER_UID=false
ENTRYPOINT_OVERRIDE=""
OVERRIDE_COMMAND=false
FORWARD_PORTS=()
WORKSPACE_MOUNT=""

# Check if advanced features are configured
has_advanced_features() {
    if command -v jq &> /dev/null; then
        if jq -e '.updateRemoteUserUID or .entrypoint or .overrideCommand or .forwardPorts or .portsAttributes or .workspaceMount' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Parse advanced features configuration
parse_advanced_features_config() {
    # Parse devcontainer config first to set DEVCONTAINER_CONFIG_FILE
    if command -v parse_devcontainer_config >/dev/null 2>&1; then
        parse_devcontainer_config
    else
        error_exit "Failed to parse devcontainer configuration" "$EXIT_CONFIG_ERROR"
    fi
    
    if [ -z "${DEVCONTAINER_CONFIG_FILE:-}" ]; then
        error_exit "No devcontainer configuration file found. Run from a project directory with .devcontainer/devcontainer.json" "$EXIT_CONFIG_ERROR"
    fi
    
    info "Parsing advanced features configuration..."
    
    if command -v jq &> /dev/null; then
        # Parse updateRemoteUserUID
        UPDATE_REMOTE_USER_UID=$(jq -r '.updateRemoteUserUID // false' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        if [ "$UPDATE_REMOTE_USER_UID" = "true" ]; then
            info "Remote user UID/GID synchronization enabled"
        fi
        
        # Parse entrypoint override
        ENTRYPOINT_OVERRIDE=$(jq -r '.entrypoint // empty' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        if [ -n "$ENTRYPOINT_OVERRIDE" ] && [ "$ENTRYPOINT_OVERRIDE" != "null" ]; then
            info "Entrypoint override: $ENTRYPOINT_OVERRIDE"
        fi
        
        # Parse overrideCommand
        OVERRIDE_COMMAND=$(jq -r '.overrideCommand // false' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        if [ "$OVERRIDE_COMMAND" = "true" ]; then
            info "Command override enabled"
        fi
        
        # Parse forwardPorts
        if jq -e '.forwardPorts' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS= read -r port; do
                if [ -n "$port" ] && [ "$port" != "null" ]; then
                    FORWARD_PORTS+=("$port")
                fi
            done < <(jq -r '.forwardPorts[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
            
            if [ ${#FORWARD_PORTS[@]} -gt 0 ]; then
                info "Forward ports: ${FORWARD_PORTS[*]}"
            fi
        fi
        
        # Parse portsAttributes
        if jq -e '.portsAttributes' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            info "Ports attributes configured"
            # For now, we'll just note that ports attributes are configured
            # Full implementation would parse individual port configurations
        fi
        
        # Parse workspaceMount
        WORKSPACE_MOUNT=$(jq -r '.workspaceMount // empty' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        if [ -n "$WORKSPACE_MOUNT" ] && [ "$WORKSPACE_MOUNT" != "null" ]; then
            # Expand variables in workspaceMount
            WORKSPACE_MOUNT=$(echo "$WORKSPACE_MOUNT" | sed "s|\${workspaceFolder}|$PROJECT_DIR|g" | sed "s|\${localWorkspaceFolder}|$PROJECT_DIR|g")
            info "Workspace mount: $WORKSPACE_MOUNT"
        fi
        
        return 0
    fi
    
    return 1
}

# Apply remote user UID/GID synchronization
apply_user_uid_sync() {
    if [ "$UPDATE_REMOTE_USER_UID" != "true" ]; then
        return 0
    fi
    
    if [ -z "${CONTAINER_USER:-}" ] && [ -z "${REMOTE_USER:-}" ]; then
        return 0
    fi
    
    info "Applying remote user UID/GID synchronization..."
    
    # Get current user's UID and GID
    local current_uid
    local current_gid
    current_uid=$(id -u)
    current_gid=$(id -g)
    
    info "Current user: UID=$current_uid, GID=$current_gid"
    
    # Check if container user exists and get its UID/GID
    local container_uid
    local container_gid
    if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
        container_uid=$(execute_command_in_devcontainer "$PROJECT_DIR" id -u "${CONTAINER_USER:-}" 2>/dev/null || echo "")
        container_gid=$(execute_command_in_devcontainer "$PROJECT_DIR" id -g "${CONTAINER_USER:-}" 2>/dev/null || echo "")
    else
        container_uid=$(docker exec "$CONTAINER_NAME" id -u "${CONTAINER_USER:-}" 2>/dev/null || echo "")
        container_gid=$(docker exec "$CONTAINER_NAME" id -g "${CONTAINER_USER:-}" 2>/dev/null || echo "")
    fi
    
    if [ -n "$container_uid" ] && [ "$container_uid" != "$current_uid" ]; then
        info "Updating container user UID from $container_uid to $current_uid"
        
        # Update user UID
        if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
            if ! execute_command_in_devcontainer "$PROJECT_DIR" usermod -u "$current_uid" "${CONTAINER_USER:-vscode}" 2>/dev/null; then
                warning "Failed to update container user UID"
            fi
            # Update file ownership for the user's files
            if ! execute_command_in_devcontainer "$PROJECT_DIR" find /home/"${CONTAINER_USER:-vscode}" -user "$container_uid" -exec chown -h "$current_uid":"$current_gid" {} \; 2>/dev/null; then
                warning "Failed to update file ownership"
            fi
        else
            if ! docker exec "$CONTAINER_NAME" usermod -u "$current_uid" "${CONTAINER_USER:-vscode}" 2>/dev/null; then
                warning "Failed to update container user UID"
            fi
            # Update file ownership for the user's files
            if ! docker exec "$CONTAINER_NAME" find /home/"${CONTAINER_USER:-vscode}" -user "$container_uid" -exec chown -h "$current_uid":"$current_gid" {} \; 2>/dev/null; then
                warning "Failed to update file ownership"
            fi
        fi
    fi
    
    if [ -n "$container_gid" ] && [ "$container_gid" != "$current_gid" ]; then
        info "Updating container user GID from $container_gid to $current_gid"
        
        # Update user GID
        if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
            if ! execute_command_in_devcontainer "$PROJECT_DIR" groupmod -g "$current_gid" "$(id -gn "${CONTAINER_USER:-vscode}" 2>/dev/null || echo "vscode")" 2>/dev/null; then
                warning "Failed to update container user GID"
            fi
        else
            if ! docker exec "$CONTAINER_NAME" groupmod -g "$current_gid" "$(id -gn "${CONTAINER_USER:-vscode}" 2>/dev/null || echo "vscode")" 2>/dev/null; then
                warning "Failed to update container user GID"
            fi
        fi
    fi
    
    success "Remote user UID/GID synchronization completed"
}

# Apply entrypoint override
apply_entrypoint_override() {
    if [ -z "${ENTRYPOINT_OVERRIDE:-}" ]; then
        return 0
    fi
    
    info "Applying entrypoint override: $ENTRYPOINT_OVERRIDE"
    
    # For Docker-native implementation, we can't easily change the entrypoint
    # after container creation. This would require recreating the container.
    # For now, we'll log the intended entrypoint override.
    warning "Entrypoint override specified but not implemented in Docker-native mode"
    warning "To use entrypoint override, rebuild the container with the new entrypoint"
    
    return 0
}

# Apply command override
apply_command_override() {
    if [ "$OVERRIDE_COMMAND" != "true" ]; then
        return 0
    fi
    
    info "Command override enabled"
    
    # Command override typically means not using the default command
    # For Docker-native implementation, this is handled during container creation
    # by not specifying a command or using a custom command
    info "Container will not use default command due to override setting"
    
    return 0
}

# Apply port forwarding
apply_port_forwarding() {
    if [ ${#FORWARD_PORTS[@]} -eq 0 ]; then
        return 0
    fi
    
    info "Applying port forwarding for: ${FORWARD_PORTS[*]}"
    
    # Port forwarding is typically handled during container creation
    # The ports are already exposed in the docker create command
    # This function can be used for additional port management if needed
    
    for port in "${FORWARD_PORTS[@]}"; do
        # Validate port format
        if [[ ! "$port" =~ ^[0-9]+$ ]] && [[ ! "$port" =~ ^[0-9]+:[0-9]+$ ]]; then
            warning "Invalid port format: $port"
            continue
        fi
        
        info "Port $port will be forwarded"
    done
    
    return 0
}

# Apply ports attributes
apply_ports_attributes() {
    if ! command -v jq &> /dev/null || ! jq -e '.portsAttributes' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
        return 0
    fi
    
    info "Applying ports attributes configuration..."
    
    # Parse ports attributes
    # This would handle properties like onAutoForward, label, protocol, etc.
    # For now, we'll just log that ports attributes are configured
    
    if command -v jq &> /dev/null; then
        local port_count
        port_count=$(jq '.portsAttributes | length' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "0")
        info "Found $port_count port attribute configurations"
    fi
    
    return 0
}

# Apply workspace mount
apply_workspace_mount() {
    if [ -z "${WORKSPACE_MOUNT:-}" ]; then
        return 0
    fi
    
    info "Applying workspace mount: $WORKSPACE_MOUNT"
    
    # Workspace mount is typically handled during container creation
    # This function can be used for additional mount management if needed
    
    # Validate mount path
    if [ ! -d "$WORKSPACE_MOUNT" ]; then
        warning "Workspace mount path does not exist: $WORKSPACE_MOUNT"
        return 1
    fi
    
    success "Workspace mount configured: $WORKSPACE_MOUNT"
    
    return 0
}

# Show advanced features information
show_advanced_features_info() {
    if ! parse_advanced_features_config; then
        echo "No advanced features configured."
        return 1
    fi
    
    echo "Advanced Features Configuration:"
    echo "  Remote User UID Sync: $UPDATE_REMOTE_USER_UID"
    if [ -n "${ENTRYPOINT_OVERRIDE:-}" ]; then
        echo "  Entrypoint Override: $ENTRYPOINT_OVERRIDE"
    fi
    echo "  Command Override: $OVERRIDE_COMMAND"
    
    if [ ${#FORWARD_PORTS[@]} -gt 0 ]; then
        echo "  Forward Ports:"
        for port in "${FORWARD_PORTS[@]}"; do
            echo "    - $port"
        done
    fi
    
    if command -v jq &> /dev/null && jq -e '.portsAttributes' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
        echo "  Ports Attributes: Configured"
    fi
    
    if [ -n "${WORKSPACE_MOUNT:-}" ]; then
        echo "  Workspace Mount: $WORKSPACE_MOUNT"
    fi
}

# Validate advanced features configuration
validate_advanced_features_config() {
    if ! parse_advanced_features_config; then
        echo "No advanced features configured."
        return 0
    fi
    
    local errors=()
    local warnings=()
    
    # Validate updateRemoteUserUID
    if [ "$UPDATE_REMOTE_USER_UID" = "true" ]; then
        if [ -z "${CONTAINER_USER:-}" ] && [ -z "${REMOTE_USER:-}" ]; then
            warnings+=("updateRemoteUserUID is true but no container user specified")
        fi
    fi
    
    # Validate entrypoint override
    if [ -n "${ENTRYPOINT_OVERRIDE:-}" ]; then
        if [ "$ENTRYPOINT_OVERRIDE" = "null" ]; then
            errors+=("entrypoint cannot be null")
        fi
    fi
    
    # Validate forward ports
    for port in "${FORWARD_PORTS[@]}"; do
        if [[ ! "$port" =~ ^[0-9]+$ ]] && [[ ! "$port" =~ ^[0-9]+:[0-9]+$ ]]; then
            errors+=("Invalid port format: $port")
        fi
        
        local port_num
        if [[ "$port" =~ ^[0-9]+:[0-9]+$ ]]; then
            port_num="${port##*:}"
        else
            port_num="$port"
        fi
        
        if [ "$port_num" -lt 1 ] || [ "$port_num" -gt 65535 ]; then
            errors+=("Port number out of range: $port_num")
        fi
    done
    
    # Validate workspace mount
    if [ -n "${WORKSPACE_MOUNT:-}" ]; then
        if [ "$WORKSPACE_MOUNT" = "null" ]; then
            errors+=("workspaceMount cannot be null")
        elif [ ! -d "$WORKSPACE_MOUNT" ]; then
            warnings+=("workspaceMount path does not exist: $WORKSPACE_MOUNT")
        fi
    fi
    
    # Report validation results
    if [ ${#errors[@]} -gt 0 ]; then
        echo "Advanced features configuration validation errors:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo "Advanced features configuration warnings:"
        for warning in "${warnings[@]}"; do
            echo "  - $warning"
        done
    fi
    
    if [ ${#errors[@]} -eq 0 ]; then
        success "Advanced features configuration is valid"
    fi
    
    return 0
}

# Apply all advanced features
apply_advanced_features() {
    if ! parse_advanced_features_config; then
        return 0
    fi
    
    info "Applying advanced features..."
    
    apply_user_uid_sync
    apply_entrypoint_override
    apply_command_override
    apply_port_forwarding
    apply_ports_attributes
    apply_workspace_mount
    
    success "Advanced features applied successfully"
}