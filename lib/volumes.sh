#!/usr/bin/env bash

# Volume management functionality for dcutil

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Constants for lock retry and delays
readonly LOCK_RETRY_DELAY=0.01      # 10ms between lock acquisition attempts
readonly LOCK_OPERATION_DELAY=0.02  # 20ms delay for file operations
readonly LOCK_WAIT_DELAY=0.05       # 50ms delay for waiting operations

# Lock management functions
open_lock() {
    local lockfile="$1"
    local exclusive="${2:-false}"

    if command -v flock &>/dev/null; then
        if [ "$exclusive" = true ]; then
            exec 100>"$lockfile" || return 1
            flock -x 100 || return 1
        else
            exec 100<"$lockfile" || return 1
            flock -s 100 || return 1
        fi
        echo "100"
        return 0
    fi
    return 1
}

close_lock() {
    local fd="$1"
    if command -v flock &>/dev/null && [ -n "$fd" ]; then
        flock -u "$fd" 2>/dev/null || true
        exec "$fd">&- 2>/dev/null || true
    fi
}



ensure_volume_config() {
    local volume_file
    volume_file=$(get_volume_config_file)
    info "Using volume config: $volume_file"
    info "DEVCONTAINER_CONFIG_FILE: ${DEVCONTAINER_CONFIG_FILE:-<unset>}"

    local dir
    dir=$(dirname "$volume_file")
    if [ ! -d "$dir" ]; then
        if ! mkdir -p "$dir" 2>/dev/null; then
            error_exit "Failed to create directory for volumes config: $dir" "$EXIT_PERMISSION_ERROR"
        fi
    fi

    local lockfile
    lockfile="${volume_file}.lock"

    if [ ! -f "$volume_file" ]; then
        echo '{"volumes": {}}' > "$volume_file"
        validate_json_if_available "$volume_file"
        success "Initialized volume config at $volume_file"
    fi

    return 0
}

get_volume_config_file() {
    local cfg="${DEVCONTAINER_CONFIG_FILE:-}"

    # Strip surrounding quotes if present
    cfg="${cfg#\"}"
    cfg="${cfg%\"}"

    if [ -n "$cfg" ]; then
        if [ -f "$cfg" ]; then
            echo "$cfg"
            return 0
        else
            cfg=$(realpath -m "$cfg" 2>/dev/null || echo "$cfg")
        fi

        local dir
        dir=$(dirname "$cfg")
        realpath -m "$dir/volumes.json" 2>/dev/null || echo "$dir/volumes.json"
        return 0
    fi

    if [ -n "${PROJECT_DIR:-}" ]; then
        realpath -m "$PROJECT_DIR/.devcontainer/volumes.json" 2>/dev/null || echo "$PROJECT_DIR/.devcontainer/volumes.json"
    else
        realpath -m ".devcontainer/volumes.json" 2>/dev/null || echo ".devcontainer/volumes.json"
    fi
}

add_volume() {
    local volume_name="$1"
    local host_path="$2"
    local container_path="$3"
    local mount_type="${4:-bind}"

    if [ -z "$volume_name" ] || [ -z "$host_path" ] || [ -z "$container_path" ]; then
        error_exit "💾 Usage: dcutil volumes add <name> <your_computer_path> <environment_path> [type]" "$EXIT_INVALID_ARGS"
    fi

    # Validate mount type
    case "$mount_type" in
        "bind"|"volume"|"tmpfs")
            ;;
        *)
            error_exit "Invalid mount type '$mount_type'. Must be one of: bind, volume, tmpfs" "$EXIT_INVALID_ARGS"
            ;;
    esac

    local volume_file
    volume_file=$(get_volume_config_file)
    ensure_volume_config

    local lockfile
    lockfile="${volume_file}.lock"

    # Check if volume already exists
    local volume_exists=false
    if command -v jq &>/dev/null; then
        if jq -e ".volumes[\"$volume_name\"]" "$volume_file" >/dev/null 2>&1; then
            volume_exists=true
        fi
    else
        if grep -q "\"$volume_name\"" "$volume_file"; then
            volume_exists=true
        fi
    fi

    if [ "$volume_exists" = true ]; then
        error_exit "Volume '$volume_name' already exists" "$EXIT_CONFIG_ERROR"
    fi

    # Validate host path exists (for bind mounts)
    if [ "$mount_type" = "bind" ]; then
        # Expand tilde
        host_path="${host_path/#\~/$HOME}"

        # Validate path for security
        validate_safe_path "$host_path"

        if [ ! -e "$host_path" ]; then
            if ! [ -t 0 ]; then
                # Non-interactive: create directory if it doesn't exist
                mkdir -p "$host_path" 2>/dev/null || true
            else
                if confirm_prompt "Host path '$host_path' does not exist. Create it? (y/N):"; then
                    mkdir -p "$host_path" || {
                        error_exit "Failed to create host path '$host_path'" "$EXIT_CONFIG_ERROR"
                    }
                else
                    close_lock "$fd"
                    info "Volume addition cancelled"
                    return 0
                fi
            fi
        fi

        # Convert to absolute path
        host_path=$(realpath "$host_path" 2>/dev/null || echo "$host_path")
    fi

    # Add volume to configuration atomically
    if command -v jq &> /dev/null; then
        local temp_file
        temp_file=$(mktemp "${volume_file}.XXXXXX")
        if ! jq --arg name "$volume_name" --arg host "$host_path" --arg container "$container_path" --arg type "$mount_type" \
            '.volumes[$name] = {"host_path": $host, "container_path": $container, "mount_type": $type, "auto_mount": false}' \
            "$volume_file" > "$temp_file"; then
            warning "Failed to update volume file using jq; printing current file for debugging"
            head -n 200 "$volume_file" 2>/dev/null || true
            rm -f "$temp_file" || true
            close_lock "$fd"
            error_exit "Failed to update volume config using jq" "$EXIT_CONFIG_ERROR"
        fi
        mv "$temp_file" "$volume_file"
    else
        error_exit "jq is required for volume management" "$EXIT_CONFIG_ERROR"
    fi

    close_lock "$fd"

    success "Added volume '$volume_name'"
    info "  On your computer: $host_path"
    info "  In your environment: $container_path"
    info "  Mount type: $mount_type"
    info "💡 Use 'dcutil volumes mount $volume_name' to make it available"
}

list_volumes() {
    local volume_file
    volume_file=$(get_volume_config_file)
    ensure_volume_config

    local lockfile
    lockfile="${volume_file}.lock"

    info "Shared storage for this project (config: $volume_file)"
    info "Volume file path: $volume_file"
    info "Lockfile: $lockfile"

    local attempts=0
    local max_attempts=40
    local found=false

    while [ $attempts -lt $max_attempts ]; do
        if command -v flock &>/dev/null; then
            exec 9<"$lockfile" || true
            flock -s 9 || true
        fi

        if [ -f "$volume_file" ]; then
            info "Volumes file size: $(stat -c%s "$volume_file") bytes"
        fi

        if command -v jq &> /dev/null; then
            # Ensure file is valid JSON
            local json_attempts=0
            while ! jq -e . "$volume_file" >/dev/null 2>&1 && [ $json_attempts -lt 5 ]; do
                sleep $LOCK_RETRY_DELAY
                json_attempts=$((json_attempts + 1))
            done

            if jq -e '.volumes | length > 0' "$volume_file" >/dev/null 2>&1; then
                jq -r '.volumes | keys[]' "$volume_file" | while read -r key; do
                    host=$(jq -r '.volumes["'"$key"'"].host_path' "$volume_file")
                    container=$(jq -r '.volumes["'"$key"'"].container_path' "$volume_file")
                    type=$(jq -r '.volumes["'"$key"'"].mount_type' "$volume_file")
                    auto=$(jq -r '.volumes["'"$key"'"].auto_mount' "$volume_file")
                    echo "  $key -> $host:$container (type: $type, auto: $auto)"
                done
                found=true
            fi
        fi

        # if command -v flock &>/dev/null; then
        #     close_lock "$fd"
        # fi

        if [ "$found" = true ]; then
            break
        fi

        attempts=$((attempts + 1))
        sleep $LOCK_OPERATION_DELAY
    done

    if [ "$found" = false ]; then
        echo "  No shared storage configured yet"
    fi
}

remove_volume() {
    local volume_name="$1"

    if [ -z "$volume_name" ]; then
        error_exit "💾 Usage: dcutil volumes remove <name>" "$EXIT_INVALID_ARGS"
    fi

    local volume_file
    volume_file=$(get_volume_config_file)
    ensure_volume_config

    local lockfile
    lockfile="${volume_file}.lock"

    # Acquire exclusive lock during removal
    local fd=""
    if command -v flock &>/dev/null; then
        fd=$(open_lock "$lockfile" true)
    fi

    # Check if volume exists
    local volume_exists=false
    if command -v jq &>/dev/null; then
        if jq -e ".volumes[\"$volume_name\"]" "$volume_file" >/dev/null 2>&1; then
            volume_exists=true
        fi
    else
        if grep -q "\"$volume_name\"" "$volume_file"; then
            volume_exists=true
        fi
    fi

    if [ "$volume_exists" = false ]; then
        # if command -v flock &>/dev/null; then
        #     close_lock "$fd"
        # fi
        error_exit "⚠️  Storage volume '$volume_name' not found. Use 'dcutil volumes list' to see available volumes." "$EXIT_CONFIG_ERROR"
    fi

    # Confirm removal
    echo ""
    warning "This will remove the shared storage configuration for '$volume_name'"
    local confirm=""
    if ! [ -t 0 ]; then
        # Non-interactive: assume confirmation
        confirm="y"
    else
        read -r -p "Are you sure? (y/N): " confirm
    fi
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        info "Volume removal cancelled"
        # if command -v flock &>/dev/null; then
        #     close_lock "$fd"
        # fi
        return 0
    fi

    # Remove volume from configuration atomically
    if command -v jq &> /dev/null; then
        local temp_file
        temp_file=$(mktemp "${volume_file}.XXXXXX")
        if ! jq --arg name "$volume_name" 'del(.volumes[$name])' "$volume_file" > "$temp_file"; then
            warning "Failed to update volume file using jq; printing current file for debugging"
            head -n 200 "$volume_file" 2>/dev/null || true
            rm -f "$temp_file" || true
            if command -v flock &>/dev/null; then
                close_lock 9
                exec 9>&- || true
            fi
            error_exit "Failed to update volume config using jq" "$EXIT_CONFIG_ERROR"
        fi
        mv "$temp_file" "$volume_file"
    else
        error_exit "jq is required for volume management" "$EXIT_CONFIG_ERROR"
    fi

    if command -v flock &>/dev/null; then
        close_lock 9
        exec 9>&- || true
    fi

    success "Removed volume '$volume_name'"

    # Offer to unmount if mounted
    if run_in_container "echo running" 2>/dev/null >/dev/null; then
        if ! [ -t 0 ]; then
            # Non-interactive: perform unmount automatically if container is running and the volume was removed
            unmount_volume "$volume_name" || true
        else
            echo ""
            read -r -p "Remove this storage from your running environment? (y/N): " unmount_now
            if [[ "$unmount_now" =~ ^[Yy] ]]; then
                unmount_volume "$volume_name"
            fi
        fi
    fi
}

mount_volume() {
    local volume_name="$1"

    if [ -z "$volume_name" ]; then
        error_exit "Usage: dcutil volumes mount <name>" "$EXIT_INVALID_ARGS"
    fi

    local volume_file
    volume_file=$(get_volume_config_file)
    ensure_volume_config

    local lockfile
    lockfile="${volume_file}.lock"

    # Acquire shared lock while reading configuration
    local fd=""
    if command -v flock &>/dev/null; then
        fd=$(open_lock "$lockfile" false)
    fi

    # Get volume configuration
    local host_path=""
    local container_path=""
    local mount_type=""

    if command -v jq &> /dev/null; then
        # Retry briefly if the file is being updated concurrently
        local attempts=0
        while ! jq -e . "$volume_file" >/dev/null 2>&1 && [ $attempts -lt 5 ]; do
            sleep $LOCK_WAIT_DELAY
            attempts=$((attempts + 1))
        done

        host_path=$(jq -r ".volumes[\"$volume_name\"].host_path" "$volume_file" 2>/dev/null)
        container_path=$(jq -r ".volumes[\"$volume_name\"].container_path" "$volume_file" 2>/dev/null)
        mount_type=$(jq -r ".volumes[\"$volume_name\"].mount_type" "$volume_file" 2>/dev/null)
    else
        # Fallback parsing
        host_path=$(grep -A5 "\"$volume_name\"" "$volume_file" | grep "host_path" | sed 's/.*: "\(.*\)",.*/\1/')
        container_path=$(grep -A5 "\"$volume_name\"" "$volume_file" | grep "container_path" | sed 's/.*: "\(.*\)",.*/\1/')
        mount_type=$(grep -A5 "\"$volume_name\"" "$volume_file" | grep "mount_type" | sed 's/.*: "\(.*\)",.*/\1/')
    fi

    # Validate volume exists
    if [ -z "$host_path" ] || [ "$host_path" = "null" ]; then
        # if command -v flock &>/dev/null; then
        #     close_lock "$fd"
        # fi
        error_exit "Volume '$volume_name' not found" "$EXIT_CONFIG_ERROR"
    fi

    # Release shared lock after reading configuration
    if command -v flock &>/dev/null; then
        close_lock 9
        exec 9>&- || true
    fi

    # Check if container is running
    if ! run_in_container "echo running" 2>/dev/null >/dev/null; then
        error_exit "Devcontainer is not running. Start it first with: dcutil up" "$EXIT_DEVCONTAINER_ERROR"
    fi

    # Get container ID
    CONTAINER_ID=$(docker ps --filter label=devcontainer.local_folder="$PROJECT_DIR" --format "{{.ID}}" 2>/dev/null | head -1)
    if [ -z "$CONTAINER_ID" ]; then
        error_exit "No running devcontainer found for $PROJECT_DIR" "$EXIT_DEVCONTAINER_ERROR"
    fi

    info "Volume '$volume_name' configuration:"
    info "  Host path: $host_path"
    info "  Container path: $container_path"
    info "  Mount type: $mount_type"
    
    # Add configuration sync documentation
    info "NOTE: For live configuration sync, add to devcontainer.json 'mounts' array:"
    echo ""
    echo "  \"mounts\": ["
    echo "    \"source=$host_path,target=$container_path,type=bind,consistency=cached\""
    echo "  ]"
    echo ""
    info "Current implementation copies files once, not continuously synced."

    # For bind mounts, copy data to demonstrate the concept
    case "$mount_type" in
        "bind")
            warning "Direct mount operations require privileged containers"
            warning "For production use, add volume mounts to .devcontainer/devcontainer.json:"
            echo ""
            info "Add to devcontainer.json 'mounts' array:"
            echo "  \"mounts\": ["
            echo "    \"source=$host_path,target=$container_path,type=bind,consistency=cached\""
            echo "  ]"
            echo ""

            # Offer to copy files as demonstration
            if [ -d "$host_path" ] && [ "$(find "$host_path" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)" -gt 0 ]; then
                echo ""
                read -r -p "Copy files from host to container as demonstration? (y/N): " copy_files
                if [[ "$copy_files" =~ ^[Yy] ]]; then
                    if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
                        if execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p "$container_path" 2>/dev/null &&
                           execute_command_in_devcontainer "$PROJECT_DIR" cp -rL "$host_path/." "$container_path/" 2>/dev/null; then
                            success "Files copied to container"
                            info "Note: This is a one-time copy, not a live bind mount"
                        else
                            warning "Failed to copy files to container"
                        fi
                    elif docker cp "$host_path/." "$CONTAINER_ID$container_path/" 2>/dev/null; then
                        success "Files copied to container"
                        info "Note: This is a one-time copy, not a live bind mount"
                    else
                        warning "Failed to copy files to container"
                    fi
                fi
            fi
            ;;
        "volume")
            warning "Volume mounts require container recreation"
            warning "Add to devcontainer.json 'mounts' array:"
            echo ""
            info "Add to devcontainer.json 'mounts' array:"
            echo "  \"mounts\": ["
            echo "    \"source=$volume_name,target=$container_path,type=volume\""
            echo "  ]"
            echo ""
            read -r -p "Recreate container with volume '$volume_name'? (y/N): " recreate
            if [[ "$recreate" =~ ^[Yy] ]]; then
                info "Recreating container with volume mount..."
                if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
                    execute_command_in_devcontainer "$PROJECT_DIR" down --workspace-folder "$PROJECT_DIR" 2>/dev/null || true
                else
                    devcontainer down --workspace-folder "$PROJECT_DIR" 2>/dev/null || true
                fi
                warning "Volume '$volume_name' will be available after container restart"
            fi
            ;;
        "tmpfs")
            warning "tmpfs mounts require privileged containers"
            warning "Add to devcontainer.json 'mounts' array:"
            echo ""
            info "Add to devcontainer.json 'mounts' array:"
            echo "  \"mounts\": ["
            echo "    \"target=$container_path,type=tmpfs\""
            echo "  ]"
            echo ""
            ;;
    esac

    success "Volume '$volume_name' configuration displayed"
    info "Use 'dcutil volumes status' to see current container mounts"
}

unmount_volume() {
    local volume_name="$1"

    if [ -z "$volume_name" ]; then
        error_exit "Usage: dcutil volumes unmount <name>" "$EXIT_INVALID_ARGS"
    fi

    # Check if container is running
    if ! run_in_container "echo running" 2>/dev/null >/dev/null; then
        error_exit "Devcontainer is not running" "$EXIT_DEVCONTAINER_ERROR"
    fi

    # Get container ID
    CONTAINER_ID=$(docker ps --filter label=devcontainer.local_folder="$PROJECT_DIR" --format "{{.ID}}" 2>/dev/null | head -1)
    if [ -z "$CONTAINER_ID" ]; then
        error_exit "No running devcontainer found for $PROJECT_DIR" "$EXIT_DEVCONTAINER_ERROR"
    fi

    info "Unmounting volume '$volume_name'..."

    # Get mount point (assume it's the same as container_path)
    local container_path=""
    local volume_file
    volume_file=$(get_volume_config_file)

    if command -v jq &> /dev/null; then
        container_path=$(jq -r ".volumes[\"$volume_name\"].container_path" "$volume_file" 2>/dev/null)
    else
        container_path=$(grep -A5 "\"$volume_name\"" "$volume_file" | grep "container_path" | sed 's/.*: "\(.*\)",.*/\1/')
    fi

    if [ -n "$container_path" ] && [ "$container_path" != "null" ]; then
        if command -v execute_command_in_devcontainer >/dev/null 2>&1; then
            if execute_command_in_devcontainer "$PROJECT_DIR" umount "$container_path" 2>/dev/null; then
                success "Volume '$volume_name' unmounted successfully"
            else
                warning "Volume '$volume_name' was not mounted or failed to unmount"
            fi
        elif docker exec "$CONTAINER_ID" umount "$container_path" 2>/dev/null; then
            success "Volume '$volume_name' unmounted successfully"
        else
            warning "Volume '$volume_name' was not mounted or failed to unmount"
        fi
    else
        warning "Could not determine container path for volume '$volume_name'"
    fi
}

volume_status() {
    local volume_file
    volume_file=$(get_volume_config_file)
    ensure_volume_config

    info "Volume status for project: $PROJECT_DIR"
    echo ""

    # Check if container is running
    if run_in_container "echo running" 2>/dev/null >/dev/null; then
        success "Container is running"

        # Get container ID
        CONTAINER_ID=$(docker ps --filter label=devcontainer.local_folder="$PROJECT_DIR" --format "{{.ID}}" 2>/dev/null | head -1)

        echo ""
        info "Container mounts:"
        docker inspect "$CONTAINER_ID" --format '{{ range .Mounts }}{{ if eq .Type "bind" }}{{ .Source }} -> {{ .Destination }} ({{ .Mode }}){{ println }}{{ end }}{{ end }}' 2>/dev/null || echo "  No bind mounts found"

        echo ""
        info "Configured volumes:"
        list_volumes

    else
        warning "Container is not running"
        echo ""
        info "Configured volumes:"
        list_volumes
    fi
}

backup_volume() {
    local volume_name="$1"
    local backup_path="$2"

    if [ -z "$volume_name" ]; then
        error_exit "Usage: dcutil volumes backup <name> [backup_path]" "$EXIT_INVALID_ARGS"
    fi

    local volume_file
    volume_file=$(get_volume_config_file)
    ensure_volume_config

    # Get volume configuration
    local host_path=""
    if command -v jq &> /dev/null; then
        host_path=$(jq -r ".volumes[\"$volume_name\"].host_path" "$volume_file" 2>/dev/null)
    else
        host_path=$(grep -A5 "\"$volume_name\"" "$volume_file" | grep "host_path" | sed 's/.*: "\(.*\)",.*/\1/')
    fi

    if [ -z "$host_path" ] || [ "$host_path" = "null" ]; then
        error_exit "Volume '$volume_name' not found" "$EXIT_CONFIG_ERROR"
    fi

    # Expand tilde in host path
    host_path="${host_path/#\~/$HOME}"

    if [ ! -d "$host_path" ]; then
        error_exit "Volume host path '$host_path' does not exist" "$EXIT_CONFIG_ERROR"
    fi

    # Determine backup path
    if [ -z "$backup_path" ]; then
        backup_path="./${volume_name}_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    fi

    info "Creating backup of volume '$volume_name'..."
    info "  Source: $host_path"
    info "  Backup: $backup_path"

    # Create backup directory if needed
    backup_dir=$(dirname "$backup_path")
    if [ ! -d "$backup_dir" ]; then
        mkdir -p "$backup_dir"
    fi

    # Create tar.gz backup
    if tar -czf "$backup_path" -C "$(dirname "$host_path")" "$(basename "$host_path")" 2>/dev/null; then
        success "Volume '$volume_name' backed up successfully"
        info "Backup size: $(du -h "$backup_path" | cut -f1)"
        info "Backup location: $backup_path"
    else
        error_exit "Failed to create backup of volume '$volume_name'" "$EXIT_CONFIG_ERROR"
    fi
}

restore_volume() {
    local volume_name="$1"
    local backup_path="$2"

    if [ -z "$volume_name" ] || [ -z "$backup_path" ]; then
        error_exit "Usage: dcutil volumes restore <name> <backup_path>" "$EXIT_INVALID_ARGS"
    fi

    local volume_file
    volume_file=$(get_volume_config_file)
    ensure_volume_config

    # Get volume configuration
    local host_path=""
    if command -v jq &> /dev/null; then
        host_path=$(jq -r ".volumes[\"$volume_name\"].host_path" "$volume_file" 2>/dev/null)
    else
        host_path=$(grep -A5 "\"$volume_name\"" "$volume_file" | grep "host_path" | sed 's/.*: "\(.*\)",.*/\1/')
    fi

    if [ -z "$host_path" ] || [ "$host_path" = "null" ]; then
        error_exit "Volume '$volume_name' not found" "$EXIT_CONFIG_ERROR"
    fi

    # Expand tilde in paths
    host_path="${host_path/#\~/$HOME}"
    backup_path="${backup_path/#\~/$HOME}"

    if [ ! -f "$backup_path" ]; then
        error_exit "Backup file '$backup_path' not found" "$EXIT_CONFIG_ERROR"
    fi

    info "Restoring volume '$volume_name' from backup..."
    info "  Volume: $host_path"
    info "  Backup: $backup_path"

    # Confirm restoration
    echo ""
    warning "This will overwrite the current volume contents"
    read -r -p "Continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        info "Volume restoration cancelled"
        return 0
    fi

    # Create backup of current data
    if [ -d "$host_path" ]; then
        local current_backup
        current_backup="./${volume_name}_pre_restore_$(date +%Y%m%d_%H%M%S).tar.gz"
        info "Creating backup of current data..."
        if tar -czf "$current_backup" -C "$(dirname "$host_path")" "$(basename "$host_path")" 2>/dev/null; then
            info "Current data backed up to: $current_backup"
        else
            warning "Failed to backup current data (continuing anyway)"
        fi
    fi

    # Remove existing volume directory
    if [ -d "$host_path" ]; then
        rm -rf "$host_path"
    fi

    # Create parent directory
    mkdir -p "$(dirname "$host_path")"

    # Extract backup
    if tar -xzf "$backup_path" -C "$(dirname "$host_path")" 2>/dev/null; then
        success "Volume '$volume_name' restored successfully"
        info "Restored to: $host_path"

        # Set proper permissions
        if command -v chown &> /dev/null; then
            chown -R "$(id -u):$(id -g)" "$host_path" 2>/dev/null || true
        fi
    else
        error_exit "Failed to restore volume '$volume_name' from backup" "$EXIT_CONFIG_ERROR"
    fi
}