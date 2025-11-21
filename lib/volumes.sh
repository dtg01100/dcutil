#!/bin/bash

# Volume management functionality for dcutil

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

get_volume_config_file() {
    echo "$PROJECT_DIR/.devcontainer/volumes.json"
}

ensure_volume_config() {
    local volume_file
    volume_file=$(get_volume_config_file)
    local volume_dir
    volume_dir=$(dirname "$volume_file")

    if [ ! -d "$volume_dir" ]; then
        mkdir -p "$volume_dir"
    fi

    if [ ! -f "$volume_file" ]; then
        echo '{"volumes": {}}' > "$volume_file"
    fi
}

list_volumes() {
    local volume_file
    volume_file=$(get_volume_config_file)
    ensure_volume_config

    info "Mounted volumes for this project:"
    echo ""

    if command -v jq &> /dev/null; then
        # Use jq for pretty output if available
        if jq -e '.volumes | length > 0' "$volume_file" >/dev/null 2>&1; then
            jq -r '.volumes | to_entries[] | "  \(.key) -> \(.value.host_path) (auto: \(.value.auto_mount))"' "$volume_file"
        else
            echo "  No volumes configured"
        fi
    else
        # Fallback to grep/sed for JSON parsing
        local volumes
        volumes=$(grep -o '"[^"]*":' "$volume_file" | grep -v 'volumes' | sed 's/"//g; s/:.*//')
        if [ -n "$volumes" ]; then
            echo "$volumes" | while read -r vol_name; do
                local host_path
                host_path=$(grep -A5 "\"$vol_name\"" "$volume_file" | grep "host_path" | sed 's/.*: "\(.*\)",.*/\1/')
                local auto_mount
                auto_mount=$(grep -A5 "\"$vol_name\"" "$volume_file" | grep "auto_mount" | sed 's/.*: \(.*\)/\1/')
                echo "  $vol_name -> $host_path (auto: ${auto_mount%,})"
            done
        else
            echo "  No volumes configured"
        fi
    fi
    echo ""
}

# Enhanced volume management with atomic operations
add_volume() {
    local volume_name="$1"
    local host_path="$2"
    local container_path="$3"
    local mount_type="${4:-bind}"

    if [ -z "$volume_name" ] || [ -z "$host_path" ] || [ -z "$container_path" ]; then
        error_exit "Usage: dcutil volumes add <name> <host_path> <container_path> [type]" "$EXIT_INVALID_ARGS"
    fi

    # Validate paths
    validate_safe_path "$host_path"
    validate_safe_path "$container_path"

    # Validate mount type
    if [[ ! " bind volume tmpfs " =~ $mount_type ]]; then
        error_exit "Invalid mount type: '$mount_type'. Use 'bind', 'volume', or 'tmpfs'." "$EXIT_INVALID_ARGS"
    fi

    # Expand tilde in paths safely
    host_path=$(safe_path "$host_path")
    container_path=$(safe_path "$container_path")

    # Validate host path
    case "$mount_type" in
        "bind")
            if [ ! -e "$host_path" ]; then
                warning "Host path '$host_path' does not exist. Creating directory..."
                if ! mkdir -p "$host_path" 2>/dev/null; then
                    error_exit "Failed to create host path '$host_path'" "$EXIT_PERMISSION_ERROR"
                fi
                success "Created directory: $host_path"
            fi
            ;;
        "volume")
            # Volume names should be valid
            if ! [[ "$volume_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
                error_exit "Invalid volume name: '$volume_name'. Use alphanumeric characters, dots, hyphens, and underscores only." "$EXIT_INVALID_ARGS"
            fi
            ;;
        "tmpfs")
            # tmpfs doesn't need host path validation
            ;;
    esac

    local volume_file
    volume_file=$(get_volume_config_file)
    ensure_volume_config

    # Check if volume already exists using jq
    if command -v jq &> /dev/null; then
        if jq -e ".volumes[\"$volume_name\"]" "$volume_file" >/dev/null 2>&1; then
            error_exit "Volume '$volume_name' already exists. Use 'dcutil volumes remove $volume_name' first." "$EXIT_CONFIG_ERROR"
        fi
    fi

    # Add volume to configuration atomically
    if command -v jq &> /dev/null; then
        local temp_file
        temp_file=$(mktemp "${volume_file}.XXXXXX")
        jq --arg name "$volume_name" \
           --arg host "$host_path" \
           --arg container "$container_path" \
           --arg type "$mount_type" \
           '.volumes[$name] = {
                "host_path": $host,
                "container_path": $container,
                "mount_type": $type,
                "auto_mount": true,
                "created": now|todateiso8601
              }' "$volume_file" > "$temp_file" && \
        mv "$temp_file" "$volume_file"
        rm -f "$temp_file"
    else
        # Fallback: manual JSON manipulation (less reliable)
        local temp_file="${volume_file}.tmp"
        cp "$volume_file" "$temp_file"

        # Insert new volume entry before the closing brace
        sed -i "/^    }$/i\\
    },\\
    \"$volume_name\": {\\
        \"host_path\": \"$host_path\",\\
        \"container_path\": \"$container_path\",\\
        \"mount_type\": \"$mount_type\",\\
        \"auto_mount\": true,\\
        \"created\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"\\
    }" "$temp_file"

        mv "$temp_file" "$volume_file"
    fi

    success "Added volume '$volume_name'"
    info "  Host path: $host_path"
    info "  Container path: $container_path"
    info "  Mount type: $mount_type"
    info "  Auto-mount: enabled"

    # Offer to mount immediately if container is running
    if devcontainer exec --workspace-folder . echo "running" 2>/dev/null >/dev/null; then
        echo ""
        read -r -p "Mount volume now? (y/N): " mount_now
        if [[ "$mount_now" =~ ^[Yy] ]]; then
            mount_volume "$volume_name"
        fi
    fi
}

remove_volume() {
    local volume_name="$1"

    if [ -z "$volume_name" ]; then
        error_exit "Usage: dcutil volumes remove <name>" "$EXIT_INVALID_ARGS"
    fi

    local volume_file
    volume_file=$(get_volume_config_file)
    ensure_volume_config

    # Check if volume exists
    local volume_exists=false
    if command -v jq &> /dev/null; then
        if jq -e ".volumes[\"$volume_name\"]" "$volume_file" >/dev/null 2>&1; then
            volume_exists=true
        fi
    else
        if grep -q "\"$volume_name\"" "$volume_file"; then
            volume_exists=true
        fi
    fi

    if [ "$volume_exists" = false ]; then
        error_exit "Volume '$volume_name' not found" "$EXIT_CONFIG_ERROR"
    fi

    # Confirm removal
    echo ""
    warning "This will remove volume configuration for '$volume_name'"
    read -r -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        info "Volume removal cancelled"
        return 0
    fi

    # Remove volume from configuration atomically
    if command -v jq &> /dev/null; then
        local temp_file
        temp_file=$(mktemp "${volume_file}.XXXXXX")
        jq --arg name "$volume_name" 'del(.volumes[$name])' "$volume_file" > "$temp_file" && \
        mv "$temp_file" "$volume_file"
        rm -f "$temp_file"
    else
        # Fallback: remove lines containing the volume name
        local temp_file="${volume_file}.tmp"
        sed "/\"$volume_name\": {/,/},/d" "$volume_file" > "$temp_file"
        # Handle last volume (no trailing comma)
        sed "s/    }/    }/; /\"$volume_name\": {/,/}/d" "$temp_file" > "$volume_file.tmp2" 2>/dev/null || cp "$temp_file" "$volume_file.tmp2"
        mv "$volume_file.tmp2" "$temp_file"
        mv "$temp_file" "$volume_file"
    fi

    success "Removed volume '$volume_name'"

    # Offer to unmount if mounted
    if devcontainer exec --workspace-folder . echo "running" 2>/dev/null >/dev/null; then
        echo ""
        read -r -p "Unmount volume from running container? (y/N): " unmount_now
        if [[ "$unmount_now" =~ ^[Yy] ]]; then
            unmount_volume "$volume_name"
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

    # Get volume configuration
    local host_path=""
    local container_path=""
    local mount_type=""

    if command -v jq &> /dev/null; then
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
        error_exit "Volume '$volume_name' not found" "$EXIT_CONFIG_ERROR"
    fi

    # Check if container is running
    if ! devcontainer exec --workspace-folder . echo "running" 2>/dev/null >/dev/null; then
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
                    if docker cp "$host_path/." "$CONTAINER_ID$container_path/" 2>/dev/null; then
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
                devcontainer down --workspace-folder "$PROJECT_DIR" 2>/dev/null || true
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
    if ! devcontainer exec --workspace-folder . echo "running" 2>/dev/null >/dev/null; then
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
        if docker exec "$CONTAINER_ID" umount "$container_path" 2>/dev/null; then
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
    if devcontainer exec --workspace-folder . echo "running" 2>/dev/null >/dev/null; then
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