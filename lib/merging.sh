#!/usr/bin/env bash

# Image Metadata Merging support for dcutil
# Implements the merge logic between image metadata and devcontainer.json per specification

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Wrapper functions for main script compatibility
devcontainer_merging_show() {
    show_merged_config
}

devcontainer_merging_validate() {
    validate_merged_config
}

devcontainer_merging_cleanup() {
    cleanup_merged_config
}

# Global variables for metadata merging
IMAGE_METADATA_MERGED=()
MERGED_CONFIG_FILE=""

# Check if metadata merging is needed
needs_metadata_merging() {
    if [ -z "${IMAGE_NAME:-}" ]; then
        return 1
    fi
    
    # Check if image has devcontainer metadata
    local metadata_label
    metadata_label=$(docker image inspect "$IMAGE_NAME" -f '{{index .Config.Labels "devcontainer.metadata"}}' 2>/dev/null || echo "")
    
    if [ -n "$metadata_label" ]; then
        return 0
    fi
    
    return 1
}

merge_features_property() {
    local metadata_entry="$1"
    if ! command -v jq &>/dev/null; then
        return 1
    fi

    local existing_features
    existing_features=$(jq '.features // {}' "$MERGED_CONFIG_FILE" 2>/dev/null || echo "{}")
    local metadata_features
    metadata_features=$(echo "$metadata_entry" | jq '.features // {}' 2>/dev/null || echo "{}")

    # Merge feature objects - keys from devcontainer.json take precedence
    local merged_features
    merged_features=$(jq -s '.[0] + .[1]' <<< "$metadata_features $existing_features" 2>/dev/null || echo "{}")

    local temp_file
    temp_file=$(mktemp)
    jq ".features = $merged_features" "$MERGED_CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$MERGED_CONFIG_FILE"
}

# Parse and merge image metadata with devcontainer.json
merge_image_metadata() {
    if ! needs_metadata_merging; then
        info "No image metadata to merge"
        return 0
    fi
    
    info "Merging image metadata with devcontainer.json..."
    
    # Create temporary merged configuration
    MERGED_CONFIG_FILE=$(mktemp)
    
    # Start with devcontainer.json as base
    cp "$DEVCONTAINER_CONFIG_FILE" "$MERGED_CONFIG_FILE"
    
    # Extract image metadata
    local metadata_label
    metadata_label=$(docker image inspect "$IMAGE_NAME" -f '{{index .Config.Labels "devcontainer.metadata"}}' 2>/dev/null || echo "")
    
    if [ -z "$metadata_label" ]; then
        return 0
    fi
    
    # Parse metadata array
    if command -v jq &> /dev/null; then
        echo "$metadata_label" | jq -c '.[]' 2>/dev/null | while IFS= read -r metadata_entry; do
            if [ -n "$metadata_entry" ]; then
                IMAGE_METADATA_MERGED+=("$metadata_entry")
            fi
        done
        
        # Apply merge logic for each metadata entry
        for metadata_entry in "${IMAGE_METADATA_MERGED[@]}"; do
            merge_single_metadata_entry "$metadata_entry"
        done
    fi
    
    # Replace original config with merged version
    DEVCONTAINER_CONFIG_FILE="$MERGED_CONFIG_FILE"
    
    success "Image metadata merged successfully"
    return 0
}

# Merge a single metadata entry with devcontainer.json
merge_single_metadata_entry() {
    local metadata_entry="$1"
    
    if ! command -v jq &> /dev/null; then
        return 1
    fi
    
    info "Merging metadata entry..."
    
    # Apply merge logic based on specification table
    # Note: This is a simplified implementation of the merge logic
    # Full implementation would handle all property types and merge rules
    
    # Merge capAdd (Union without duplicates)
    if echo "$metadata_entry" | jq -e '.capAdd' >/dev/null 2>&1; then
        merge_array_property "capAdd" "$metadata_entry"
    fi
    
    # Merge securityOpt (Union without duplicates)
    if echo "$metadata_entry" | jq -e '.securityOpt' >/dev/null 2>&1; then
        merge_array_property "securityOpt" "$metadata_entry"
    fi
    
    # Merge mounts (Collected list, conflicts: Last source wins)
    if echo "$metadata_entry" | jq -e '.mounts' >/dev/null 2>&1; then
        merge_mounts_property "$metadata_entry"
    fi
    
    # Merge lifecycle commands (Collected list)
    merge_lifecycle_commands "onCreateCommand" "$metadata_entry"
    merge_lifecycle_commands "updateContentCommand" "$metadata_entry"
    merge_lifecycle_commands "postCreateCommand" "$metadata_entry"
    merge_lifecycle_commands "postStartCommand" "$metadata_entry"
    merge_lifecycle_commands "postAttachCommand" "$metadata_entry"
    
    # Merge customizations (Left to tools)
    if echo "$metadata_entry" | jq -e '.customizations' >/dev/null 2>&1; then
        merge_object_property "customizations" "$metadata_entry"
    fi
    
    # Merge features property (union, devcontainer.json overrides image metadata)
    if echo "$metadata_entry" | jq -e '.features' >/dev/null 2>&1; then
        merge_features_property "$metadata_entry"
    fi

    # Merge other properties (Last value wins)
    merge_string_property "containerUser" "$metadata_entry"
    merge_string_property "remoteUser" "$metadata_entry"
    merge_string_property "userEnvProbe" "$metadata_entry"
    merge_object_property "remoteEnv" "$metadata_entry"
    merge_object_property "containerEnv" "$metadata_entry"
    merge_boolean_property "overrideCommand" "$metadata_entry"
    merge_string_property "shutdownAction" "$metadata_entry"
    merge_boolean_property "updateRemoteUserUID" "$metadata_entry"
}

# Merge array properties (Union without duplicates)
merge_array_property() {
    local property="$1"
    local metadata_entry="$2"
    
    if ! command -v jq &> /dev/null; then
        return 1
    fi
    
    # Get existing array from devcontainer.json
    local existing_array
    existing_array=$(jq ".$property // []" "$MERGED_CONFIG_FILE" 2>/dev/null || echo "[]")
    
    # Get new array from metadata
    local new_array
    new_array=$(echo "$metadata_entry" | jq ".$property // []" 2>/dev/null || echo "[]")
    
    # Combine arrays and remove duplicates
    local combined_array
    combined_array=$(jq -s 'add | unique' <<< "$existing_array $new_array" 2>/dev/null || echo "[]")
    
    # Update the merged config
    local temp_file
    temp_file=$(mktemp)
    jq ".$property = $combined_array" "$MERGED_CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$MERGED_CONFIG_FILE"
}

# Merge mounts property with conflict resolution
merge_mounts_property() {
    local metadata_entry="$1"
    
    if ! command -v jq &> /dev/null; then
        return 1
    fi
    
    # Get existing mounts
    local existing_mounts
    existing_mounts=$(jq '.mounts // []' "$MERGED_CONFIG_FILE" 2>/dev/null || echo "[]")
    
    # Get new mounts from metadata
    local new_mounts
    new_mounts=$(echo "$metadata_entry" | jq '.mounts // []' 2>/dev/null || echo "[]")
    
    # For mounts, we'll append new mounts but respect "last source wins" for conflicts
    # This is a simplified implementation
    local combined_mounts
    combined_mounts=$(jq -s 'add' <<< "$existing_mounts $new_mounts" 2>/dev/null || echo "[]")
    
    # Update the merged config
    local temp_file
    temp_file=$(mktemp)
    jq ".mounts = $combined_mounts" "$MERGED_CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$MERGED_CONFIG_FILE"
}

# Merge lifecycle commands (Collected list)
merge_lifecycle_commands() {
    local property="$1"
    local metadata_entry="$2"
    
    if ! command -v jq &> /dev/null; then
        return 1
    fi
    
    # Get existing command
    local existing_cmd
    existing_cmd=$(jq ".$property" "$MERGED_CONFIG_FILE" 2>/dev/null || echo "null")
    
    # Get new command from metadata
    local new_cmd
    new_cmd=$(echo "$metadata_entry" | jq ".$property" 2>/dev/null || echo "null")
    
    # If both exist, combine them into an array
    if [ "$existing_cmd" != "null" ] && [ "$new_cmd" != "null" ]; then
        # Convert to arrays if they aren't already
        local existing_array
        if echo "$existing_cmd" | jq -e 'type == "array"' >/dev/null 2>&1; then
            existing_array="$existing_cmd"
        else
            existing_array="[$existing_cmd]"
        fi
        
        local new_array
        if echo "$new_cmd" | jq -e 'type == "array"' >/dev/null 2>&1; then
            new_array="$new_cmd"
        else
            new_array="[$new_cmd]"
        fi
        
        # Combine arrays
        local combined
        combined=$(jq -s 'add' <<< "$existing_array $new_array" 2>/dev/null || echo "[]")
        
        # Update the merged config
        local temp_file
        temp_file=$(mktemp)
        jq ".$property = $combined" "$MERGED_CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$MERGED_CONFIG_FILE"
    elif [ "$new_cmd" != "null" ]; then
        # Only new command exists, use it
        local temp_file
        temp_file=$(mktemp)
        jq ".$property = $new_cmd" "$MERGED_CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$MERGED_CONFIG_FILE"
    fi
}

# Merge object properties
merge_object_property() {
    local property="$1"
    local metadata_entry="$2"
    
    if ! command -v jq &> /dev/null; then
        return 1
    fi
    
    # Get existing object
    local existing_obj
    existing_obj=$(jq ".$property // {}" "$MERGED_CONFIG_FILE" 2>/dev/null || echo "{}")
    
    # Get new object from metadata
    local new_obj
    new_obj=$(echo "$metadata_entry" | jq ".$property // {}" 2>/dev/null || echo "{}")
    
    # Merge objects (new values override existing)
    local merged_obj
    merged_obj=$(jq -s '.[0] + .[1]' <<< "$existing_obj $new_obj" 2>/dev/null || echo "{}")
    
    # Update the merged config
    local temp_file
    temp_file=$(mktemp)
    jq ".$property = $merged_obj" "$MERGED_CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$MERGED_CONFIG_FILE"
}

# Merge string properties (Last value wins)
merge_string_property() {
    local property="$1"
    local metadata_entry="$2"
    
    if ! command -v jq &> /dev/null; then
        return 1
    fi
    
    # Get new value from metadata
    local new_value
    new_value=$(echo "$metadata_entry" | jq -r ".$property" 2>/dev/null || echo "null")
    
    # If new value exists, override existing
    if [ "$new_value" != "null" ] && [ "$new_value" != "" ]; then
        local temp_file
        temp_file=$(mktemp)
        jq ".$property = \"$new_value\"" "$MERGED_CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$MERGED_CONFIG_FILE"
    fi
}

# Merge boolean properties (Last value wins)
merge_boolean_property() {
    local property="$1"
    local metadata_entry="$2"
    
    if ! command -v jq &> /dev/null; then
        return 1
    fi
    
    # Get new value from metadata
    local new_value
    new_value=$(echo "$metadata_entry" | jq ".$property" 2>/dev/null || echo "null")
    
    # If new value exists, override existing
    if [ "$new_value" != "null" ]; then
        local temp_file
        temp_file=$(mktemp)
        jq ".$property = $new_value" "$MERGED_CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$MERGED_CONFIG_FILE"
    fi
}

# Show merged configuration
show_merged_config() {
    if [ -z "${MERGED_CONFIG_FILE:-}" ]; then
        echo "No merged configuration available."
        return 0
    fi
    
    echo "Merged Configuration (Image Metadata + devcontainer.json):"
    echo "========================================================"
    cat "$MERGED_CONFIG_FILE" | jq '.' 2>/dev/null || cat "$MERGED_CONFIG_FILE"
}

# Validate merged configuration
validate_merged_config() {
    if [ -z "${MERGED_CONFIG_FILE:-}" ]; then
        echo "No merged configuration to validate."
        return 0
    fi
    
    info "Validating merged configuration..."
    
    # Basic JSON validation
    if ! jq '.' "$MERGED_CONFIG_FILE" >/dev/null 2>&1; then
        error "Merged configuration is not valid JSON"
        return 1
    fi
    
    # Check for conflicting properties
    local conflicts=()
    
    # Add validation logic for specific property conflicts
    # This is where you would add specific validation rules
    
    if [ ${#conflicts[@]} -gt 0 ]; then
        echo "Configuration conflicts detected:"
        for conflict in "${conflicts[@]}"; do
            echo "  - $conflict"
        done
        return 1
    fi
    
    success "Merged configuration is valid"
    return 0
}

# Cleanup merged configuration
cleanup_merged_config() {
    if [ -n "${MERGED_CONFIG_FILE:-}" ] && [ -f "$MERGED_CONFIG_FILE" ]; then
        rm -f "$MERGED_CONFIG_FILE"
    fi
    MERGED_CONFIG_FILE=""
}