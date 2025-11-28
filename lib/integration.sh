#!/usr/bin/env bash

# Tool Integration support for dcutil
# Implements customizations and metadata parsing from devcontainer specification

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Wrapper functions for main script compatibility
devcontainer_integration_info() {
    show_tool_integration_info
}

devcontainer_integration_validate() {
    validate_tool_integration_config
}

devcontainer_integration_apply() {
    apply_tool_integration
}

# Global variables for tool integration
CUSTOMIZATIONS_CONFIG=""
IMAGE_METADATA=()

# Check if tool integration features are configured
has_tool_integration() {
    if command -v jq &> /dev/null; then
        if jq -e '.customizations or .devcontainerMetadata' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Parse customizations configuration
parse_customizations_config() {
    # Parse devcontainer config first to set DEVCONTAINER_CONFIG_FILE
    if command -v parse_devcontainer_config >/dev/null 2>&1; then
        parse_devcontainer_config
    else
        error_exit "Failed to parse devcontainer configuration" "$EXIT_CONFIG_ERROR"
    fi
    
    if [ -z "${DEVCONTAINER_CONFIG_FILE:-}" ]; then
        error_exit "No devcontainer configuration file found. Run from a project directory with .devcontainer/devcontainer.json" "$EXIT_CONFIG_ERROR"
    fi
    
    info "Parsing tool integration configuration..."
    
    if command -v jq &> /dev/null; then
        # Parse customizations
        if jq -e '.customizations' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            CUSTOMIZATIONS_CONFIG=$(jq '.customizations' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
            info "Customizations configuration found"
            
            # Handle VS Code customizations
            if jq -e '.customizations.vscode' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
                parse_vscode_customizations
            fi
            
            # Handle other tool customizations
            if jq -e '.customizations | keys[] | select(. != "vscode")' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
                parse_other_customizations
            fi
        fi
        
        # Parse image metadata
        if docker image inspect "${IMAGE_NAME:-}" >/dev/null 2>&1; then
            parse_image_metadata
        fi
        
        return 0
    fi
    
    return 1
}

# Parse VS Code customizations
parse_vscode_customizations() {
    info "Parsing VS Code customizations..."
    
    # Parse VS Code extensions
    if jq -e '.customizations.vscode.extensions' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
        local vscode_extensions
        vscode_extensions=$(jq -r '.customizations.vscode.extensions[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
        
        if [ -n "$vscode_extensions" ]; then
            info "VS Code extensions:"
            echo "$vscode_extensions" | while IFS= read -r extension; do
                if [ -n "$extension" ]; then
                    info "  - $extension"
                fi
            done
        fi
    fi
    
    # Parse VS Code settings
    if jq -e '.customizations.vscode.settings' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
        info "VS Code settings configured"
    fi
    
    # Parse VS Code commands
    if jq -e '.customizations.vscode.commands' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
        info "VS Code commands configured"
    fi
}

# Parse other tool customizations
parse_other_customizations() {
    info "Parsing other tool customizations..."
    
    # Get all customization keys except vscode
    if command -v jq &> /dev/null; then
        local other_tools
        other_tools=$(jq -r '.customizations | keys[] | select(. != "vscode")' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
        
        echo "$other_tools" | while IFS= read -r tool; do
            if [ -n "$tool" ]; then
                info "Tool customization: $tool"
                # For now, we just log the tool customizations
                # Implementation would depend on specific tool requirements
            fi
        done
    fi
}

# Parse image metadata
parse_image_metadata() {
    info "Parsing image metadata..."
    
    if [ -z "${IMAGE_NAME:-}" ]; then
        return 1
    fi
    
    # Extract devcontainer.metadata label from image
    local metadata_label
    metadata_label=$(docker image inspect "$IMAGE_NAME" -f '{{index .Config.Labels "devcontainer.metadata"}}' 2>/dev/null || echo "")
    
    if [ -n "$metadata_label" ]; then
        info "Image metadata found"
        
        # Parse metadata array
        if command -v jq &> /dev/null; then
            echo "$metadata_label" | jq -r '.[]' 2>/dev/null | while IFS= read -r metadata_entry; do
                if [ -n "$metadata_entry" ]; then
                    IMAGE_METADATA+=("$metadata_entry")
                    info "Image metadata entry: $metadata_entry"
                fi
            done
        fi
    else
        info "No image metadata found"
    fi
}

# Apply VS Code customizations
apply_vscode_customizations() {
    # First check if there are any VSCode customizations to apply
    if [ -z "${CUSTOMIZATIONS_CONFIG:-}" ]; then
        info "No VSCode customizations to apply"
        return 0
    fi

    # Check if there are extensions or settings in the customizations
    local has_extensions=false
    local has_settings=false

    if command -v jq &> /dev/null; then
        if echo "$CUSTOMIZATIONS_CONFIG" | jq -e '.vscode.extensions' >/dev/null 2>&1; then
            local extension_count
            extension_count=$(echo "$CUSTOMIZATIONS_CONFIG" | jq '.vscode.extensions | length' 2>/dev/null || echo "0")
            if [ "$extension_count" -gt 0 ]; then
                has_extensions=true
            fi
        fi

        if echo "$CUSTOMIZATIONS_CONFIG" | jq -e '.vscode.settings' >/dev/null 2>&1; then
            local settings_obj
            settings_obj=$(echo "$CUSTOMIZATIONS_CONFIG" | jq '.vscode.settings' 2>/dev/null || echo "{}")
            if [ "$settings_obj" != "{}" ] && [ "$settings_obj" != "null" ]; then
                has_settings=true
            fi
        fi
    fi

    if [ "$has_extensions" != true ] && [ "$has_settings" != true ]; then
        info "No VSCode extensions or settings to apply"
        return 0
    fi

    info "Applying VS Code customizations..."

    # Check if container is running before attempting installation
    if [ -z "${CONTAINER_NAME:-}" ]; then
        error_exit "No container name defined for applying VS Code customizations" "$EXIT_CONFIG_ERROR"
    fi

    # Verify container is running
    if ! is_container_running "$CONTAINER_NAME"; then
        error_exit "Container must be running to install VS Code extensions" "$EXIT_DEVCONTAINER_ERROR"
    fi

    # Create VS Code settings directory in container
    local vscode_settings_dir="/home/${CONTAINER_USER:-vscode}/.vscode-server/data/User"
    execute_in_container sh -c "mkdir -p '$vscode_settings_dir'" 2>/dev/null || true

    # Apply VS Code extensions
    if [ "$has_extensions" = true ] && command -v jq &> /dev/null; then
        local extensions
        extensions=$(echo "$CUSTOMIZATIONS_CONFIG" | jq -r '.vscode.extensions[]' 2>/dev/null || echo "")

        if [ -n "$extensions" ]; then
            info "Installing VS Code extensions..."

            # Loop through each extension and install
            local extension_list=()
            local i=0
            while IFS= read -r extension; do
                if [ -n "$extension" ] && [ "$extension" != "null" ]; then
                    extension_list[i]="$extension"
                    ((i++))
                fi
            done <<< "$extensions"

            for extension in "${extension_list[@]}"; do
                info "Installing VS Code extension: $extension"

                # Check if VS Code server exists in container
                local vs_code_cmd="code-server"
                local has_vscode_server=false

                if command_exists_in_container "code-server"; then
                    has_vscode_server=true
                elif command_exists_in_container "code"; then
                    vs_code_cmd="code"
                    has_vscode_server=true
                fi

                if [ "$has_vscode_server" = true ]; then
                    # Install extension using code command
                    if execute_in_container sh -c "$vs_code_cmd --install-extension '$extension' --force" 2>/dev/null; then
                        success "Extension $extension installed successfully"
                    else
                        warning "Failed to install VS Code extension: $extension"
                    fi
                else
                    # If VS Code server is not available, just log the extension
                    info "VS Code server not found in container, extension $extension will be installed when VS Code connects to container"
                fi
            done
        fi
    fi

    # Apply VS Code settings
    if [ "$has_settings" = true ] && command -v jq &> /dev/null; then
        local settings_file="$vscode_settings_dir/settings.json"
        local settings_object
        settings_object=$(echo "$CUSTOMIZATIONS_CONFIG" | jq '.vscode.settings' 2>/dev/null || echo "{}")

        # If settings object is empty or null, skip this step
        if [ "$(echo "$settings_object" | jq -r 'if . == null or . == {} then "empty" else "not_empty" end' 2>/dev/null)" = "not_empty" ]; then
            # Create the settings file with proper JSON
            execute_in_container sh -c "mkdir -p '$(dirname "$settings_file")' && echo '$settings_object' > '$settings_file'" 2>/dev/null || warning "Could not write VS Code settings"

            if [ $? -eq 0 ]; then
                info "VS Code settings applied"
            else
                warning "Could not write VS Code settings to container"
            fi
        fi
    fi

    success "VS Code customizations applied"
}

# Helper function to check if container is running
is_container_running() {
    local container_name="$1"
    if command -v execute_container_command >/dev/null 2>&1; then
        if execute_container_command container inspect "$container_name" &>/dev/null; then
            execute_container_command container inspect "$container_name" | grep -q '"Running": true'
            return $?
        fi
    else
        if docker container inspect "$container_name" &>/dev/null; then
            docker container inspect "$container_name" | grep -q '"Running": true'
            return $?
        fi
    fi
    return 1  # Container is not running
}

# Helper function to execute commands in the container using the appropriate method
execute_in_container() {
    local command="$1"
    shift
    if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
        execute_command_in_devcontainer "$PROJECT_DIR" "$command" "$@"
    else
        docker exec "$CONTAINER_NAME" "$command" "$@"
    fi
}

# Helper function to check if a command exists in the container
command_exists_in_container() {
    local cmd="$1"
    if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
        execute_command_in_devcontainer "$PROJECT_DIR" sh -c "command -v '$cmd'" &>/dev/null
    else
        docker exec "$CONTAINER_NAME" sh -c "command -v '$cmd'" &>/dev/null
    fi
}

# Apply tool customizations
apply_tool_customizations() {
    if [ -z "${CUSTOMIZATIONS_CONFIG:-}" ]; then
        return 0
    fi
    
    info "Applying tool customizations..."
    
    # Apply customizations for tools other than VS Code
    if command -v jq &> /dev/null; then
        local other_tools
        other_tools=$(echo "$CUSTOMIZATIONS_CONFIG" | jq -r 'keys[] | select(. != "vscode")' 2>/dev/null || echo "")
        
        echo "$other_tools" | while IFS= read -r tool; do
            if [ -n "$tool" ]; then
                info "Applying customizations for tool: $tool"
                # Tool-specific customization logic would go here
                # This is a placeholder for future implementation
            fi
        done
    fi
    
    success "Tool customizations applied"
}

# Apply image metadata
apply_image_metadata() {
    if [ ${#IMAGE_METADATA[@]} -eq 0 ]; then
        return 0
    fi
    
    info "Applying image metadata..."
    
    for metadata_entry in "${IMAGE_METADATA[@]}"; do
        info "Processing metadata: $metadata_entry"
        # Image metadata processing logic would go here
        # This is a placeholder for future implementation
    done
    
    success "Image metadata applied"
}

# Show tool integration information
show_tool_integration_info() {
    if ! parse_customizations_config; then
        echo "No tool integration features configured."
        return 1
    fi
    
    echo "Tool Integration Configuration:"
    
    if [ -n "${CUSTOMIZATIONS_CONFIG:-}" ]; then
        echo "  Customizations: Configured"
        
        # Show VS Code customizations
        if command -v jq &> /dev/null && echo "$CUSTOMIZATIONS_CONFIG" | jq -e '.vscode' >/dev/null 2>&1; then
            echo "  VS Code Customizations:"
            
            if echo "$CUSTOMIZATIONS_CONFIG" | jq -e '.vscode.extensions' >/dev/null 2>&1; then
                echo "    Extensions:"
                echo "$CUSTOMIZATIONS_CONFIG" | jq -r '.vscode.extensions[]' 2>/dev/null | while IFS= read -r ext; do
                    echo "      - $ext"
                done
            fi
            
            if echo "$CUSTOMIZATIONS_CONFIG" | jq -e '.vscode.settings' >/dev/null 2>&1; then
                echo "    Settings: Configured"
            fi
        fi
        
        # Show other tool customizations
        if command -v jq &> /dev/null; then
            local other_tools
            other_tools=$(echo "$CUSTOMIZATIONS_CONFIG" | jq -r 'keys[] | select(. != "vscode")' 2>/dev/null || echo "")
            
            if [ -n "$other_tools" ]; then
                echo "  Other Tool Customizations:"
                echo "$other_tools" | while IFS= read -r tool; do
                    if [ -n "$tool" ]; then
                        echo "    - $tool"
                    fi
                done
            fi
        fi
    else
        echo "  Customizations: Not configured"
    fi
    
    if [ ${#IMAGE_METADATA[@]} -gt 0 ]; then
        echo "  Image Metadata: ${#IMAGE_METADATA[@]} entries"
    else
        echo "  Image Metadata: Not found"
    fi
}

# Validate tool integration configuration
validate_tool_integration_config() {
    if ! parse_customizations_config; then
        echo "No tool integration features configured."
        return 0
    fi
    
    local errors=()
    local warnings=()
    
    # Validate customizations
    if [ -n "${CUSTOMIZATIONS_CONFIG:-}" ]; then
        # Validate VS Code extensions format
        if command -v jq &> /dev/null && echo "$CUSTOMIZATIONS_CONFIG" | jq -e '.vscode.extensions' >/dev/null 2>&1; then
            local extension_count
            extension_count=$(echo "$CUSTOMIZATIONS_CONFIG" | jq '.vscode.extensions | length' 2>/dev/null || echo "0")
            
            if [ "$extension_count" -gt 0 ]; then
                info "Validating $extension_count VS Code extensions..."
                # Extension validation logic would go here
            fi
        fi
        
        # Validate VS Code settings format
        if command -v jq &> /dev/null && echo "$CUSTOMIZATIONS_CONFIG" | jq -e '.vscode.settings' >/dev/null 2>&1; then
            if ! echo "$CUSTOMIZATIONS_CONFIG" | jq -e '.vscode.settings | type == "object"' >/dev/null 2>&1; then
                errors+=("VS Code settings must be an object")
            fi
        fi
    fi
    
    # Report validation results
    if [ ${#errors[@]} -gt 0 ]; then
        echo "Tool integration configuration validation errors:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo "Tool integration configuration warnings:"
        for warning in "${warnings[@]}"; do
            echo "  - $warning"
        done
    fi
    
    if [ ${#errors[@]} -eq 0 ]; then
        success "Tool integration configuration is valid"
    fi
    
    return 0
}

# Apply all tool integration features
apply_tool_integration() {
    if ! parse_customizations_config; then
        return 0
    fi
    
    info "Applying tool integration features..."
    
    apply_vscode_customizations
    apply_tool_customizations
    apply_image_metadata
    
    success "Tool integration features applied successfully"
}