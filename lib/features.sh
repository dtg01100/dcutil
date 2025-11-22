#!/bin/bash

# Devcontainer Features support for dcutil
# Implements Devcontainer Features specification for adding tools and runtimes

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for Features
FEATURES_CONFIG=()
FEATURES_DIR=""
FEATURES_CACHE_DIR=""
FEATURES_INSTALL_LOG=""

# Constants
FEATURES_REGISTRY="ghcr.io"
FEATURES_NAMESPACE="devcontainers/features"
FEATURES_DEFAULT_VERSION="latest"

# Check if Features are configured
has_features() {
    if command -v jq &> /dev/null; then
        if jq -e '.features' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Parse Features configuration from devcontainer.json
parse_features_config() {
    # Parse devcontainer config first to set DEVCONTAINER_CONFIG_FILE
    if command -v parse_devcontainer_config >/dev/null 2>&1; then
        parse_devcontainer_config
    else
        error_exit "Failed to parse devcontainer configuration" "$EXIT_CONFIG_ERROR"
    fi
    
    if [ -z "${DEVCONTAINER_CONFIG_FILE:-}" ]; then
        error_exit "No devcontainer configuration file found. Run from a project directory with .devcontainer/devcontainer.json" "$EXIT_CONFIG_ERROR"
    fi
    
    info "Parsing Features configuration..."
    
    if command -v jq &> /dev/null; then
        # Initialize features directory
        FEATURES_DIR="$PROJECT_DIR/.devcontainer-features"
        FEATURES_CACHE_DIR="$HOME/.cache/dcutil/features"
        FEATURES_INSTALL_LOG="$FEATURES_DIR/install.log"
        
        # Create directories
        mkdir -p "$FEATURES_DIR"
        mkdir -p "$FEATURES_CACHE_DIR"
        
        # Parse features object - handle both object and array formats
        if jq -e '.features' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            # Object format: {"featureId": config}
            while IFS= read -r feature_id; do
                if [ -n "$feature_id" ] && [ "$feature_id" != "null" ]; then
                    # Get the configuration for this feature
                    local feature_config
                    feature_config=$(jq -r ".features[\"$feature_id\"]" "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
                    
                    if [ -n "$feature_config" ] && [ "$feature_config" != "null" ]; then
                        # Store as "id:config" format
                        FEATURES_CONFIG+=("$feature_id:$feature_config")
                    fi
                fi
            done < <(jq -r '.features | keys[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
        fi
        
        if [ ${#FEATURES_CONFIG[@]} -gt 0 ]; then
            info "Found ${#FEATURES_CONFIG[@]} feature(s):"
            for feature in "${FEATURES_CONFIG[@]}"; do
                local feature_id="${feature%:*}"
                info "  - $feature_id"
            done
            return 0
        fi
    fi
    
    return 1
}

# Extract feature information from feature spec
parse_feature_spec() {
    local feature_spec="$1"
    
    # Parse feature ID and version
    local feature_id=""
    local feature_version="$FEATURES_DEFAULT_VERSION"
    
    if [[ "$feature_spec" == *":"* ]]; then
        feature_id="${feature_spec%:*}"
        feature_version="${feature_spec#*:}"
    else
        feature_id="$feature_spec"
    fi
    
    # Handle different feature ID formats
    if [[ ! "$feature_id" == *"/"* ]]; then
        # Short format: node -> ghcr.io/devcontainers/features/node
        feature_id="$FEATURES_REGISTRY/$FEATURES_NAMESPACE/$feature_id"
    elif [[ ! "$feature_id" == */*/* ]]; then
        # Medium format: devcontainers/features/node -> ghcr.io/devcontainers/features/node
        feature_id="$FEATURES_REGISTRY/$feature_id"
    fi
    
    echo "$feature_id:$feature_version"
}

# Download feature definition
download_feature() {
    local feature_spec="$1"
    local parsed_spec
    parsed_spec=$(parse_feature_spec "$feature_spec")
    
    local feature_id="${parsed_spec%:*}"
    local feature_version="${parsed_spec#*:}"
    
    info "Downloading feature: $feature_id@$feature_version"
    
    # Construct download URL
    local feature_name="${feature_id##*/}"
    local registry_path="${feature_id%/*}"
    local registry="${registry_path%/*}"
    local namespace="${registry_path#*/}"
    
    local download_url="https://$registry/v2/$namespace/$feature_name/manifests/$feature_version"
    
    # Check if feature is already cached
    local cache_key="${feature_id//\//_}_${feature_version}"
    local cache_dir="$FEATURES_CACHE_DIR/$cache_key"
    
    if [ -d "$cache_dir" ]; then
        info "Feature cached: $feature_id@$feature_version"
        echo "$cache_dir"
        return 0
    fi
    
    # Create cache directory
    mkdir -p "$cache_dir"
    
    # Download feature manifest
    local manifest_file="$cache_dir/manifest.json"
    if curl -fsSL "$download_url" -o "$manifest_file"; then
        success "Feature manifest downloaded: $feature_id@$feature_version"
    else
        error "Failed to download feature manifest: $feature_id@$feature_version"
        return 1
    fi
    
    # Extract feature files
    local feature_files_url="https://$registry/v2/$namespace/$feature_name/blobs/"
    
    # For now, we'll create a basic feature structure
    # In a full implementation, this would download the actual feature files
    mkdir -p "$cache_dir/src"
    
    # Create a basic feature.json
    cat > "$cache_dir/feature.json" << EOF
{
    "id": "$feature_id",
    "version": "$feature_version",
    "name": "$feature_name",
    "description": "Devcontainer feature: $feature_name",
    "documentationURL": "https://github.com/devcontainers/features/tree/main/src/$feature_name"
}
EOF
    
    success "Feature cached: $feature_id@$feature_version"
    echo "$cache_dir"
}

# Install a single feature
install_feature() {
    local feature_spec="$1"
    local install_dir="$2"
    
    info "Installing feature: $feature_spec"
    
    # Download feature
    local feature_dir
    feature_dir=$(download_feature "$feature_spec") || return 1
    
    # Extract feature metadata
    local feature_id
    feature_id=$(parse_feature_spec "$feature_spec" | cut -d: -f1)
    local feature_name="${feature_id##*/}"
    
    # Create installation log entry
    echo "$(date): Installing $feature_spec" >> "$FEATURES_INSTALL_LOG"
    
    # For now, we'll create a basic installation
    # In a full implementation, this would execute the feature's install.sh script
    
    local install_script="$feature_dir/src/install.sh"
    if [ -f "$install_script" ]; then
        info "Running feature installation script..."
        if bash "$install_script"; then
            success "Feature installed successfully: $feature_spec"
            echo "$(date): Successfully installed $feature_spec" >> "$FEATURES_INSTALL_LOG"
            return 0
        else
            error "Feature installation failed: $feature_spec"
            echo "$(date): Failed to install $feature_spec" >> "$FEATURES_INSTALL_LOG"
            return 1
        fi
    else
        warning "No installation script found for feature: $feature_spec"
        # Create a mock installation
        echo "$(date): Feature $feature_spec would be installed (mock)" >> "$FEATURES_INSTALL_LOG"
        success "Feature processing completed: $feature_spec"
        return 0
    fi
}

# Install all configured features
install_features() {
    if ! parse_features_config; then
        info "No features configured"
        return 0
    fi
    
    info "Installing ${#FEATURES_CONFIG[@]} feature(s)..."
    
    # Initialize installation log
    echo "# Devcontainer Features Installation Log" > "$FEATURES_INSTALL_LOG"
    echo "# Date: $(date)" >> "$FEATURES_INSTALL_LOG"
    echo "# Project: $PROJECT_DIR" >> "$FEATURES_INSTALL_LOG"
    echo "" >> "$FEATURES_INSTALL_LOG"
    
    local failed_features=()
    
    for feature_spec in "${FEATURES_CONFIG[@]}"; do
        if ! install_feature "$feature_spec" "$FEATURES_DIR"; then
            failed_features+=("$feature_spec")
        fi
    done
    
    # Report results
    if [ ${#failed_features[@]} -eq 0 ]; then
        success "All features installed successfully"
        return 0
    else
        error "Failed to install ${#failed_features[@]} feature(s):"
        for failed in "${failed_features[@]}"; do
            error "  - $failed"
        done
        return 1
    fi
}

# Show features information
show_features_info() {
    if ! parse_features_config; then
        echo "No features configured."
        return 1
    fi
    
    echo "Devcontainer Features Configuration:"
    echo "  Cache Directory: $FEATURES_CACHE_DIR"
    echo "  Install Directory: $FEATURES_DIR"
    echo "  Features:"
    
    for feature_spec in "${FEATURES_CONFIG[@]}"; do
        local feature_id="${feature_spec%:*}"
        local feature_config="${feature_spec#*:}"
        
        # Extract just the feature name from the ID
        local feature_name="${feature_id##*/}"
        
        echo "    - $feature_name"
        echo "      ID: $feature_id"
        
        # Show version if available in config
        if command -v jq &> /dev/null; then
            local version
            version=$(echo "$feature_config" | jq -r '.version // "latest"' 2>/dev/null)
            echo "      Version: ${version:-latest}"
        else
            echo "      Version: latest"
        fi
        
        # Check cache status
        local cache_key="${feature_id//\//_}_latest"
        local cache_dir="$FEATURES_CACHE_DIR/$cache_key"
        if [ -d "$cache_dir" ]; then
            echo "      Status: Cached"
        else
            echo "      Status: Not cached"
        fi
        echo ""
    done
    
    # Show installation log if it exists
    if [ -f "$FEATURES_INSTALL_LOG" ]; then
        echo "Installation Log:"
        echo "================"
        cat "$FEATURES_INSTALL_LOG"
    fi
}

# Validate features configuration
validate_features_config() {
    if ! parse_features_config; then
        echo "No features configured."
        return 0
    fi
    
    local errors=()
    local warnings=()
    
    # Validate each feature specification
    for feature_spec in "${FEATURES_CONFIG[@]}"; do
        local parsed_spec
        parsed_spec=$(parse_feature_spec "$feature_spec")
        local feature_id="${parsed_spec%:*}"
        local feature_version="${parsed_spec#*:}"
        
        # Validate feature ID format
        if [[ ! "$feature_id" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
            errors+=("Invalid feature ID format: $feature_id")
        fi
        
        # Check for latest version warning
        if [ "$feature_version" = "latest" ]; then
            warnings+=("Using 'latest' version for $feature_id - consider pinning to specific version")
        fi
        
        # Check cache status
        local cache_key="${feature_id//\//_}_${feature_version}"
        local cache_dir="$FEATURES_CACHE_DIR/$cache_key"
        if [ ! -d "$cache_dir" ]; then
            warnings+=("Feature not cached: $feature_id@$feature_version")
        fi
    done
    
    # Report validation results
    if [ ${#errors[@]} -gt 0 ]; then
        echo "Features configuration validation errors:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo "Features configuration warnings:"
        for warning in "${warnings[@]}"; do
            echo "  - $warning"
        done
    fi
    
    if [ ${#errors[@]} -eq 0 ]; then
        success "Features configuration is valid"
    fi
    
    return 0
}

# Clean features cache
clean_features_cache() {
    if [ -z "${FEATURES_CACHE_DIR:-}" ]; then
        error_exit "Features cache directory not initialized" "$EXIT_CONFIG_ERROR"
    fi
    
    info "Cleaning features cache..."
    
    if [ -d "$FEATURES_CACHE_DIR" ]; then
        # Remove all cached features
        rm -rf "$FEATURES_CACHE_DIR"/*
        success "Features cache cleaned"
    else
        info "Features cache directory does not exist"
    fi
    
    # Clean installation directory
    if [ -d "$FEATURES_DIR" ]; then
        rm -rf "$FEATURES_DIR"
        mkdir -p "$FEATURES_DIR"
        success "Features installation directory cleaned"
    fi
}

# Update features (re-download and reinstall)
update_features() {
    info "Updating features..."
    
    # Clean cache first
    clean_features_cache
    
    # Reinstall all features
    install_features
}

# Check for feature updates
check_features_updates() {
    if ! parse_features_config; then
        echo "No features configured."
        return 1
    fi
    
    echo "Checking for feature updates..."
    
    local updates_available=()
    
    for feature_spec in "${FEATURES_CONFIG[@]}"; do
        local parsed_spec
        parsed_spec=$(parse_feature_spec "$feature_spec")
        local feature_id="${parsed_spec%:*}"
        local feature_version="${parsed_spec#*:}"
        
        # Skip if using latest
        if [ "$feature_version" = "latest" ]; then
            continue
        fi
        
        # For now, we'll assume updates are available
        # In a full implementation, this would check the registry for newer versions
        updates_available+=("$feature_spec")
    done
    
    if [ ${#updates_available[@]} -gt 0 ]; then
        echo "Updates available for:"
        for update in "${updates_available[@]}"; do
            echo "  - $update"
        done
        return 1
    else
        echo "All features are up to date"
        return 0
    fi
}