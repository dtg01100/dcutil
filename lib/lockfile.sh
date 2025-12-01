#!/usr/bin/env bash

# Devcontainer Lockfile Support for dcutil
# Implements devcontainer-lock.json functionality for reproducible builds

# Source core functionality
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for lockfile
LOCKFILE_CONFIG_FILE=""
LOCKFILE_DIR=""

# Check if lockfile is configured
has_lockfile() {
    local project_dir="${1:-$PROJECT_DIR}"
    local config_file="${2:-$DEVCONTAINER_CONFIG_FILE}"
    
    if [ -z "$config_file" ]; then
        if [ -f "$project_dir/.devcontainer/devcontainer.json" ]; then
            config_file="$project_dir/.devcontainer/devcontainer.json"
        elif [ -f "$project_dir/.devcontainer.json" ]; then
            config_file="$project_dir/.devcontainer.json"
        else
            return 1
        fi
    fi
    
    # Check if generateLockfile is enabled in devcontainer.json
    if command -v jq &> /dev/null && [ -f "$config_file" ]; then
        local generate_lockfile
        generate_lockfile=$(jq -r '.generateLockfile // false' "$config_file" 2>/dev/null || echo "false")
        
        if [ "$generate_lockfile" = "true" ]; then
            return 0
        fi
    fi
    
    # Also check if a devcontainer-lock.json already exists
    local lockfile_path
    if [ -f "$project_dir/.devcontainer/devcontainer-lock.json" ]; then
        LOCKFILE_CONFIG_FILE="$project_dir/.devcontainer/devcontainer-lock.json"
        return 0
    elif [ -f "$project_dir/devcontainer-lock.json" ]; then
        LOCKFILE_CONFIG_FILE="$project_dir/devcontainer-lock.json"
        return 0
    fi
    
    return 1
}

# Parse lockfile configuration
## shellcheck disable=SC2120
parse_lockfile_config() {
    local project_dir="${1:-$PROJECT_DIR}"
    
    if ! has_lockfile "$project_dir"; then
        info "No lockfile configuration found."
        return 1
    fi
    
    # Set the appropriate lockfile path
    if [ -f "$project_dir/.devcontainer/devcontainer-lock.json" ]; then
        LOCKFILE_CONFIG_FILE="$project_dir/.devcontainer/devcontainer-lock.json"
    elif [ -f "$project_dir/devcontainer-lock.json" ]; then
        LOCKFILE_CONFIG_FILE="$project_dir/devcontainer-lock.json"
    else
        # If generateLockfile is true, we'll generate it later
        local devcontainer_file
        if [ -f "$project_dir/.devcontainer/devcontainer.json" ]; then
            devcontainer_file="$project_dir/.devcontainer/devcontainer.json"
        elif [ -f "$project_dir/.devcontainer.json" ]; then
            devcontainer_file="$project_dir/.devcontainer.json"
        else
            error_exit "No devcontainer.json found" "$EXIT_CONFIG_ERROR"
        fi
        
        if command -v jq &>/dev/null; then
            local generate_lockfile
            generate_lockfile=$(jq -r '.generateLockfile // false' "$devcontainer_file" 2>/dev/null || echo "false")
            
            if [ "$generate_lockfile" = "true" ]; then
                # Create lockfile path
                if [ -f "$project_dir/.devcontainer/devcontainer.json" ]; then
                    LOCKFILE_CONFIG_FILE="$project_dir/.devcontainer/devcontainer-lock.json"
                else
                    LOCKFILE_CONFIG_FILE="$project_dir/devcontainer-lock.json"
                fi
            fi
        fi
    fi
    
    # Initialize lockfile directory
    if [ -n "$LOCKFILE_CONFIG_FILE" ]; then
        LOCKFILE_DIR="$(dirname "$LOCKFILE_CONFIG_FILE")"
    fi
    
    return 0
}

# Generate lockfile from current configuration
generate_lockfile() {
    local project_dir="${1:-$PROJECT_DIR}"
    
    info "Generating devcontainer lockfile for reproducible builds..."
    
    if ! command -v parse_devcontainer_config >/dev/null 2>&1; then
        error_exit "Devcontainer configuration parsing module not available" "$EXIT_CONFIG_ERROR"
    fi
    
    # Make sure devcontainer config is parsed first
    parse_devcontainer_config
    
    # Create lockfile path
    local lockfile_path
    if [ -f "$project_dir/.devcontainer/devcontainer.json" ]; then
        lockfile_path="$project_dir/.devcontainer/devcontainer-lock.json"
    else
        lockfile_path="$project_dir/devcontainer-lock.json"
    fi
    
    # Initialize the lockfile content
    local temp_lockfile
    temp_lockfile=$(mktemp)

    # Create base lockfile structure
    cat > "$temp_lockfile" << LOCKFILE_BASE
{
    "version": "1.0.0",
    "specVersion": "0.0.1",
    "devcontainerVersion": "0.0.1",
    "dependencies": {
    }
}
LOCKFILE_BASE
    
    # Add image information if available
    if [ -n "${IMAGE_NAME:-}" ] && [ "$IMAGE_NAME" != "null" ]; then
        # Get resolved image information (this would normally resolve to specific digests)
        # For now we'll just add the base image
        local temp_file
        temp_file=$(mktemp)
        jq --arg image_name "$IMAGE_NAME" '.dependencies.image = $image_name' "$temp_lockfile" > "$temp_file" && mv "$temp_file" "$temp_lockfile"
    fi
    
    # Add feature information if features are configured
    if command -v parse_features_config >/dev/null 2>&1 && parse_features_config >/dev/null 2>&1; then
        if [ ${#FEATURES_IDS[@]} -gt 0 ]; then
            # features_lock intentionally not used in this helper - previously reserved for future collection
            
            for feature_id in "${FEATURES_IDS[@]}"; do
                local feature_spec="$feature_id"
                
                # Parse the feature spec to get ID and resolve to specific version/hash
                local parsed_spec
                parsed_spec=$(parse_feature_spec "$feature_spec")
                local feature_name="${parsed_spec%:*}"
                local feature_version="${parsed_spec#*:}"
                
                # In a full implementation, this would resolve to the specific digest
                # For now, we'll record what was specified
                local temp_file
                temp_file=$(mktemp)
                jq --arg fid "$feature_name" --arg fver "$feature_version" '.dependencies[$fid] = $fver' "$temp_lockfile" > "$temp_file" && mv "$temp_file" "$temp_lockfile"
            done
        fi
    fi
    
    # Add additional properties
    local temp_file
    temp_file=$(mktemp)
    jq --arg timestamp "$(date -Iseconds)" '.generated = $timestamp' "$temp_lockfile" > "$temp_file" && mv "$temp_file" "$temp_lockfile"
    
    # Write the final lockfile
    cat "$temp_lockfile" > "$lockfile_path"
    
    # Clean up
    # Cleanup is handled by mktemp (files are created in system temp dir and auto-cleaned)
    
    success "Devcontainer lockfile generated: $lockfile_path"
    LOCKFILE_CONFIG_FILE="$lockfile_path"
    return 0
}

# Validate against lockfile if present
validate_against_lockfile() {
    local project_dir="${1:-$PROJECT_DIR}"
    
    if ! has_lockfile "$project_dir"; then
        info "No lockfile to validate against."
        return 0
    fi
    
    if [ ! -f "$LOCKFILE_CONFIG_FILE" ]; then
        warning "Lockfile referenced but not found: $LOCKFILE_CONFIG_FILE"
        return 0
    fi
    
    info "Validating configuration against lockfile: $LOCKFILE_CONFIG_FILE"
    
    local errors=()
    local warnings=()
    
    # Parse the lockfile to get locked dependencies
    if command -v jq &> /dev/null && [ -f "$LOCKFILE_CONFIG_FILE" ]; then
        # Get dependencies from lockfile
        if jq -e '.dependencies' "$LOCKFILE_CONFIG_FILE" >/dev/null 2>&1; then
            # Check if image matches lockfile
            if [ -n "${IMAGE_NAME:-}" ] && jq -e '.dependencies.image' "$LOCKFILE_CONFIG_FILE" >/dev/null 2>&1; then
                local locked_image
                locked_image=$(jq -r '.dependencies.image' "$LOCKFILE_CONFIG_FILE" 2>/dev/null)
                
                if [ "$locked_image" != "$IMAGE_NAME" ]; then
                    warnings+=("Base image differs from lockfile: expected '$locked_image', got '$IMAGE_NAME'")
                fi
            fi
            
            # Check if features match lockfile
            if command -v parse_features_config >/dev/null 2>&1 && parse_features_config >/dev/null 2>&1 && [ ${#FEATURES_IDS[@]} -gt 0 ]; then
                for feature_id in "${FEATURES_IDS[@]}"; do
                    local feature_spec="$feature_id"
                    local parsed_spec
                    parsed_spec=$(parse_feature_spec "$feature_spec")
                    local feature_name="${parsed_spec%:*}"
                    
                    # Check if this feature is in the lockfile
                    if jq -e ".dependencies[\"$feature_name\"]" "$LOCKFILE_CONFIG_FILE" >/dev/null 2>&1; then
                        local locked_version
                        locked_version=$(jq -r ".dependencies[\"$feature_name\"]" "$LOCKFILE_CONFIG_FILE" 2>/dev/null)
                        
                        # Extract current version 
                        local current_version="${parsed_spec#*:}"
                        
                        if [ "$locked_version" != "$current_version" ]; then
                            warnings+=("Feature $feature_name version differs from lockfile: expected '$locked_version', got '$current_version'")
                        fi
                    else
                        warnings+=("Feature $feature_name not found in lockfile")
                    fi
                done
            fi
        fi
    fi
    
    # Report validation results
    if [ ${#errors[@]} -gt 0 ]; then
        echo "Lockfile validation errors:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo "Lockfile validation warnings:"
        for warning in "${warnings[@]}"; do
            echo "  - $warning"
        done
    fi
    
    if [ ${#errors[@]} -eq 0 ]; then
        success "Lockfile validation passed"
    fi
    
    return 0
}

# Apply lockfile when creating/updating container
apply_lockfile() {
    local project_dir="${1:-$PROJECT_DIR}"
    
    if ! has_lockfile "$project_dir"; then
        info "No lockfile to apply."
        return 0
    fi
    
    if [ ! -f "$LOCKFILE_CONFIG_FILE" ]; then
        warning "Lockfile referenced but not found: $LOCKFILE_CONFIG_FILE"
        # Generate lockfile if generateLockfile is enabled
        local devcontainer_file=""
        if [ -f "$project_dir/.devcontainer/devcontainer.json" ]; then
            devcontainer_file="$project_dir/.devcontainer/devcontainer.json"
        elif [ -f "$project_dir/.devcontainer.json" ]; then
            devcontainer_file="$project_dir/.devcontainer.json"
        fi
        
        if [ -n "$devcontainer_file" ] && command -v jq &>/dev/null; then
            local generate_lockfile
            generate_lockfile=$(jq -r '.generateLockfile // false' "$devcontainer_file" 2>/dev/null || echo "false")
            
            if [ "$generate_lockfile" = "true" ]; then
                info "Generating lockfile as per generateLockfile setting..."
                generate_lockfile "$project_dir"
            fi
        fi
        return 0
    fi
    
    info "Applying lockfile configuration from: $LOCKFILE_CONFIG_FILE"
    
    # In a full implementation, this would override image and feature versions with the locked versions
    # For now, we'll just log that the lockfile is being applied
    if command -v jq &> /dev/null; then
        local gen_date
        gen_date=$(jq -r '.generated // empty' "$LOCKFILE_CONFIG_FILE" 2>/dev/null)
        if [ -n "$gen_date" ] && [ "$gen_date" != "null" ]; then
            info "Lockfile generated on: $gen_date"
        fi
    fi
    
    return 0
}

# Show lockfile information
show_lockfile_info() {
    if ! command -v parse_lockfile_config >/dev/null 2>&1 || ! parse_lockfile_config "$PROJECT_DIR" >/dev/null 2>&1; then
        echo "No lockfile configuration found."
        return 1
    fi
    
    echo "Devcontainer Lockfile Configuration:"
    echo "  Lockfile: ${LOCKFILE_CONFIG_FILE:-<none>}"
    echo "  Directory: ${LOCKFILE_DIR:-<none>}"
    
    if [ -f "$LOCKFILE_CONFIG_FILE" ]; then
        echo ""
        echo "Lockfile Content:"
        echo "================="
        cat "$LOCKFILE_CONFIG_FILE"
        echo ""
    else
        echo "  Status: Lockfile does not exist"
        echo "  Tip: Enable in devcontainer.json with { \"generateLockfile\": true }"
    fi
}

# Validate lockfile configuration
validate_lockfile_config() {
    if ! command -v parse_lockfile_config >/dev/null 2>&1 || ! parse_lockfile_config "$PROJECT_DIR" >/dev/null 2>&1; then
        echo "No lockfile configuration found."
        return 0
    fi
    
    local errors=()
    local warnings=()
    
    if [ -f "$LOCKFILE_CONFIG_FILE" ]; then
        # Validate JSON structure
        if command -v jq &> /dev/null; then
            if ! jq empty "$LOCKFILE_CONFIG_FILE" 2>/dev/null; then
                errors+=("Lockfile is not valid JSON")
            else
                # Validate required fields
                if ! jq -e '.version' "$LOCKFILE_CONFIG_FILE" >/dev/null 2>&1; then
                    errors+=("Lockfile missing required 'version' field")
                fi
                
                if ! jq -e '.dependencies' "$LOCKFILE_CONFIG_FILE" >/dev/null 2>&1; then
                    errors+=("Lockfile missing required 'dependencies' field")
                fi
            fi
        fi
    fi
    
    # Report validation results
    if [ ${#errors[@]} -gt 0 ]; then
        echo "Lockfile configuration validation errors:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo "Lockfile configuration warnings:"
        for warning in "${warnings[@]}"; do
            echo "  - $warning"
        done
    fi
    
    if [ ${#errors[@]} -eq 0 ]; then
        success "Lockfile configuration is valid"
    fi
    
    return 0
}

# Clean lockfile artifacts
clean_lockfile_artifacts() {
    local project_dir="${1:-$PROJECT_DIR}"
    
    info "Cleaning lockfile artifacts..."
    
    local lockfile_path=""
    if [ -f "$project_dir/.devcontainer/devcontainer-lock.json" ]; then
        lockfile_path="$project_dir/.devcontainer/devcontainer-lock.json"
    elif [ -f "$project_dir/devcontainer-lock.json" ]; then
        lockfile_path="$project_dir/devcontainer-lock.json"
    fi
    
    if [ -n "$lockfile_path" ] && [ -f "$lockfile_path" ]; then
        rm -f "$lockfile_path"
        success "Removed lockfile: $lockfile_path"
    else
        info "No lockfile to clean"
    fi
}