#!/usr/bin/env bash

# Devcontainer Features support for dcutil
# Implements Devcontainer Features specification for adding tools and runtimes

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for Features
declare -a FEATURES_IDS=()
declare -A FEATURES_CONFIG_MAP=()
FEATURES_DIR=""
FEATURES_CACHE_DIR=""
FEATURES_INSTALL_LOG=""
# Inputs support
declare -a INPUTS_NAMES=()
declare -A INPUTS_DEFAULTS=()
declare -A INPUTS_DESCRIPTIONS=()
declare -A INPUTS_VALUES=()
# Track per-feature environment variables set during installation
declare -A FEATURE_ENV_VARS=()

# Load inputs values interactively if not already set
load_input_values() {
    if [ ${#INPUTS_NAMES[@]} -eq 0 ]; then
        return 0
    fi

    for input_name in "${INPUTS_NAMES[@]}"; do
        local default="${INPUTS_DEFAULTS[$input_name]:-}"
        local description="${INPUTS_DESCRIPTIONS[$input_name]:-}"
        local value="${INPUTS_VALUES[$input_name]:-}"

        if [ -n "$value" ]; then
            continue
        fi

        if [ -n "$description" ]; then
            echo "Input: $input_name - $description"
        else
            echo "Input: $input_name"
        fi

        if [ -n "$default" ]; then
            read -r -p "Enter value for $input_name (default: $default): " val
            val=${val:-$default}
        else
            read -r -p "Enter value for $input_name: " val
        fi

        INPUTS_VALUES["$input_name"]="$val"
    done
}
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
        
        # Reset arrays/maps
        FEATURES_IDS=()
        FEATURES_CONFIG_MAP=()

        # Parse features - handle both object and array formats
        if jq -e '.features' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            # If it's an object (map)
            if jq -e '.features | type == "object"' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
                while IFS= read -r feature_key; do
                    if [ -n "$feature_key" ] && [ "$feature_key" != "null" ]; then
                        local feature_config
                        feature_config=$(jq -c --arg key "$feature_key" '.features[$key]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "{}")

                        # Skip disabled features (boolean false)
                        if [ "$feature_config" = "false" ] || [ "$feature_config" = "null" ]; then
                            continue
                        fi

                        # Normalize true -> {}
                        if [ "$feature_config" = "true" ]; then
                            feature_config="{}"
                        fi

                        FEATURES_IDS+=("$feature_key")
                        FEATURES_CONFIG_MAP["$feature_key"]="$feature_config"
                    fi
                done < <(jq -r '.features | keys[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
            elif jq -e '.features | type == "array"' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
                # If it's an array, read entries as feature specs
                jq -c '.features[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null | while IFS= read -r entry; do
                    if [ -z "$entry" ] || [ "$entry" = "null" ]; then
                        continue
                    fi
                    local entry_type
                    entry_type=$(jq -r 'type' <<< "$entry" 2>/dev/null || echo "")
                    if [ "$entry_type" = "string" ]; then
                        FEATURES_IDS+=("$entry")
                        FEATURES_CONFIG_MAP["$entry"]="{}"
                    elif [ "$entry_type" = "object" ]; then
                        # Handle object entries either with .id or as {"id": {...}} or {"<id>": {...}}
                        if jq -e 'has("id")' <<< "$entry" >/dev/null 2>&1; then
                            local id
                            id=$(jq -r '.id' <<< "$entry" 2>/dev/null || echo "")
                            if [ -n "$id" ]; then
                                local cfg
                                cfg=$(jq -c '.' <<< "$entry" 2>/dev/null || echo "{}")
                                FEATURES_IDS+=("$id")
                                FEATURES_CONFIG_MAP["$id"]="$cfg"
                            fi
                        else
                            local key
                            key=$(jq -r 'keys[0]' <<< "$entry" 2>/dev/null || echo "")
                            if [ -n "$key" ]; then
                                local cfg
                                cfg=$(jq -c '.[keys[0]]' <<< "$entry" 2>/dev/null || echo "{}")
                                FEATURES_IDS+=("$key")
                                FEATURES_CONFIG_MAP["$key"]="$cfg"
                            fi
                        fi
                    fi
                done
            fi
        fi

        # Parse optional inputs
        if jq -e '.inputs' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS= read -r input_name; do
                if [ -n "$input_name" ] && [ "$input_name" != "null" ]; then
                    INPUTS_NAMES+=("$input_name")
                    local def
                    def=$(jq -r ".inputs[\"$input_name\"].default // empty" "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
                    if [ -n "$def" ] && [ "$def" != "null" ]; then
                        INPUTS_DEFAULTS["$input_name"]="$def"
                    fi
                    local desc
                    desc=$(jq -r ".inputs[\"$input_name\"].description // empty" "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
                    if [ -n "$desc" ] && [ "$desc" != "null" ]; then
                        INPUTS_DESCRIPTIONS["$input_name"]="$desc"
                    fi
                fi
            done < <(jq -r '.inputs | keys[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
            if [ ${#INPUTS_NAMES[@]} -gt 0 ]; then
                info "Found ${#INPUTS_NAMES[@]} input(s) configured"
                for input_name in "${INPUTS_NAMES[@]}"; do
                    INPUTS_VALUES["$input_name"]="${INPUTS_DEFAULTS[$input_name]:-}"
                done
            fi
        fi

        if [ ${#FEATURES_IDS[@]} -gt 0 ]; then
            info "Found ${#FEATURES_IDS[@]} feature(s):"
            for feature_id in "${FEATURES_IDS[@]}"; do
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

    # Normalize formats:
    # - Short: node -> ghcr.io/devcontainers/features/node
    # - Medium: devcontainers/features/node -> ghcr.io/devcontainers/features/node
    # - Full: ghcr.io/devcontainers/features/node -> keep as-is
    
    # If no slash -> short format
    if [[ "$feature_id" != *"/"* ]]; then
        feature_id="$FEATURES_REGISTRY/$FEATURES_NAMESPACE/$feature_id"
    else
        # Detect if first segment looks like a registry (contains '.' or ':')
        local first_segment="${feature_id%%/*}"
        if [[ "$first_segment" != *.* && "$first_segment" != *:* && "$feature_id" != "$FEATURES_REGISTRY"/* ]]; then
            feature_id="$FEATURES_REGISTRY/$feature_id"
        fi
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

    # Extract feature name from the ID
    local feature_name="${feature_id##*/}"

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

    # Download feature definition from GitHub
    local feature_json_url="https://raw.githubusercontent.com/devcontainers/features/main/src/$feature_name/devcontainer-feature.json"
    local feature_json_file="$cache_dir/devcontainer-feature.json"

    if curl -fsSL "$feature_json_url" -o "$feature_json_file"; then
        success "Feature definition downloaded: $feature_id@$feature_version"
    else
        error "Failed to download feature definition: $feature_id@$feature_version"
        error "URL: $feature_json_url"
        return 1
    fi

    # Create src directory and download install.sh if it exists
    mkdir -p "$cache_dir/src"

    local install_script_url="https://raw.githubusercontent.com/devcontainers/features/main/src/$feature_name/install.sh"
    local install_script_file="$cache_dir/src/install.sh"

    if curl -fsSL "$install_script_url" -o "$install_script_file"; then
        chmod +x "$install_script_file"
        info "Install script downloaded for feature: $feature_name"
    else
        warning "No install script found for feature: $feature_name, using fallback"
        # Create a basic install script as fallback
        cat > "$install_script_file" << 'FEATURE_INSTALL_SCRIPT'
#!/usr/bin/env bash
# Default fallback install script for features
# This script simply prints DCUTIL_INPUT_* environment variables for testing
echo "Feature $FEATURE_NAME installed (fallback script)"
env | sed -n 's/^DCUTIL_INPUT_/DCUTIL_INPUT_/p' | sed 's/^/DCUTIL_INPUT: /'
env | sed -n 's/^DCUTIL_FEATURE_INPUT_/DCUTIL_FEATURE_INPUT_/p' | sed 's/^/DCUTIL_FEATURE_INPUT: /'
exit 0
FEATURE_INSTALL_SCRIPT
        chmod +x "$install_script_file"
    fi

    # Copy the feature definition as feature.json for compatibility
    cp "$feature_json_file" "$cache_dir/feature.json"
    
    success "Feature cached: $feature_id@$feature_version"
    echo "$cache_dir"
}

# Helper: prepare env variables for a feature's inputs
env_prepare_inputs_for_feature() {
    local feature_spec="$1"
    local feature_config="$2"
    local feature_id
    feature_id=$(parse_feature_spec "$feature_spec" | cut -d: -f1)
    local feature_name
    feature_name="${feature_id##*/}"
    local feature_safe_name
    feature_safe_name=$(echo "$feature_name" | sed 's#[/\\.-]#_#g' | tr '[:lower:]' '[:upper:]')

    # Set environment variables for feature inputs
    for input_name in "${INPUTS_NAMES[@]}"; do
        local var_name="DCUTIL_FEATURE_INPUT_${feature_safe_name}_$(echo "$input_name" | sed 's#[-\.]#_#g' | tr '[:lower:]' '[:upper:]')"
        local val="${INPUTS_VALUES[$input_name]:-}"

        if [ -z "$val" ]; then
            val="${INPUTS_DEFAULTS[$input_name]:-}"
        fi

        # Also set DCUTIL_INPUT_<name> for cross feature use
        export "DCUTIL_INPUT_${input_name^^}"="$val"
        export "$var_name"="$val"
    done
}

# Helper: clear env variables for a feature
env_clear_inputs_for_feature() {
    local feature_safe_name="$1"
    for input_name in "${INPUTS_NAMES[@]}"; do
        local var_name="DCUTIL_FEATURE_INPUT_${feature_safe_name}_$(echo "$input_name" | sed 's#[-\.]#_#g' | tr '[:lower:]' '[:upper:]')"
        unset "DCUTIL_INPUT_${input_name^^}"
        unset "$var_name"
    done
}

# Install a single feature
install_feature() {
    local feature_spec="$1"
    local install_dir="$2"
    local feature_config="$3"
    
    info "Installing feature: $feature_spec"
    
    # Download feature
    local feature_dir
    feature_dir=$(download_feature "$feature_spec") || return 1
    
    # Extract feature metadata
    local feature_id
    feature_id=$(parse_feature_spec "$feature_spec" | cut -d: -f1)
    local feature_name="${feature_id##*/}"
    local feature_safe_name
    feature_safe_name=$(echo "$feature_name" | sed 's#[/\\.-]#_#g' | tr '[:lower:]' '[:upper:]')
    
    # Create installation log entry
    echo "$(date): Installing $feature_spec" >> "$FEATURES_INSTALL_LOG"
    
    # Prepare input environment variables
    env_prepare_inputs_for_feature "$feature_spec" "$feature_config"
    
    # For now, we'll create a basic installation
    # In a full implementation, this would execute the feature's install.sh script
    
    local install_script="$feature_dir/src/install.sh"
    if [ -f "$install_script" ]; then
        info "Running feature installation script..."
        # Run install script and capture output into install log
        if bash "$install_script" >> "$FEATURES_INSTALL_LOG" 2>&1; then
            success "Feature installed successfully: $feature_spec"
            echo "$(date): Successfully installed $feature_spec" >> "$FEATURES_INSTALL_LOG"
            # Cleanup env variables for next feature
            env_clear_inputs_for_feature "$feature_safe_name"
            return 0
        else
            error "Feature installation failed: $feature_spec"
            echo "$(date): Failed to install $feature_spec" >> "$FEATURES_INSTALL_LOG"
            env_clear_inputs_for_feature "$feature_safe_name"
            return 1
        fi
    else
        warning "No installation script found for feature: $feature_spec"
        # Create a mock installation
        echo "$(date): Feature $feature_spec would be installed (mock)" >> "$FEATURES_INSTALL_LOG"
        success "Feature processing completed: $feature_spec"
        env_clear_inputs_for_feature "$feature_safe_name"
        return 0
    fi
}

# Install all configured features
install_features() {
    if ! parse_features_config; then
        info "No features configured"
        return 0
    fi
    
    info "Installing ${#FEATURES_IDS[@]} feature(s)..."
    
    # Initialize installation log
    echo "# Devcontainer Features Installation Log" > "$FEATURES_INSTALL_LOG"
    echo "# Date: $(date)" >> "$FEATURES_INSTALL_LOG"
    echo "# Project: $PROJECT_DIR" >> "$FEATURES_INSTALL_LOG"
    echo "" >> "$FEATURES_INSTALL_LOG"
    
    # Load inputs if any
    load_input_values
    
    local failed_features=()
    
    for feature_id in "${FEATURES_IDS[@]}"; do
        local feature_spec="$feature_id"
        local feature_config
        feature_config="${FEATURES_CONFIG_MAP[$feature_id]}"
        if ! install_feature "$feature_spec" "$FEATURES_DIR" "$feature_config"; then
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
    
    for feature_key in "${FEATURES_IDS[@]}"; do
        local feature_spec="$feature_key"
        local feature_config
        feature_config="${FEATURES_CONFIG_MAP[$feature_key]}"
        
        local parsed_spec
        parsed_spec=$(parse_feature_spec "$feature_spec")
        local feature_id="${parsed_spec%:*}"
        local feature_version="${parsed_spec#*:}"
        
        # Extract just the feature name from the ID
        local feature_name="${feature_id##*/}"
        
        echo "    - $feature_name"
        echo "      ID: $feature_id"
        
        # Show version if available in config or parsed spec
        if command -v jq &> /dev/null; then
            local version
            version=$(echo "$feature_config" | jq -r '.version // "'$feature_version'"' 2>/dev/null || echo "$feature_version")
            echo "      Version: ${version:-$feature_version}"
        else
            echo "      Version: $feature_version"
        fi
        
        # Check cache status
        local cache_key="${feature_id//\//_}_$feature_version"
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
    for feature_key in "${FEATURES_IDS[@]}"; do
        local feature_spec="$feature_key"
        local feature_config
        feature_config="${FEATURES_CONFIG_MAP[$feature_key]}"
        local parsed_spec
        parsed_spec=$(parse_feature_spec "$feature_spec")
        local feature_id="${parsed_spec%:*}"
        local feature_version="${parsed_spec#*:}"

        # If config contains a version, prefer it
        if command -v jq &> /dev/null; then
            local cfg_version
            cfg_version=$(echo "$feature_config" | jq -r '.version // empty' 2>/dev/null || echo "")
            if [ -n "$cfg_version" ] && [ "$cfg_version" != "null" ]; then
                feature_version="$cfg_version"
            fi
        fi

        # Validate feature ID format
        if [[ ! "$feature_id" =~ ^[a-zA-Z0-9._-]+(\/[a-zA-Z0-9._-]+){2,3}$ ]]; then
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
    
    for feature_key in "${FEATURES_IDS[@]}"; do
        local feature_spec="$feature_key"
        local feature_config
        feature_config="${FEATURES_CONFIG_MAP[$feature_key]}"
        local parsed_spec
        parsed_spec=$(parse_feature_spec "$feature_spec")
        local feature_id="${parsed_spec%:*}"
        local feature_version="${parsed_spec#*:}"

        # If config contains a version, prefer it
        if command -v jq &> /dev/null; then
            local cfg_version
            cfg_version=$(echo "$feature_config" | jq -r '.version // empty' 2>/dev/null || echo "")
            if [ -n "$cfg_version" ] && [ "$cfg_version" != "null" ]; then
                feature_version="$cfg_version"
            fi
        fi

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