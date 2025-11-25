#!/usr/bin/env bash

# Initialization functionality for dcutil

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Fetch available devcontainer templates from GitHub
fetch_available_templates() {
    local cache_file="$HOME/.cache/dcutil/templates.json"
    local cache_age=86400  # 24 hours

    # Check if cache exists and is recent
    if [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0))) -lt $cache_age ]; then
        cat "$cache_file" 2>/dev/null || echo "[]"
        return
    fi

    # Create cache directory
    mkdir -p "$(dirname "$cache_file")" 2>/dev/null || true

    # Fetch templates from GitHub API
    if command -v curl >/dev/null 2>&1; then
        local templates
        templates=$(curl -s --max-time 10 "https://api.github.com/repos/devcontainers/templates/contents/src" 2>/dev/null || echo "[]")

        # Cache the result
        echo "$templates" > "$cache_file" 2>/dev/null || true

        echo "$templates"
    else
        echo "[]"
    fi
}

# Fetch available devcontainer features from GitHub
fetch_available_features() {
    local cache_file="$HOME/.cache/dcutil/features.json"
    local cache_age=86400  # 24 hours

    # Check if cache exists and is recent
    if [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0))) -lt $cache_age ]; then
        cat "$cache_file" 2>/dev/null || echo "[]"
        return
    fi

    # Create cache directory
    mkdir -p "$(dirname "$cache_file")" 2>/dev/null || true

    # Fetch features from GitHub API
    if command -v curl >/dev/null 2>&1; then
        local features
        features=$(curl -s --max-time 10 "https://api.github.com/repos/devcontainers/features/contents/src" 2>/dev/null || echo "[]")

        # Cache the result
        echo "$features" > "$cache_file" 2>/dev/null || true

        echo "$features"
    else
        echo "[]"
    fi
}

# Display available templates and let user choose
choose_template() {
    local templates_json="$1"

    info "choose_template called with JSON length: ${#templates_json}"

    if ! command -v jq >/dev/null 2>&1; then
        warning "jq not available, using basic template selection"
        echo "basic"
        return
    fi

    # Parse template names
    local template_names
    if ! template_names=$(echo "$templates_json" | jq -r '.[].name' 2>/dev/null); then
        warning "Template parsing failed, using basic template"
        echo "basic"
        return
    fi
    
    # Check if we got any template names
    if [ -z "$template_names" ]; then
        warning "No templates found, using basic template"
        echo "basic"
        return
    fi
    
    info "Parsed template names: '$template_names'"

    echo -e "${YELLOW}📋 Available Devcontainer Templates:${NC}" >&2
    echo "" >&2

    local i=1
    local template_array=()
    while IFS= read -r template; do
        if [ -n "$template" ]; then
            template_array+=("$template")
            echo "$i) $template" >&2
            i=$((i + 1))
        fi
    done <<< "$template_names"

    echo "" >&2
    echo "0) Custom (specify your own image)" >&2
    echo "" >&2

    local choice
    read -r -p "Choose template [1-$((i-1)), 0 for custom]: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -le $((i-1)) ]; then
        if [ "$choice" -eq 0 ]; then
            echo "custom"
        else
            echo "${template_array[$((choice-1))]}"
        fi
    else
        warning "Invalid choice, using basic template"
        echo "basic"
    fi
}

# Display available features and let user choose
choose_features() {
    local features_json="$1"

    if ! command -v jq >/dev/null 2>&1; then
        warning "jq not available, skipping feature selection"
        echo "[]"
        return
    fi

    # Parse feature names
    local feature_names
    feature_names=$(echo "$features_json" | jq -r '.[].name' 2>/dev/null || echo "")

    if [ -z "$feature_names" ]; then
        warning "Could not fetch features, skipping feature selection"
        echo "[]"
        return
    fi

    echo -e "${YELLOW}🔧 Available Devcontainer Features:${NC}" >&2
    echo "Features add tools and runtimes to your container." >&2
    echo "" >&2

    local i=1
    local feature_array=()
    while IFS= read -r feature; do
        if [ -n "$feature" ]; then
            feature_array+=("$feature")
            echo "$i) $feature" >&2
            i=$((i + 1))
        fi
    done <<< "$feature_names"

    echo "" >&2
    echo "0) No additional features" >&2
    echo "" >&2

    local selected_features=""
    while true; do
        read -r -p "Choose features (comma-separated numbers, or 0 for none): " choices
        if [ "$choices" = "0" ] || [ -z "$choices" ]; then
            selected_features=""
            break
        fi

        # Parse comma-separated choices
        local valid=true
        local feature_list=""
        IFS=',' read -ra choice_array <<< "$choices"
        for choice in "${choice_array[@]}"; do
            choice=$(echo "$choice" | xargs)  # trim whitespace
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
                if [ -n "$feature_list" ]; then
                    feature_list="$feature_list ${feature_array[$((choice-1))]}"
                else
                    feature_list="${feature_array[$((choice-1))]}"
                fi
            else
                echo "Invalid choice: $choice. Please enter numbers between 1 and $((i-1))."
                valid=false
                break
            fi
        done

        if [ "$valid" = true ]; then
            selected_features="$feature_list"
            break
        fi
    done

    # Return space-separated list (will be converted to JSON later)
    echo "$selected_features"
}

# Wrapper for dialog to ensure stderr goes to /dev/tty if available
safe_dialog() {
    local output rc

    # Prefer --stdout to capture selection output reliably
    if [ -c /dev/tty ] && [ -w /dev/tty ]; then
        output=$(dialog --stdout "$@" 2>/dev/tty)
        rc=$?
    else
        output=$(dialog --stdout "$@" 2>/dev/null)
        rc=$?
    fi

    printf "%s" "$output"
    return $rc
}

# Try to obtain the dialog maxsize (rows and cols) without displaying UI
dialog_maxsize() {
    local out sizes
    out=$(safe_dialog --print-maxsize 2>/dev/null || echo "")

    # Strip ANSI escape sequences and try to parse numbers like "MaxSize: 24, 80"
    sizes=$(printf "%s" "$out" | sed -n 's/[^0-9,]*\([0-9]\+\), *\([0-9]\+\).*/\1 \2/p')
    if [ -n "$sizes" ]; then
        echo "$sizes"
        return 0
    fi
    return 1
}

# Compute dialog sizes based on terminal dimensions
compute_dialog_dims() {
    local default_h="$1" default_w="$2" default_list="$3"
    local min_lines=10 min_cols=40
    local lines cols

    # Prefer dialog's own idea of the screen size to ensure compatibility
    if dialog_maxsize >/dev/null 2>&1; then
        read -r lines cols <<< "$(dialog_maxsize)"
        # Validate that we got numeric values
        if ! [[ "$lines" =~ ^[0-9]+$ ]] || ! [[ "$cols" =~ ^[0-9]+$ ]]; then
            lines=$(tput lines 2>/dev/null || echo 24)
            cols=$(tput cols 2>/dev/null || echo 80)
        fi
    else
        lines=$(tput lines 2>/dev/null || echo 24)
        cols=$(tput cols 2>/dev/null || echo 80)
    fi

    # Ensure we have valid numbers for arithmetic
    if ! [[ "$lines" =~ ^[0-9]+$ ]] || ! [[ "$cols" =~ ^[0-9]+$ ]]; then
        echo "0 0 0"
        return 0
    fi

    if [ "$lines" -lt "$min_lines" ] || [ "$cols" -lt "$min_cols" ]; then
        echo "0 0 0"
        return 0
    fi

    local max_h=$((lines - 4))
    if [ "$max_h" -lt 8 ]; then
        max_h=8
    fi

    local h="$default_h"
    if [ "$h" -gt "$max_h" ]; then
        h="$max_h"
    fi

    local max_w=$((cols - 4))
    if [ "$max_w" -lt 30 ]; then
        max_w=30
    fi

    local w="$default_w"
    if [ "$w" -gt "$max_w" ]; then
        w="$max_w"
    fi

    local list_h="$default_list"
    local max_list_h=$((h - 4))
    if [ "$list_h" -gt "$max_list_h" ]; then
        list_h="$max_list_h"
    fi

    if [ "$h" -lt 6 ] || [ "$w" -lt 30 ]; then
        echo "0 0 0"
        return 0
    fi

    echo "$h $w $list_h"
    return 0
}

# Verify that dialog shows a UI and user can interact with it
verify_dialog() {
    # Use --print-maxsize to silently verify dialog can display unless forced
    if safe_dialog --print-maxsize >/dev/null 2>&1; then
        return 0
    fi

    # If print-maxsize fails and dialog has been forced, fallback to visual infobox then yesno
    if [ "${DCUTIL_FORCE_DIALOG:-0}" = "1" ]; then
        # Direct dialog usage without redirection
        (dialog --title "Dialog Test" --infobox "Testing dialog - you should briefly see a dialog box (this is a test)" 3 60) &
        sleep 1
        dialog --title "Dialog Test" --yesno "Did you see the dialog box?" 6 60
        return $?
    fi

    return 1
}

# Check if dialog is available for enhanced UI
has_dialog() {
    # Allow forcing dialog usage for debugging
    if [ "${DCUTIL_FORCE_DIALOG:-0}" = "1" ]; then
        if command -v dialog >/dev/null 2>&1; then
            return 0
        fi
    fi

    # Basic binary check
    if ! command -v dialog >/dev/null 2>&1; then
        return 1
    fi

    # Ensure we are attached to a terminal and TERM is sane
    if ! [ -t 0 ] || ! [ -t 1 ] || [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
        return 1
    fi

    # Ensure we have a writable controlling tty available
    if ! [ -c /dev/tty ] || ! [ -w /dev/tty ]; then
        return 1
    fi

    # Ensure the terminal is large enough for dialog widgets
    local lines cols
    lines=$(tput lines 2>/dev/null || echo 24)
    cols=$(tput cols 2>/dev/null || echo 80)
    if [ "$lines" -lt 10 ] || [ "$cols" -lt 40 ]; then
        return 1
    fi

    # Test dialog with a non-displaying command
    if dialog --print-maxsize >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# Enhanced wizard with dialog interface
wizard_with_dialog() {
    local templates_json="$1"
    local features_json="$2"

    # Initialize variables
    local selected_features=""

    # Template selection - dynamic from API
    local template_args=()
    local template_names=()
    local i=1

    if command -v jq >/dev/null 2>&1; then
        while IFS= read -r template; do
            if [ -n "$template" ]; then
                template_args+=("$i" "$template")
                template_names+=("$template")
                i=$((i + 1))
            fi
        done <<< "$(echo "$templates_json" | jq -r '.[].name' 2>/dev/null)"
    fi

    template_args+=("$i" "custom")
    local selected_template_num
    # Compute dims for menu
    read -r m_h m_w m_list <<< "$(compute_dialog_dims 30 80 20)"
    if [ "$m_h" -eq 0 ]; then
        # Terminal too small for dialog menu
        return 2
    fi

    selected_template_num=$(safe_dialog --title "Devcontainer Template Selection" \
        --menu "Choose a devcontainer template:" "$m_h" "$m_w" "$m_list" \
        "${template_args[@]}" 2>/dev/null)
    local dialog_exit=$?

    if [ $dialog_exit -eq 1 ] || [ $dialog_exit -eq 255 ]; then
        # User cancelled or pressed ESC
        return 1
    elif [ $dialog_exit -ne 0 ]; then
        # Error - could be dialog failure, terminal issues, etc.
        error "Dialog failed with exit code: $dialog_exit"
        return 2
    fi
    
    # Validate that we got a selection
    if [ -z "$selected_template_num" ]; then
        error "No template selection received"
        return 2
    fi

    local selected_template=""
    if [ "$selected_template_num" = "$i" ]; then
        selected_template="custom"
    elif [ -n "$selected_template_num" ] && [[ "$selected_template_num" =~ ^[0-9]+$ ]] && [ "$selected_template_num" -gt 0 ] && [ "$selected_template_num" -le $((i-1)) ]; then
        # Convert template_names array to get the selected one
        if [ ${#template_names[@]} -gt 0 ] && [ $((selected_template_num-1)) -lt ${#template_names[@]} ]; then
            selected_template="${template_names[$((selected_template_num-1))]}"
        fi
    fi
    info "Selected template: $selected_template"

    # Feature selection
    local feature_list=""
    i=1

    if command -v jq >/dev/null 2>&1; then
        while IFS= read -r feature; do
            if [ -n "$feature" ] && [ $i -le 15 ]; then  # Limit to 15 features for dialog
                feature_list="$feature_list $i $feature off"
                i=$((i + 1))
            fi
        done <<< "$(echo "$features_json" | jq -r '.[].name' 2>/dev/null | head -15)"
    fi

    if [ -n "$feature_list" ]; then
        local f_h f_w f_list
        read -r f_h f_w f_list <<< "$(compute_dialog_dims 20 70 10)"
        if [ "$f_h" -eq 0 ]; then
            # Terminal too small for dialog checklist -> fallback
            return 2
        fi

        local selected_feature_nums
        selected_feature_nums=$(safe_dialog --title "Devcontainer Features" \
            --checklist "Select additional features to install:" "$f_h" "$f_w" "$f_list" $feature_list)
        dialog_exit=$?

        if [ $dialog_exit -eq 1 ] || [ $dialog_exit -eq 255 ]; then
            # User cancelled
            return 1
        elif [ $dialog_exit -ne 0 ]; then
            # Error
            return 2
        fi

        # Convert selected feature numbers to feature names
        local feature_names=""
        if command -v jq >/dev/null 2>&1; then
            feature_names=$(echo "$features_json" | jq -r '.[].name' 2>/dev/null | head -15)
        fi

        selected_features=""
        for num in $selected_feature_nums; do
            if [ "$num" -gt 0 ] && [ "$num" -le 15 ]; then
                local feature_name
                feature_name=$(echo "$feature_names" | sed -n "${num}p")
                if [ -n "$feature_name" ]; then
                    selected_features="$selected_features $feature_name"
                fi
            fi
        done
        selected_features="${selected_features/# /}"  # Trim leading space
    fi

    # Container name (auto-generate from project directory)
    local container_name
    local project_basename
    project_basename=$(basename "$PROJECT_DIR" 2>/dev/null || echo "project")
    local default_name="dcutil-$project_basename"
    
    # Compute dims for inputboxes
    local n_h n_w
    read -r n_h n_w n_list <<< "$(compute_dialog_dims 8 40 0)"
    if [ "$n_h" -eq 0 ]; then
        # Terminal too small for dialog inputbox -> fallback
        return 2
    fi

    container_name=$(safe_dialog --title "Container Configuration" \
        --inputbox "Container name:" "$n_h" "$n_w" "$default_name")

    # Workspace folder
    local workspace_folder
    workspace_folder=$(safe_dialog --title "Container Configuration" \
        --inputbox "Workspace folder inside container:" "$n_h" "$n_w" "/workspaces")

    # Container user
    local container_user
    local d_h d_w
    read -r d_h d_w d_list <<< "$(compute_dialog_dims 8 40 0)"
    if [ "$d_h" -eq 0 ]; then
        # Terminal too small for dialog inputbox -> fallback
        return 2
    fi

    container_user=$(safe_dialog --title "Container Configuration" \
        --inputbox "Container user (name or UID[:GID]:" "$d_h" "$d_w" "vscode")

    # Mount options
    local m_h m_w
    read -r m_h m_w m_list <<< "$(compute_dialog_dims 6 50 0)"
    if [ "$m_h" -eq 0 ]; then
        # Terminal too small for dialog yesno -> fallback
        return 2
    fi

    safe_dialog --title "Mount Options" \
        --yesno "Map host project directory to container workspace?" "$m_h" "$m_w"
    mount_choice=$?

    # Chown options
    safe_dialog --title "Permissions" \
        --yesno "Set ownership of workspace to container user?" "$m_h" "$m_w"
    chown_choice=$?

    # Clear dialog artifacts
    clear

    # Set global variables for the caller
    SELECTED_TEMPLATE="$selected_template"
    SELECTED_FEATURES="$selected_features"
    CONTAINER_NAME="$container_name"
    WORKSPACE_FOLDER="$workspace_folder"
    CONTAINER_USER="$container_user"
    MOUNT_CHOICE=$mount_choice
    CHOWN_CHOICE=$chown_choice

    return 0
}

# Parse init options
init_mode() {
    local INIT_MODE="${1:-wizard}"
    validate_init_mode "$INIT_MODE"

    case "$INIT_MODE" in
        "--fast"|"fast")
            info "Creating fast devcontainer configuration..."

            # Create .devcontainer directory
            if ! mkdir -p .devcontainer 2>/dev/null; then
                error_exit "Failed to create .devcontainer directory" "$EXIT_PERMISSION_ERROR"
            fi

            # Fast mode defaults (non-interactive)
            repo_name="$(basename "$PROJECT_DIR")"
            workspace_folder="/workspaces/$repo_name"
            container_user="vscode"
            remote_user="$container_user"
            set_chown=true
            mount_project_to_container=true
            
            # Check if the base image already includes workspace mounting features
            # The base:ubuntu image includes common-utils and git features that handle mounting
            base_image="mcr.microsoft.com/devcontainers/base:ubuntu"
            mounts_snippet=""
            
            # Only add explicit mounts if not using base images with built-in workspace mounting
            if [ "$mount_project_to_container" = true ] && [[ "$base_image" != *"base:"* ]]; then
                mounts_snippet="\"mounts\": [\"source=$PROJECT_DIR,target=$workspace_folder,type=bind,consistency=cached\"],"
            fi

            if [ "$set_chown" = true ]; then
                chown_snippet="; if id -u $container_user >/dev/null 2>&1; then if command -v sudo >/dev/null; then sudo chown -R $container_user:$container_user $workspace_folder || true; else chown -R $container_user:$container_user $workspace_folder || true; fi; else echo 'User $container_user not found in image, skipping chown'; fi"
            else
                chown_snippet=""
            fi

# Create basic devcontainer.json
            if ! cat > .devcontainer/devcontainer.json << EOF
{
    "name": "Basic Dev Container",
    "image": "$base_image",
    
    "workspaceFolder": "$workspace_folder",
    "remoteUser": "$remote_user",
    "containerUser": "$container_user",
    "customizations": {
        "vscode": {
            "extensions": [
                "ms-vscode.vscode-json",
                "ms-vscode.vscode-git"
            ]
        }
    },
    "postCreateCommand": "apt-get update && apt-get install -y --no-install-recommends curl git && mkdir -p $workspace_folder"
}
EOF
            then
                error_exit "Failed to create devcontainer.json file" "$EXIT_PERMISSION_ERROR"
            fi

            validate_json_if_available ".devcontainer/devcontainer.json"

            success "Fast devcontainer configuration created"

            # Offer to start the container immediately
            if [ -t 0 ] && [ -t 1 ]; then
                echo ""
                read -r -p "Would you like to start the devcontainer now? (Y/n): " start_now
                start_now=${start_now:-Y}
                if [[ "$start_now" =~ ^[Yy] ]]; then
                    info "Starting devcontainer..."
                    # Call the up command
                    if command -v devcontainer_up >/dev/null 2>&1; then
                        devcontainer_up
                        return 0
                    fi
                fi
            fi

            info "Run 'dcutil up' to start the container"
            ;;
        "--wizard"|"wizard"|"")
    # Check if running interactively
    if ! [ -t 0 ] || ! [ -t 1 ]; then
        warning "Non-interactive environment detected. Use 'dcutil init fast' for automated setup."
        exit "$EXIT_INVALID_ARGS"
    fi
    
    # Check if terminal and dialog are available
    if ! command -v dialog >/dev/null 2>&1; then
        warning "dialog command not found. Using text-based interface."
    fi

    # Get available templates and features
    local templates_json
    templates_json=$(fetch_available_templates)

    local features_json
    features_json=$(fetch_available_features)

# Use dialog interface if available, otherwise fallback to text
             wizard_with_dialog_failed=false
             if has_dialog; then
                info "Devcontainer Initialization Wizard (Enhanced UI)"
                echo ""

                # Get all config via dialog
                local wizard_result
                wizard_with_dialog "$templates_json" "$features_json"
                wizard_result=$?
                
                case $wizard_result in
                    0)
                        # Success
                        ;;
                    1)
                        # User cancelled
                        info "Wizard cancelled by user"
                        exit 0
                        ;;
                    2)
                        # Error occurred
                        error "Wizard encountered an error. Falling back to text interface."
                        # Fall through to text interface
                        ;;
                    *)
                        # Unknown error
                        error "Wizard failed with unexpected error code: $wizard_result"
                        exit $wizard_result
                        ;;
                esac
                
                # Only proceed with dialog results if wizard succeeded
                if [ $wizard_result -eq 0 ]; then
                    # Extract results from global variables
                    selected_template="$SELECTED_TEMPLATE"
                    selected_features="$SELECTED_FEATURES"
                    container_name="$CONTAINER_NAME"
                    workspace_folder="$WORKSPACE_FOLDER"
                    container_user_input="$CONTAINER_USER"
                    mount_choice=$MOUNT_CHOICE
                    chown_choice=$CHOWN_CHOICE
                else
                    # Fall back to text interface
                    info "Switching to text-based interface"
                    wizard_with_dialog_failed=true
                fi

                # Extract results from global variables
                selected_template="$SELECTED_TEMPLATE"
                selected_features="$SELECTED_FEATURES"
                container_name="$CONTAINER_NAME"
                workspace_folder="$WORKSPACE_FOLDER"
                container_user_input="$CONTAINER_USER"
                mount_choice=$MOUNT_CHOICE
                chown_choice=$CHOWN_CHOICE

                # Convert selected features to JSON array
                if [ -n "$selected_features" ]; then
                    selected_features_json=$(echo "$selected_features" | tr ' ' '\n' | jq -R . | jq -s .)
                else
                    selected_features_json="[]"
                fi

                # Convert dialog results to expected format
                case $mount_choice in
                    0) mount_choice="Y" ;;
                    *) mount_choice="n" ;;
                esac

                case $chown_choice in
                    0) chown_choice="Y" ;;
                    *) chown_choice="n" ;;
                esac

                # Convert selected features to JSON array
                if [ -n "$selected_features" ]; then
                    selected_features_json=$(echo "$selected_features" | tr ' ' '\n' | jq -R . | jq -s .)
                else
                    selected_features_json="[]"
                fi

                 # Set defaults
                 container_user_input=${container_user_input:-vscode}

                # Validate workspace folder
                if [ -n "$workspace_folder" ]; then
                    validate_workspace_folder "$workspace_folder" || workspace_folder="/workspaces"
                else
                    workspace_folder="/workspaces"
                fi
            else
                info "Devcontainer Initialization Wizard"
                echo ""

                # Get available templates and let user choose
                local selected_template
                selected_template=$(choose_template "$templates_json")

                # Get available features and let user choose
                local selected_features_json
                selected_features_json=$(choose_features "$features_json")

                 # Get remaining config via text prompts
                 # Get container name
                 read -r -p "Container name [My Project]: " container_name
                 container_name=${container_name:-"My Project"}

                 # Prompt for workspace folder (validate)
                 while true; do
                     read -r -p "Workspace folder inside container [/workspaces]: " workspace_folder
                     workspace_folder=${workspace_folder:-/workspaces}
                     validate_workspace_folder "$workspace_folder"
                     case $? in
                         0) break;;
                         1) echo "Invalid input: workspace folder cannot be empty";;
                         2) echo "Workspace folder must be an absolute path (start with /)";;
                         3) echo "'/' is not allowed as a workspace folder. Choose a subdirectory like /workspaces/project";;
                         4) echo "Workspace folder must not have leading or trailing whitespace";;
                         *) echo "Invalid workspace folder";;
                     esac
                 done

                 # Prompt for container user (supports name or numeric UID[:GID])
                 read -r -p "Container user (name or UID[:GID]) [vscode]: " container_user_input
                 container_user_input=${container_user_input:-vscode}

                 # Ask whether to set ownership of the workspace
                 read -r -p "Set ownership of $workspace_folder to ${container_user_input}? (Y/n): " chown_choice
                 chown_choice=${chown_choice:-Y}

                 # Ask whether to mount host project dir into container workspace
                 read -r -p "Map host project directory ($PROJECT_DIR) to container workspace folder as bind mount? (Y/n): " mount_choice
                 mount_choice=${mount_choice:-Y}

                # Ask whether to set ownership of the workspace
                read -r -p "Set ownership of $workspace_folder to ${container_user_input}? (Y/n): " chown_choice
                chown_choice=${chown_choice:-Y}

                # Ask whether to mount host project dir into container workspace
                read -r -p "Map host project directory ($PROJECT_DIR) to container workspace folder as bind mount? (Y/n): " mount_choice
                mount_choice=${mount_choice:-Y}
             fi

             # selected_template is used directly in the dialog path

            container_user_is_numeric=false
            container_uid=""
            container_gid=""
            if [[ "$container_user_input" =~ ^[0-9]+(:[0-9]+)?$ ]]; then
                container_user_is_numeric=true
                container_uid="${container_user_input%%:*}"
                container_gid="${container_user_input##*:}"
                if [[ "$container_gid" == "$container_uid" ]]; then
                    container_gid="$container_uid"
                fi
                container_user="$container_uid"
                remote_user="$container_uid"
            else
                container_user="$container_user_input"
                remote_user="$container_user"
            fi

             # Set variables based on dialog choices or defaults
             set_chown=false
             if [[ "$chown_choice" =~ ^[Yy] ]]; then
                 set_chown=true
             fi

             mount_project_to_container=false
             mounts_snippet=""
             if [[ "$mount_choice" =~ ^[Yy] ]]; then
                 mount_project_to_container=true
                 mounts_snippet="\"mounts\": [\"source=$PROJECT_DIR,target=$workspace_folder,type=bind,consistency=cached\"],"
             fi

            # Default chown snippet based on numeric/user input
            chown_snippet=""
            if [ "$set_chown" = true ]; then
                if [ "$container_user_is_numeric" = true ]; then
                    chown_snippet="; if command -v sudo >/dev/null; then sudo chown -R ${container_uid}:${container_gid} $workspace_folder || true; else chown -R ${container_uid}:${container_gid} $workspace_folder || true; fi"
                else
                    guarded_chown_snippet="; if id -u $container_user >/dev/null 2>&1; then if command -v sudo >/dev/null; then sudo chown -R $container_user:$container_user $workspace_folder || true; else chown -R $container_user:$container_user $workspace_folder || true; fi; else echo 'User $container_user not found in image, skipping chown'; fi"
                    unguarded_chown_snippet="; if command -v sudo >/dev/null; then sudo chown -R $container_user:$container_user $workspace_folder || true; else chown -R $container_user:$container_user $workspace_folder || true; fi"
                    chown_snippet="$guarded_chown_snippet"
                fi
            fi

            if ! mkdir -p .devcontainer 2>/dev/null; then
                error_exit "Failed to create .devcontainer directory" "$EXIT_PERMISSION_ERROR"
            fi

            # Determine image based on selected template
            case "$selected_template" in
                "basic"|"ubuntu"|"alpine")
                    image="mcr.microsoft.com/devcontainers/base:ubuntu"
                    ;;
                "javascript-node"|"typescript-node"|*node*)
                    image="mcr.microsoft.com/devcontainers/javascript-node:18"
                    ;;
                "python"|*python*)
                    image="mcr.microsoft.com/devcontainers/python:3.10"
                    ;;
                "go"|*go*)
                    image="mcr.microsoft.com/devcontainers/go:1.21"
                    ;;
                "custom")
                    read -r -p "Enter custom Docker image: " image
                    ;;
                *)
                    # For unknown templates, try to use the template name as the image
                    image="mcr.microsoft.com/devcontainers/${selected_template}:latest"
                    ;;
            esac

            # Offer to do a best-effort check whether the chosen container user exists in the image before writing config
            user_check_skipped=true
            if [ "$container_user_is_numeric" = false ]; then
                if command -v docker >/dev/null 2>&1; then
                    read -r -p "Check whether user '$container_user' exists in the selected image before writing config? (Y/n): " check_choice
                    check_choice=${check_choice:-Y}
                    if [[ "$check_choice" =~ ^[Yy] ]]; then
                        user_check_skipped=false
                    fi
                fi
            else
                info "Numeric UID/GID provided; skipping user existence check in image"
            fi

            if [ "$container_user_is_numeric" = false ] && [ "$user_check_skipped" = false ] && command -v docker >/dev/null 2>&1; then
                if check_user_in_image "$image" "$container_user"; then
                    info "User '$container_user' found in $image"
                    chown_snippet="$unguarded_chown_snippet"
                else
                    warning "User '$container_user' not found in $image"
                    read -r -p "Continue and write configuration anyway? (y/N): " cont_choice
                    if [[ ! "$cont_choice" =~ ^[Yy] ]]; then
                        info "Cancelling init"
                        exit "$EXIT_SUCCESS"
                    fi
                fi
            fi

            # Generate features JSON if any features were selected
            local features_snippet=""
            if [ "$selected_features_json" != "[]" ] && [ -n "$selected_features_json" ]; then
                # Convert feature names to feature objects
                local features_objects=""
                local first=true
                for feature in $(echo "$selected_features_json" | jq -r '.[]'); do
                    if [ "$first" = true ]; then
                        first=false
elif [ "$wizard_with_dialog_failed" = true ]; then
                info "Devcontainer Initialization Wizard (Text Interface - Dialog failed)"
                echo ""
            else
                        features_objects="$features_objects, "
                    fi
                    features_objects="$features_objects\"ghcr.io/devcontainers/features/$feature\": {}"
                done
                features_snippet="\"features\": {$features_objects},"
            fi

            # Create devcontainer.json depending on image and selected options
            if ! cat > .devcontainer/devcontainer.json << EOF
{
    "name": "$container_name",
    "image": "$image",
    $features_snippet
    $mounts_snippet
    "workspaceFolder": "$workspace_folder",
    "remoteUser": "$remote_user",
    "containerUser": "$container_user",
    "customizations": {
        "vscode": {
            "extensions": [
                "ms-vscode.vscode-json"
            ]
        }
    },
    "postCreateCommand": "bash -lc 'set -eux; if command -v sudo >/dev/null; then sudo apt-get update && sudo apt-get install -y --no-install-recommends curl git vim nano; else apt-get update && apt-get install -y --no-install-recommends curl git vim nano; fi; if command -v npm >/dev/null && [ -f package.json ]; then npm install; fi; if command -v pip >/dev/null && [ -f requirements.txt ]; then pip install -r requirements.txt; fi; if command -v go >/dev/null && [ -f go.mod ]; then go mod download; fi; mkdir -p $workspace_folder${chown_snippet}'"
}
EOF
            then
                error_exit "Failed to create devcontainer.json file" "$EXIT_PERMISSION_ERROR"
            fi

            validate_json_if_available ".devcontainer/devcontainer.json"

            success "Devcontainer configuration created"

            # Offer to start the container immediately
            if [ -t 0 ] && [ -t 1 ]; then
                echo ""
                read -r -p "Would you like to start the devcontainer now? (Y/n): " start_now
                start_now=${start_now:-Y}
                if [[ "$start_now" =~ ^[Yy] ]]; then
                    info "Starting devcontainer..."
                    # Call the up command
                    if command -v devcontainer_up >/dev/null 2>&1; then
                        devcontainer_up
                        return 0
                    fi
                fi
            fi

            info "Run 'dcutil up' to start the container"
            ;;

        "--help"|"-h")
            echo "Usage: dcutil init [mode]"
            echo ""
            echo "Modes:"
            echo "  fast     Create basic Ubuntu container automatically"
            echo "  wizard   Interactive setup with dynamic templates and features (default)"
            echo ""
            echo "Wizard Features:"
            echo "  • Dynamic template fetching (40+ official templates from GitHub)"
            echo "  • Live feature catalog (27+ features: Node.js, Python, Docker, etc.)"
            echo "  • Dialog interface (ncurses UI when available)"
            echo "  • Text interface fallback for all environments"
            echo "  • Auto-generated container names and smart defaults"
            echo "  • Optional immediate container startup"
            echo ""
            echo "Examples:"
            echo "  dcutil init          # Start interactive wizard"
            echo "  dcutil init wizard   # Start interactive wizard (explicit)"
            echo "  dcutil init fast     # Quick basic Ubuntu setup"
            echo "  dcutil init --fast   # Quick basic Ubuntu setup"
            ;;
        *)
            echo -e "${RED}❌ Unknown init mode: $INIT_MODE${NC}"
            echo "Use 'dcutil init --help' for usage information"
            exit 1
            ;;
    esac
}