#!/usr/bin/env bash

# userEnvProbe support for dcutil
# Implements shell-based environment variable probing per devcontainer specification

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Wrapper functions for main script compatibility
devcontainer_userprobe_probe() {
    probe_user_environment
}

devcontainer_userprobe_show() {
    show_probed_environment
}

devcontainer_userprobe_validate() {
    validate_user_env_probe_config
}

devcontainer_userprobe_apply() {
    apply_user_env_probe
}

devcontainer_userprobe_cleanup() {
    cleanup_probed_environment
}

# Global variables for userEnvProbe
USER_ENV_PROBE=""
PROBED_ENV_VARS=()

# Check if userEnvProbe is configured
has_user_env_probe() {
    if command -v jq &> /dev/null; then
        if jq -e '.userEnvProbe' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Parse userEnvProbe configuration
parse_user_env_probe_config() {
    if ! has_user_env_probe; then
        return 1
    fi
    
    info "Parsing userEnvProbe configuration..."
    
    if command -v jq &> /dev/null; then
        USER_ENV_PROBE=$(jq -r '.userEnvProbe // "zsh"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        
        if [ -n "$USER_ENV_PROBE" ] && [ "$USER_ENV_PROBE" != "null" ]; then
            info "userEnvProbe set to: $USER_ENV_PROBE"
            return 0
        fi
    fi
    
    return 1
}

# Probe environment variables using specified shell
probe_user_environment() {
    if ! parse_user_env_probe_config; then
        info "No userEnvProbe configuration found"
        return 0
    fi
    
    info "Probing user environment with $USER_ENV_PROBE..."
    
    # Create temporary script to probe environment
    local probe_script
    probe_script=$(mktemp)
    
    # Create probe script that outputs environment variables
    cat > "$probe_script" << 'EOF'
#!/usr/bin/env bash

# Source common profile files to pick up user environment
if [ -f "$HOME/.bash_profile" ]; then
    source "$HOME/.bash_profile"
fi

if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi

if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc"
fi

if [ -f "$HOME/.profile" ]; then
    source "$HOME/.profile"
fi

# Output environment variables in a parseable format
env | grep -E "^([A-Z_]+)=" | sort
EOF

    # Make probe script executable
    chmod +x "$probe_script"
    
    # Run probe script with the specified shell
    local probe_output
    if command -v "$USER_ENV_PROBE" >/dev/null 2>&1; then
        probe_output=$("$USER_ENV_PROBE" "$probe_script" 2>/dev/null)
    else
        # Fallback to bash if specified shell is not available
        warning "Shell $USER_ENV_PROBE not found, falling back to bash"
        probe_output=$(bash "$probe_script" 2>/dev/null)
    fi
    
    # Clean up probe script
    rm -f "$probe_script"
    
    if [ -n "$probe_output" ]; then
        info "Environment probing completed, found $(echo "$probe_output" | wc -l) variables"
        
        # Store probed environment variables
        while IFS= read -r env_var; do
            if [ -n "$env_var" ]; then
                PROBED_ENV_VARS+=("$env_var")
            fi
        done <<< "$probe_output"
        
        return 0
    else
        warning "Environment probing failed or returned no variables"
        return 1
    fi
}

# Apply probed environment variables to container
apply_probed_environment() {
    if [ ${#PROBED_ENV_VARS[@]} -eq 0 ]; then
        info "No probed environment variables to apply"
        return 0
    fi
    
    info "Applying ${#PROBED_ENV_VARS[@]} probed environment variables to container..."
    
    # Apply each probed environment variable to the running container
    for env_var in "${PROBED_ENV_VARS[@]}"; do
        # Extract variable name and value
        local var_name="${env_var%%=*}"
        local var_value="${env_var#*=}"
        
        # Skip if variable is empty or already set in container
        if [ -z "$var_name" ] || [ -z "$var_value" ]; then
            continue
        fi
        
        # Apply environment variable to container
        if [ -n "$CONTAINER_NAME" ]; then
            # Validate variable name contains only valid identifier characters
            if [[ "$var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                # Prefer official devcontainer CLI for exec
                if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
                    if execute_command_in_devcontainer "$PROJECT_DIR" /bin/sh -c "export $var_name=\"$var_value\" && echo 'export $var_name=\"$var_value\"' >> /etc/environment" 2>/dev/null; then
                        info "Applied: $var_name"
                    else
                        warning "Failed to apply: $var_name"
                    fi
                elif docker exec -e "$var_name=$var_value" "$CONTAINER_NAME" sh -c "export $var_name" 2>/dev/null ||
                   docker exec "$CONTAINER_NAME" sh -c "echo 'export $var_name=\"\$var_name\"' >> /etc/environment 2>/dev/null || echo 'export $var_name=\"$var_value\"' >> ~/.bashrc" 2>/dev/null; then
                    info "Applied: $var_name"
                else
                    warning "Failed to apply: $var_name"
                fi
            else
                warning "Skipping invalid environment variable name: $var_name"
            fi
        else
            warning "CONTAINER_NAME not set, cannot apply environment variables to container"
        fi
    done
    
    success "Probed environment variables applied to container"
}

# Apply user environment with merging logic
apply_user_env_probe() {
    if ! parse_user_env_probe_config; then
        return 0
    fi
    
    # Probe environment variables
    if ! probe_user_environment; then
        warning "Environment probing failed, continuing without user environment"
        return 1
    fi
    
    # Apply probed environment variables
    apply_probed_environment
    
    success "userEnvProbe completed successfully"
}

# Show probed environment variables
show_probed_environment() {
    if [ ${#PROBED_ENV_VARS[@]} -eq 0 ]; then
        echo "No probed environment variables available."
        return 1
    fi
    
    echo "Probed Environment Variables:"
    echo "============================"
    
    for env_var in "${PROBED_ENV_VARS[@]}"; do
        local var_name="${env_var%%=*}"
        local var_value="${env_var#*=}"
        echo "$var_name=${var_value:0:50}${var_value:50:+...}"
    done
    
    echo ""
    echo "Total variables: ${#PROBED_ENV_VARS[@]}"
}

# Validate userEnvProbe configuration
validate_user_env_probe_config() {
    if ! parse_user_env_probe_config; then
        echo "No userEnvProbe configuration found."
        return 0
    fi
    
    local errors=()
    local warnings=()
    
    # Validate shell availability
    if ! command -v "$USER_ENV_PROBE" >/dev/null 2>&1; then
        warnings+=("Shell '$USER_ENV_PROBE' not found, will fallback to bash")
    fi
    
    # Validate shell type
    case "$USER_ENV_PROBE" in
        "bash"|"zsh"|"fish"|"sh")
            info "Valid shell type: $USER_ENV_PROBE"
            ;;
        *)
            warnings+=("Unknown shell type: $USER_ENV_PROBE, may not work correctly")
            ;;
    esac
    
    # Report validation results
    if [ ${#errors[@]} -gt 0 ]; then
        echo "userEnvProbe configuration validation errors:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo "userEnvProbe configuration warnings:"
        for warning in "${warnings[@]}"; do
            echo "  - $warning"
        done
    fi
    
    if [ ${#errors[@]} -eq 0 ]; then
        success "userEnvProbe configuration is valid"
    fi
    
    return 0
}

# Dynamic variable expansion support
expand_dynamic_variables() {
    local input_string="$1"
    
    # Handle ${localEnv:VAR_NAME} syntax
    if [[ "$input_string" == *"\${localEnv:"* ]]; then
        local var_name
        var_name=$(echo "$input_string" | sed -n 's/.*\${localEnv:\([^}]*\)}.*/\1/p')
        
        # Find the variable in probed environment
        local var_value=""
        for env_var in "${PROBED_ENV_VARS[@]}"; do
            if [[ "$env_var" == "$var_name="* ]]; then
                var_value="${env_var#*=}"
                break
            fi
        done
        
        if [ -n "$var_value" ]; then
            input_string="${input_string//\$\{localEnv:$var_name\}/$var_value}"
        else
            warning "Dynamic variable \${localEnv:$var_name} not found in probed environment"
        fi
    fi
    
    # Handle ${config:setting} syntax
    if [[ "$input_string" == *"\${config:"* ]]; then
        local config_key
        config_key=$(echo "$input_string" | sed -n 's/.*\${config:\([^}]*\)}.*/\1/p')

        # Extract config value from devcontainer.json
        local config_value=""
        if command -v jq &> /dev/null && [ -f "$DEVCONTAINER_CONFIG_FILE" ]; then
            config_value=$(jq -r ".$config_key // empty" "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
            if [ "$config_value" = "null" ] || [ "$config_value" = "empty" ]; then
                config_value=""
            fi
        fi

        if [ -n "$config_value" ]; then
            input_string="${input_string//\$\{config:$config_key\}/$config_value}"
            info "Expanded \${config:$config_key} to: $config_value"
        else
            warning "Dynamic variable \${config:$config_key} not found in devcontainer.json"
        fi
    fi
    
    echo "$input_string"
}

# Cleanup probed environment
cleanup_probed_environment() {
    if [ ${#PROBED_ENV_VARS[@]} -gt 0 ]; then
        local count
        count=${#PROBED_ENV_VARS[@]}
        info "Cleaning up probed environment ($count variables)"
        PROBED_ENV_VARS=()
    fi
}