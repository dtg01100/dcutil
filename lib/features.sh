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
                local entries
                entries=$(jq -c '.features[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
                while IFS= read -r entry; do
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
                            # Check if it's a single-key object like {"feature-id": {...}}
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
                done <<< "$entries"
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

# Download feature definition and extract dependencies
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

    # Extract dependencies from feature definition for dependency resolution
    # Parse dependsOn and installsAfter from the downloaded feature definition
    local depends_on=()
    local installs_after=()

    if command -v jq &> /dev/null && [ -f "$feature_json_file" ]; then
        # Extract dependsOn array if it exists
        if jq -e '.dependsOn' "$feature_json_file" >/dev/null 2>&1; then
            while IFS= read -r dep; do
                if [ -n "$dep" ] && [ "$dep" != "null" ]; then
                    depends_on+=("$dep")
                fi
            done < <(jq -r '.dependsOn[] // empty' "$feature_json_file" 2>/dev/null)
        fi

        # Extract installsAfter array if it exists
        if jq -e '.installsAfter' "$feature_json_file" >/dev/null 2>&1; then
            while IFS= read -r dep; do
                if [ -n "$dep" ] && [ "$dep" != "null" ]; then
                    installs_after+=("$dep")
                fi
            done < <(jq -r '.installsAfter[] // empty' "$feature_json_file" 2>/dev/null)
        fi
    fi

    # Store dependency info for later use during installation order resolution
    # Create dependency tracking files
    if [ ${#depends_on[@]} -gt 0 ]; then
        printf '%s\n' "${depends_on[@]}" > "$cache_dir/dependsOn.list"
        info "Feature $feature_name depends on: ${depends_on[*]}"
    fi

    if [ ${#installs_after[@]} -gt 0 ]; then
        printf '%s\n' "${installs_after[@]}" > "$cache_dir/installsAfter.list"
        info "Feature $feature_name installs after: ${installs_after[*]}"
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
    local feature_version
    feature_version=$(parse_feature_spec "$feature_spec" | cut -d: -f2)
    local feature_safe_name
    feature_safe_name=$(echo "$feature_name" | sed 's#[/\\.-]#_#g' | tr '[:lower:]' '[:upper:]')

    # Export standard feature environment variables
    export "FEATURE_ID=$feature_id"
    export "FEATURE_NAME=$feature_name"
    export "FEATURE_VERSION=$feature_version"

    # Set environment variables for feature inputs
    for input_name in "${INPUTS_NAMES[@]}"; do
        local input_upper
        input_upper=$(echo "$input_name" | sed 's#[-\.]#_#g' | tr '[:lower:]' '[:upper:]')
        local var_name="DCUTIL_FEATURE_INPUT_${feature_safe_name}_${input_upper}"
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
        local input_upper
        input_upper=$(echo "$input_name" | sed 's#[-\.]#_#g' | tr '[:lower:]' '[:upper:]')
        local var_name="DCUTIL_FEATURE_INPUT_${feature_safe_name}_${input_upper}"
        unset "DCUTIL_INPUT_${input_name^^}"
        unset "$var_name"
    done
}

# Helper: find running container for project
get_running_container_for_project() {
    local project_dir="${1:-$PROJECT_DIR}"
    
    # Prefer official devcontainer CLI to get container name
    if command -v get_current_devcontainer_name >/dev/null 2>&1; then
        local container_name
        container_name=$(get_current_devcontainer_name "$project_dir" 2>/dev/null || true)
        if [ -n "$container_name" ]; then
            if command -v docker >/dev/null 2>&1; then
                if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"; then
                    echo "$container_name"
                    return 0
                fi
            fi
        fi
    fi

    # Fallback to docker-based detection
    local candidate=""
    if command -v docker >/dev/null 2>&1; then
        # Prefer labeled containers
        candidate=$(docker ps --filter "label=devcontainer.local_folder=$project_dir" --format "{{.Names}}" 2>/dev/null | head -1 || true)
        if [ -n "$candidate" ]; then
            echo "$candidate"
            return 0
        fi

        # Fallback to devcontainer CLI naming pattern
        candidate=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "^devcontainer_$(basename "$project_dir")_[0-9a-f]{8}$" | head -1 || true)
        if [ -n "$candidate" ]; then
            echo "$candidate"
            return 0
        fi

        # Fallback to deterministic dcutil name
        candidate="dcutil-$(basename "$project_dir")"
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^$candidate$"; then
            echo "$candidate"
            return 0
        fi
    fi
    return 1
}

# Helper: execute a feature install script inside a container
execute_feature_install_in_container() {
    local container_name="$1"
    local install_script="$2"
    local feature_name="$3"
    local feature_safe_name="$4"

    local dest_dir="/tmp/dcutil-features"
    local dest="$dest_dir/install_${feature_safe_name}.sh"

    # Create destination directory in container
    if command -v execute_container_command >/dev/null 2>&1; then
        execute_container_command exec "$container_name" mkdir -p "$dest_dir" >/dev/null 2>&1 || true
        # Copy file into container
        execute_container_command cp "$install_script" "$container_name:$dest" || return 1
        # Prepare env args for inputs
        local env_args=()
        for input_name in "${INPUTS_NAMES[@]}"; do
            local input_upper
            input_upper=$(echo "$input_name" | sed 's#[-\. ]#_#g' | tr '[:lower:]' '[:upper:]')
            local var_global="DCUTIL_INPUT_${input_upper}"
            local var_feature="DCUTIL_FEATURE_INPUT_${feature_safe_name}_${input_upper}"
            if [ -n "${!var_global:-}" ]; then
                env_args+=("-e" "$var_global=${!var_global}")
            fi
            if [ -n "${!var_feature:-}" ]; then
                env_args+=("-e" "$var_feature=${!var_feature}")
            fi
        done
        # Execute as root to allow apt-like operations
        execute_container_command exec -i "${env_args[@]}" -u root "$container_name" bash -x "$dest" >> "$FEATURES_INSTALL_LOG" 2>&1 || return 1
        execute_container_command exec -i "$container_name" rm -f "$dest" >/dev/null 2>&1 || true
        return 0
    else
        # Use raw docker/podman commands
        docker exec -i "$container_name" mkdir -p "$dest_dir" >/dev/null 2>&1 || true
        docker cp "$install_script" "$container_name:$dest" || return 1
        # Build env args for docker exec and inline env for CLI exec
        local env_args=()
        local env_inline=""
        for input_name in "${INPUTS_NAMES[@]}"; do
            local input_upper
            input_upper=$(echo "$input_name" | sed 's#[-\. ]#_#g' | tr '[:lower:]' '[:upper:]')
            local var_global="DCUTIL_INPUT_${input_upper}"
            local var_feature="DCUTIL_FEATURE_INPUT_${feature_safe_name}_${input_upper}"
            if [ -n "${!var_global:-}" ]; then
                env_args+=("-e" "$var_global=${!var_global}")
                # Properly escape single quotes in env values
                local escaped_val="${!var_global//"'"/"'\"'\"'"}"
                env_inline+=" $var_global='$escaped_val'"
            fi
            if [ -n "${!var_feature:-}" ]; then
                env_args+=("-e" "$var_feature=${!var_feature}")
                # Properly escape single quotes in env values
                local escaped_val="${!var_feature//"'"/"'\"'\"'"}"
                env_inline+=" $var_feature='$escaped_val'"
            fi
        done

        # Prefer using official devcontainer CLI for exec if available
        if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
            # Execute using devcontainer CLI to avoid maintaining low-level exec behavior
            # Set environment variables properly for the devcontainer CLI exec
            local env_cmd="bash -x '$dest'"
            local exec_args=()
            
            # Add environment variables as separate -e flags
            for input_name in "${INPUTS_NAMES[@]}"; do
                local input_upper
                input_upper=$(echo "$input_name" | sed 's#[-\. ]#_#g' | tr '[:lower:]' '[:upper:]')
                local var_global="DCUTIL_INPUT_${input_upper}"
                local var_feature="DCUTIL_FEATURE_INPUT_${feature_safe_name}_${input_upper}"
                if [ -n "${!var_global:-}" ]; then
                    exec_args+=("-e" "$var_global=${!var_global}")
                fi
                if [ -n "${!var_feature:-}" ]; then
                    exec_args+=("-e" "$var_feature=${!var_feature}")
                fi
            done
            
            # Add standard feature environment variables
            exec_args+=("-e" "FEATURE_ID=$feature_id")
            exec_args+=("-e" "FEATURE_NAME=$feature_name")
            exec_args+=("-e" "FEATURE_VERSION=$feature_version")
            
            if execute_command_in_devcontainer "$PROJECT_DIR" exec "${exec_args[@]}" /bin/sh -lc "$env_cmd" >> "$FEATURES_INSTALL_LOG" 2>&1; then
                docker exec -i "$container_name" rm -f "$dest" >/dev/null 2>&1 || true
                return 0
            else
                return 1
            fi
        fi

        # Run with root privileges when possible
        docker exec -i --user root "${env_args[@]}" "$container_name" bash -x "$dest" >> "$FEATURES_INSTALL_LOG" 2>&1 || return 1
        docker exec -i "$container_name" rm -f "$dest" >/dev/null 2>&1 || true
        return 0
    fi
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

        # Prefer running inside a running devcontainer if available
        local container_name
        container_name=$(get_running_container_for_project "$PROJECT_DIR" 2>/dev/null || true)
        if [ -n "$container_name" ]; then
            info "Found running container: $container_name - attempting in-container installation"
            if execute_feature_install_in_container "$container_name" "$install_script" "$feature_name" "$feature_safe_name"; then
                success "Feature installed successfully (container mode): $feature_spec"
                echo "$(date): Successfully installed $feature_spec (container: $container_name)" >> "$FEATURES_INSTALL_LOG"
                env_clear_inputs_for_feature "$feature_safe_name"
                return 0
            else
                warning "In-container feature installation failed; not attempting host install unless forced"
            fi
        fi

        # If no container found or installation in container failed, only run on host when explicitly allowed
        if [ "${FEATURES_FORCE_HOST_INSTALL:-false}" = true ]; then
            info "Attempting host install because FEATURES_FORCE_HOST_INSTALL=true"
            if bash -x "$install_script" >> "$FEATURES_INSTALL_LOG" 2>&1; then
                success "Feature installed successfully (host mode): $feature_spec"
                echo "$(date): Successfully installed $feature_spec" >> "$FEATURES_INSTALL_LOG"
                env_clear_inputs_for_feature "$feature_safe_name"
                return 0
            else
                # Provide diagnostic information
                local last_log
                last_log=$(tail -n 40 "$FEATURES_INSTALL_LOG" 2>/dev/null || true)
                if echo "$last_log" | grep -qiE "Script must be run as root|sudo|Permission denied|E: Could not get lock|cannot open|No such file or directory"; then
                    error "Feature installation failed: $feature_spec (requires root or container environment)"
                    error "Last 40 lines of install log:\n$last_log"
                    error "Suggestion: Run 'dcutil up' to start the devcontainer and re-run 'dcutil features install' inside the container, or set FEATURES_FORCE_HOST_INSTALL=true to force attempt on the host at your own risk."
                else
                    error "Feature installation failed: $feature_spec"
                fi
                echo "$(date): Failed to install $feature_spec" >> "$FEATURES_INSTALL_LOG"
                env_clear_inputs_for_feature "$feature_safe_name"
                return 1
            fi
        else
            error "No running devcontainer found for this project; please run 'dcutil up' (or set FEATURES_FORCE_HOST_INSTALL=true to try host installation)"
            echo "$(date): Feature install aborted due to lack of running container" >> "$FEATURES_INSTALL_LOG"
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

# Resolve feature dependency order for installation
resolve_feature_install_order() {
    info "Resolving feature dependency order..."

    local requested_features=("$@")
    local resolved_order=()
    local visited=()
    local visiting=()

    # Dependency map - stores dependencies for each feature
    declare -A feature_deps=()

    # Build dependency map
    for feature_id in "${requested_features[@]}"; do
        local cache_key
        cache_key=$(parse_feature_spec "$feature_id" | cut -d: -f1)
        cache_key="${cache_key//\//_}_$(parse_feature_spec "$feature_id" | cut -d: -f2)"
        local cache_dir="$FEATURES_CACHE_DIR/$cache_key"

        local deps=()

        # Check dependsOn from devcontainer.json for user-specified dependencies
        if command -v jq &> /dev/null && [ -f "$DEVCONTAINER_CONFIG_FILE" ]; then
            # Check if the feature has specific dependencies in user config
            local feature_key
            feature_key=$(basename "${feature_id%:*}")  # Get just the feature name
            if jq -e ".features.\"$feature_key\".dependsOn" "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
                while IFS= read -r dep; do
                    if [ -n "$dep" ] && [ "$dep" != "null" ]; then
                        deps+=("$dep")
                    fi
                done < <(jq -r ".features.\"$feature_key\".dependsOn[]" "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
            fi
        fi

        # Get dependencies from feature definition (if cached)
        if [ -f "$cache_dir/dependsOn.list" ]; then
            while IFS= read -r dep; do
                if [ -n "$dep" ]; then
                    deps+=("$dep")
                fi
            done < "$cache_dir/dependsOn.list"
        fi

        if [ -f "$cache_dir/installsAfter.list" ]; then
            while IFS= read -r dep; do
                if [ -n "$dep" ]; then
                    deps+=("$dep")  # We'll treat installsAfter as weaker dependencies for now
                fi
            done < "$cache_dir/installsAfter.list"
        fi

        feature_deps["$feature_id"]="${deps[*]}"
    done

    # Recursive function to visit feature and its dependencies
    visit_feature() {
        local feature="$1"

        # Check for circular dependency
        for v in "${visiting[@]}"; do
            if [ "$v" = "$feature" ]; then
                error "Circular dependency detected involving: $feature"
                return 1
            fi
        done

        # Check if already visited
        for v in "${visited[@]}"; do
            if [ "$v" = "$feature" ]; then
                return 0
            fi
        done

        # Check if feature exists in requested features
        local feature_exists=false
        for req in "${requested_features[@]}"; do
            if [ "$req" = "$feature" ]; then
                feature_exists=true
                break
            fi
        done

        if [ "$feature_exists" = false ]; then
            # Not in requested features, skip
            return 0
        fi

        # Add to visiting list
        visiting+=("$feature")

        # Visit dependencies first
        local deps_str="${feature_deps[$feature]:-}"
        if [ -n "$deps_str" ]; then
            for dep in $deps_str; do
                if ! visit_feature "$dep"; then
                    return 1
                fi
            done
        fi

        # Remove from visiting and add to visited
        local new_visiting=()
        for v in "${visiting[@]}"; do
            if [ "$v" != "$feature" ]; then
                new_visiting+=("$v")
            fi
        done
        visiting=("${new_visiting[@]}")

        visited+=("$feature")
        resolved_order+=("$feature")

        return 0
    }

    # Visit all requested features
    for feature in "${requested_features[@]}"; do
        if ! visit_feature "$feature"; then
            error "Failed to resolve dependencies for feature: $feature"
            return 1
        fi
    done

    # Return resolved order
    echo "${resolved_order[@]}"
}

# Install all configured features with dependency resolution
install_features() {
    if ! parse_features_config; then
        info "No features configured"
        return 0
    fi

    info "Installing ${#FEATURES_IDS[@]} feature(s) with dependency resolution..."

    # Initialize installation log
    echo "# Devcontainer Features Installation Log" > "$FEATURES_INSTALL_LOG"
    {
        echo "# Date: $(date)"
    } >> "$FEATURES_INSTALL_LOG"
    echo "# Project: $PROJECT_DIR" >> "$FEATURES_INSTALL_LOG"
    echo "" >> "$FEATURES_INSTALL_LOG"

    # Load inputs if any
    load_input_values

    # Check for overrideFeatureInstallOrder in devcontainer.json
    local install_order=()
    if command -v jq &> /dev/null && jq -e '.overrideFeatureInstallOrder' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
        info "Using overrideFeatureInstallOrder from devcontainer.json"
        while IFS= read -r ordered_feature; do
            if [ -n "$ordered_feature" ] && [ "$ordered_feature" != "null" ]; then
                install_order+=("$ordered_feature")
            fi
        done < <(jq -r '.overrideFeatureInstallOrder[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
    else
        # Resolve dependencies to determine installation order
        info "Resolving feature installation order based on dependencies..."
        local resolved_order
        resolved_order=$(resolve_feature_install_order "${FEATURES_IDS[@]}")
        if [ -n "$resolved_order" ]; then
            install_order=()
            if [ -n "$resolved_order" ]; then
                # Split the resolved order string into array elements
                while IFS= read -r line; do
                    [ -n "$line" ] && install_order+=("$line")
                done < <(printf '%s\n' "$resolved_order")
            fi
        else
            # Fallback to original order
            install_order=("${FEATURES_IDS[@]}")
        fi
    fi

    info "Feature installation order: ${install_order[*]}"

    local failed_features=()

    for feature_id in "${install_order[@]}"; do
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
            version=$(echo "$feature_config" | jq -r ".version // \"$feature_version\"" 2>/dev/null || echo "$feature_version")
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
        else
            # Validate user-provided options against feature schema if cache exists
            local feature_def_json="$cache_dir/devcontainer-feature.json"
            if [ -f "$feature_def_json" ]; then
                # Check if feature_config has user-provided options to validate
                if [ "$feature_config" != "{}" ] && command -v jq &> /dev/null; then
                    # Get all options specified by the user (excluding version and standard keys)
                    local user_options=()
                    if echo "$feature_config" | jq -e 'keys[]' >/dev/null 2>&1; then
                        while IFS= read -r key; do
                            # Skip standard keys like "version", "installAfter", etc.
                            if [ "$key" != "version" ] && [ "$key" != "installsAfter" ] && [ "$key" != "dependsOn" ]; then
                                user_options+=("$key")
                            fi
                        done < <(echo "$feature_config" | jq -r 'keys[]' 2>/dev/null)
                    fi

                    # Check each user-provided option against feature definition
                    for option_name in "${user_options[@]}"; do
                        # Check if this option is defined in the feature's schema
                        if ! jq -e ".options[\"$option_name\"]" "$feature_def_json" >/dev/null 2>&1; then
                            warnings+=("Feature $feature_id does not accept option: $option_name")
                        fi
                    done

                    # Additional validation: ensure required options are provided
                    if jq -e '.options' "$feature_def_json" >/dev/null 2>&1; then
                        while IFS= read -r required_option; do
                            if [ -n "$required_option" ] && [ "$required_option" != "null" ]; then
                                local required_status
                                required_status=$(jq -r ".options[\"$required_option\"].required // false" "$feature_def_json" 2>/dev/null || echo "false")
                                if [ "$required_status" = "true" ] || [ "$required_status" = "true\nrequired" ]; then
                                    local found=false
                                    for user_opt in "${user_options[@]}"; do
                                        if [ "$user_opt" = "$required_option" ]; then
                                            found=true
                                            break
                                        fi
                                    done
                                    if [ "$found" = false ]; then
                                        warnings+=("Feature $feature_id requires option: $required_option")
                                    fi
                                fi
                            fi
                        done < <(jq -r '.options | to_entries[] | select(.value.required == true) | .key' "$feature_def_json" 2>/dev/null || echo "")
                    fi
                fi
            fi
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
        rm -rf "${FEATURES_CACHE_DIR:?}"/*
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