#!/bin/bash

# Comprehensive Schema Validation for Devcontainer Configuration
# Implements JSON Schema validation for devcontainer.json files

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for schema validation
SCHEMA_VALIDATION_ENABLED=true
SCHEMA_ERRORS=()
SCHEMA_WARNINGS=()
DEVCONTAINER_SPEC_VERSION="0.2.0"

# Check if schema validation is available
has_schema_validation() {
    if command -v jq &> /dev/null; then
        return 0
    fi
    return 1
}

# Validate devcontainer.json against known schema rules
validate_devcontainer_schema() {
    if ! has_schema_validation; then
        warning "Schema validation not available (jq required)"
        return 0
    fi
    
    local config_file="${1:-$DEVCONTAINER_CONFIG_FILE}"
    if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
        error_exit "No devcontainer configuration file provided" "$EXIT_CONFIG_ERROR"
    fi
    
    info "Validating devcontainer.json schema..."
    
    # Reset validation state
    SCHEMA_ERRORS=()
    SCHEMA_WARNINGS=()
    
    # Basic JSON structure validation
    if ! jq '.' "$config_file" >/dev/null 2>&1; then
        SCHEMA_ERRORS+=("Invalid JSON syntax")
        return 1
    fi
    
    # Check for required properties
    validate_required_properties "$config_file"
    
    # Validate property types and formats
    validate_property_types "$config_file"
    
    # Validate deprecated properties
    validate_deprecated_properties "$config_file"
    
    # Validate advanced features
    validate_advanced_features "$config_file"
    
    # Validate features configuration
    validate_features_schema "$config_file"
    
    # Validate lifecycle commands
    validate_lifecycle_schema "$config_file"
    
    # Validate tool integration
    validate_integration_schema "$config_file"
    
    # Report validation results
    report_schema_validation
    
    if [ ${#SCHEMA_ERRORS[@]} -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Validate required properties
validate_required_properties() {
    local config_file="$1"
    
    # Check if at least one container source is specified
    local has_image=false
    local has_dockerfile=false
    local has_docker_compose=false
    
    if jq -e '.image' "$config_file" >/dev/null 2>&1; then
        has_image=true
    fi
    
    if jq -e '.dockerFile or .dockerfile' "$config_file" >/dev/null 2>&1; then
        has_dockerfile=true
    fi
    
    if jq -e '.dockerComposeFile' "$config_file" >/dev/null 2>&1; then
        has_docker_compose=true
    fi
    
    if [ "$has_image" = false ] && [ "$has_dockerfile" = false ] && [ "$has_docker_compose" = false ]; then
        SCHEMA_ERRORS+=("At least one container source must be specified: 'image', 'dockerFile', or 'dockerComposeFile'")
    fi
    
    # Validate service property for dockerComposeFile
    if [ "$has_docker_compose" = true ]; then
        if ! jq -e '.service' "$config_file" >/dev/null 2>&1; then
            SCHEMA_ERRORS+=("When using 'dockerComposeFile', 'service' property is required")
        fi
    fi
}

# Validate property types and formats
validate_property_types() {
    local config_file="$1"
    
    # Validate boolean properties
    validate_boolean_property "$config_file" "updateRemoteUserUID"
    validate_boolean_property "$config_file" "overrideCommand"
    validate_boolean_property "$config_file" "shutdownAction"
    
    # Validate string properties
    validate_string_property "$config_file" "name"
    validate_string_property "$config_file" "image"
    validate_string_property "$config_file" "dockerFile"
    validate_string_property "$config_file" "userEnvProbe"
    validate_string_property "$config_file" "shutdownAction"
    
    # Validate array properties
    validate_array_property "$config_file" "forwardPorts"
    validate_array_property "$config_file" "portsAttributes"
    validate_array_property "$config_file" "mounts"
    validate_array_property "$config_file" "runServices"
    validate_array_property "$config_file" "waitFor"
    
    # Validate object properties
    validate_object_property "$config_file" "features"
    validate_object_property "$config_file" "customizations"
    validate_object_property "$config_file" "containerEnv"
    validate_object_property "$config_file" "remoteEnv"
    validate_object_property "$config_file" "build"
    validate_object_property "$config_file" "workspaceMount"
    
    # Validate numeric properties in build
    if jq -e '.build' "$config_file" >/dev/null 2>&1; then
        if jq -e '.build.noCache' "$config_file" >/dev/null 2>&1; then
            local no_cache_val
            no_cache_val=$(jq -r '.build.noCache' "$config_file" 2>/dev/null)
            if [[ "$no_cache_val" != "true" && "$no_cache_val" != "false" ]]; then
                SCHEMA_ERRORS+=("build.noCache must be a boolean value")
            fi
        fi
        
        if jq -e '.build.squash' "$config_file" >/dev/null 2>&1; then
            local squash_val
            squash_val=$(jq -r '.build.squash' "$config_file" 2>/dev/null)
            if [[ "$squash_val" != "true" && "$squash_val" != "false" ]]; then
                SCHEMA_ERRORS+=("build.squash must be a boolean value")
            fi
        fi
    fi
}

# Validate boolean property
validate_boolean_property() {
    local config_file="$1"
    local property="$2"
    
    if jq -e ".${property}" "$config_file" >/dev/null 2>&1; then
        local value
        value=$(jq -r ".${property}" "$config_file" 2>/dev/null)
        if [[ "$value" != "true" && "$value" != "false" && "$value" != "null" ]]; then
            SCHEMA_ERRORS+=("Property '${property}' must be a boolean value")
        fi
    fi
}

# Validate string property
validate_string_property() {
    local config_file="$1"
    local property="$2"
    
    if jq -e ".${property}" "$config_file" >/dev/null 2>&1; then
        local value
        value=$(jq -r ".${property}" "$config_file" 2>/dev/null)
        if [ "$value" = "null" ]; then
            return 0
        fi
        if [[ ! "$value" =~ ^\".*\"$ ]] && [[ ! "$value" =~ ^[a-zA-Z0-9_/.-]+$ ]]; then
            SCHEMA_WARNINGS+=("Property '${property}' should be a valid string")
        fi
    fi
}

# Validate array property
validate_array_property() {
    local config_file="$1"
    local property="$2"
    
    if jq -e ".${property}" "$config_file" >/dev/null 2>&1; then
        if ! jq -e ".${property} | type == \"array\"" "$config_file" >/dev/null 2>&1; then
            SCHEMA_ERRORS+=("Property '${property}' must be an array")
        fi
    fi
}

# Validate object property
validate_object_property() {
    local config_file="$1"
    local property="$2"
    
    if jq -e ".${property}" "$config_file" >/dev/null 2>&1; then
        if ! jq -e ".${property} | type == \"object\"" "$config_file" >/dev/null 2>&1; then
            SCHEMA_ERRORS+=("Property '${property}' must be an object")
        fi
    fi
}

# Validate deprecated properties
validate_deprecated_properties() {
    local config_file="$1"
    
    # Check for deprecated dockerfile property (should be dockerFile)
    if jq -e '.dockerfile' "$config_file" >/dev/null 2>&1; then
        if ! jq -e '.dockerFile' "$config_file" >/dev/null 2>&1; then
            SCHEMA_WARNINGS+=("Property 'dockerfile' is deprecated. Use 'dockerFile' instead")
        fi
    fi
    
    # Check for deprecated postCreateCommand in lifecycle (should be in docker.sh)
    if jq -e '.postCreateCommand' "$config_file" >/dev/null 2>&1; then
        local post_create
        post_create=$(jq -r '.postCreateCommand' "$config_file" 2>/dev/null)
        if [ -n "$post_create" ] && [ "$post_create" != "null" ]; then
            info "postCreateCommand found (handled by docker.sh)"
        fi
    fi
}

# Validate advanced features
validate_advanced_features() {
    local config_file="$1"
    
    # Validate updateRemoteUserUID with containerUser
    if jq -e '.updateRemoteUserUID' "$config_file" >/dev/null 2>&1; then
        local update_uid
        update_uid=$(jq -r '.updateRemoteUserUID' "$config_file" 2>/dev/null)
        if [ "$update_uid" = "true" ]; then
            if ! jq -e '.containerUser' "$config_file" >/dev/null 2>&1; then
                SCHEMA_WARNINGS+=("updateRemoteUserUID is true but no containerUser specified")
            fi
        fi
    fi
    
    # Validate workspaceMount syntax
    if jq -e '.workspaceMount' "$config_file" >/dev/null 2>&1; then
        local workspace_mount
        workspace_mount=$(jq -r '.workspaceMount' "$config_file" 2>/dev/null)
        if [ -n "$workspace_mount" ] && [ "$workspace_mount" != "null" ]; then
            # Check if it's a valid mount string format
            if [[ ! "$workspace_mount" =~ ^source=.*target=.*type=.* ]]; then
                SCHEMA_WARNINGS+=("workspaceMount should use 'source=X,target=Y,type=Z' format")
            fi
        fi
    fi
    
    # Validate portsAttributes structure
    if jq -e '.portsAttributes' "$config_file" >/dev/null 2>&1; then
        if jq -e '.portsAttributes | to_entries[] | select(.value.label)' "$config_file" >/dev/null 2>&1; then
            info "portsAttributes with labels found"
        fi
        if jq -e '.portsAttributes | to_entries[] | select(.value.onAutoForward)' "$config_file" >/dev/null 2>&1; then
            local valid_forward_values=("notify" "silent" "error" "")
            for val in "${valid_forward_values[@]}"; do
                if ! jq -e ".portsAttributes | to_entries[] | select(.value.onAutoForward == \"$val\")" "$config_file" >/dev/null 2>&1; then
                    continue
                fi
                info "portsAttributes with onAutoForward=$val found"
                break
            done
        fi
    fi
}

# Validate features configuration
validate_features_schema() {
    local config_file="$1"
    
    if jq -e '.features' "$config_file" >/dev/null 2>&1; then
        # Validate feature ID format
        jq -r '.features | keys[]' "$config_file" 2>/dev/null | while IFS= read -r feature_id; do
            if [[ ! "$feature_id" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]] && [[ ! "$feature_id" =~ ^ghcr\.io/ ]]; then
                SCHEMA_WARNINGS+=("Feature ID '$feature_id' should use fully qualified format (registry/namespace/feature)")
            fi
        done
        
        # Validate feature configuration objects
        jq -r '.features | to_entries[] | select(.value | type == "object") | .key' "$config_file" 2>/dev/null | while IFS= read -r feature_id; do
            info "Feature '$feature_id' has object configuration"
        done
    fi
}

# Validate lifecycle commands
validate_lifecycle_schema() {
    local config_file="$1"
    
    # Validate waitFor values
    if jq -e '.waitFor' "$config_file" >/dev/null 2>&1; then
        local wait_for
        wait_for=$(jq -r '.waitFor' "$config_file" 2>/dev/null)
        case "$wait_for" in
            "onCreateCommand"|"updateContentCommand"|"postCreateCommand")
                info "Valid waitFor value: $wait_for"
                ;;
            *)
                SCHEMA_WARNINGS+=("Unknown waitFor value: '$wait_for'. Expected: onCreateCommand, updateContentCommand, or postCreateCommand")
                ;;
        esac
    fi
    
    # Validate initializeCommand exists and is string
    if jq -e '.initializeCommand' "$config_file" >/dev/null 2>&1; then
        local init_cmd
        init_cmd=$(jq -r '.initializeCommand' "$config_file" 2>/dev/null)
        if [ "$init_cmd" = "null" ]; then
            SCHEMA_ERRORS+=("initializeCommand cannot be null")
        fi
    fi
}

# Validate tool integration
validate_integration_schema() {
    local config_file="$1"
    
    if jq -e '.customizations' "$config_file" >/dev/null 2>&1; then
        # Validate VS Code customizations
        if jq -e '.customizations.vscode' "$config_file" >/dev/null 2>&1; then
            if jq -e '.customizations.vscode.extensions' "$config_file" >/dev/null 2>&1; then
                if ! jq -e '.customizations.vscode.extensions | type == "array"' "$config_file" >/dev/null 2>&1; then
                    SCHEMA_ERRORS+=("customizations.vscode.extensions must be an array")
                fi
            fi
            
            if jq -e '.customizations.vscode.settings' "$config_file" >/dev/null 2>&1; then
                if ! jq -e '.customizations.vscode.settings | type == "object"' "$config_file" >/dev/null 2>&1; then
                    SCHEMA_ERRORS+=("customizations.vscode.settings must be an object")
                fi
            fi
            
            if jq -e '.customizations.vscode.commands' "$config_file" >/dev/null 2>&1; then
                if ! jq -e '.customizations.vscode.commands | type == "array"' "$config_file" >/dev/null 2>&1; then
                    SCHEMA_ERRORS+=("customizations.vscode.commands must be an array")
                fi
            fi
        fi
    fi
}

# Report schema validation results
report_schema_validation() {
    echo ""
    echo "Devcontainer Schema Validation Results:"
    echo "====================================="
    
    if [ ${#SCHEMA_ERRORS[@]} -gt 0 ]; then
        echo ""
        echo "❌ Validation Errors:"
        for error in "${SCHEMA_ERRORS[@]}"; do
            echo "  - $error"
        done
    fi
    
    if [ ${#SCHEMA_WARNINGS[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Validation Warnings:"
        for warning in "${SCHEMA_WARNINGS[@]}"; do
            echo "  - $warning"
        done
    fi
    
    if [ ${#SCHEMA_ERRORS[@]} -eq 0 ] && [ ${#SCHEMA_WARNINGS[@]} -eq 0 ]; then
        echo ""
        echo "✅ Schema validation passed with no errors or warnings"
    elif [ ${#SCHEMA_ERRORS[@]} -eq 0 ]; then
        echo ""
        echo "✅ Schema validation passed with warnings"
    else
        echo ""
        echo "❌ Schema validation failed with errors"
    fi
    
    echo ""
    echo "Devcontainer Specification Version: $DEVCONTAINER_SPEC_VERSION"
    echo "Validation Tool: dcutil schema validator"
}

# Show schema validation status
show_schema_status() {
    if [ ${#SCHEMA_ERRORS[@]} -eq 0 ] && [ ${#SCHEMA_WARNINGS[@]} -eq 0 ]; then
        echo "✅ Schema validation: PASSED"
        return 0
    elif [ ${#SCHEMA_ERRORS[@]} -eq 0 ]; then
        echo "⚠️  Schema validation: PASSED with warnings"
        return 0
    else
        echo "❌ Schema validation: FAILED"
        return 1
    fi
}

# Cleanup schema validation state
cleanup_schema_validation() {
    SCHEMA_ERRORS=()
    SCHEMA_WARNINGS=()
    info "Schema validation state cleaned up"
}