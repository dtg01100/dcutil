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

    if ! command -v jq >/dev/null 2>&1; then
        warning "jq not available, using basic template selection"
        echo "basic"
        return
    fi

    # Parse template names
    local template_names
    template_names=$(echo "$templates_json" | jq -r '.[].name' 2>/dev/null || echo "")

    if [ -z "$template_names" ]; then
        warning "Could not fetch templates, using basic template"
        echo "basic"
        return
    fi

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

    local selected_features=()
    while true; do
        read -r -p "Choose features (comma-separated numbers, or 0 for none): " choices >&2
        if [ "$choices" = "0" ] || [ -z "$choices" ]; then
            break
        fi

        # Parse comma-separated choices
        local valid=true
        IFS=',' read -ra choice_array <<< "$choices"
        for choice in "${choice_array[@]}"; do
            choice=$(echo "$choice" | xargs)  # trim whitespace
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
                selected_features+=("${feature_array[$((choice-1))]}")
            else
                echo "Invalid choice: $choice. Please enter numbers between 1 and $((i-1))." >&2
                valid=false
                break
            fi
        done

        if [ "$valid" = true ]; then
            break
        fi
    done

    # Return JSON array of selected features
    printf '%s\n' "${selected_features[@]}" | jq -R . | jq -s .
}

# Check if dialog is available for enhanced UI
has_dialog() {
    # Basic checks
    if ! command -v dialog >/dev/null 2>&1; then
        return 1
    fi
    if ! [ -t 0 ] || ! [ -t 1 ] || ! [ -n "$TERM" ]; then
        return 1
    fi

    # Test if dialog can actually run (try a simple command)
    if echo "" | dialog --stdout --msgbox "Testing dialog" 5 20 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Enhanced wizard with dialog interface
wizard_with_dialog() {
    local templates_json="$1"
    local features_json="$2"

    # Template selection
    local template_list=""
    local template_names=""
    local i=1

    if command -v jq >/dev/null 2>&1; then
        while IFS= read -r template; do
            if [ -n "$template" ]; then
                template_list="$template_list $i \"$template\""
                template_names="$template_names $template"
                i=$((i + 1))
            fi
        done <<< "$(echo "$templates_json" | jq -r '.[].name' 2>/dev/null || echo "")"
    fi

    template_list="$template_list $i \"Custom image\""

    local selected_template_num
    selected_template_num=$(dialog --stdout --no-cancel --title "Devcontainer Template Selection" \
        --menu "Choose a devcontainer template:" 20 60 15 \
        $template_list 2>/dev/null)
    local dialog_exit=$?

    if [ $dialog_exit -eq 1 ] || [ $dialog_exit -eq 255 ]; then
        # User cancelled or pressed ESC
        return 1
    elif [ $dialog_exit -ne 0 ]; then
        # Error
        return 1
    fi

    local selected_template=""
    if [ "$selected_template_num" = "$i" ]; then
        selected_template="custom"
    elif [ -n "$selected_template_num" ] && [ "$selected_template_num" -gt 0 ] && [ "$selected_template_num" -le $((i-1)) ]; then
        # Convert space-separated template_names to array and get the selected one
        local template_array=($template_names)
        selected_template="${template_array[$((selected_template_num-1))]}"
    fi

    # Feature selection
    local feature_list=""
    i=1

    if command -v jq >/dev/null 2>&1; then
        while IFS= read -r feature; do
            if [ -n "$feature" ]; then
                feature_list="$feature_list $i \"$feature\" off"
                i=$((i + 1))
            fi
        done <<< "$(echo "$features_json" | jq -r '.[].name' 2>/dev/null || echo "")"
    fi

    local selected_features=""
    if [ -n "$feature_list" ]; then
        selected_features=$(dialog --stdout --title "Devcontainer Features" \
            --checklist "Select additional features to install:" 20 60 10 \
            $feature_list 2>/dev/null)
        local dialog_exit=$?

        if [ $dialog_exit -eq 1 ] || [ $dialog_exit -eq 255 ]; then
            # User cancelled
            return 1
        elif [ $dialog_exit -ne 0 ]; then
            # Error
            return 1
        fi
    fi

    # Container name
    local container_name
    container_name=$(dialog --stdout --title "Container Configuration" \
        --inputbox "Container name:" 8 40 "My Project" 2>/dev/null)

    # Workspace folder
    local workspace_folder
    workspace_folder=$(dialog --stdout --title "Container Configuration" \
        --inputbox "Workspace folder inside container:" 8 40 "/workspaces" 2>/dev/null)

    # Container user
    local container_user
    container_user=$(dialog --stdout --title "Container Configuration" \
        --inputbox "Container user (name or UID[:GID]):" 8 40 "vscode" 2>/dev/null)

    # Mount options
    dialog --title "Mount Options" \
        --yesno "Map host project directory to container workspace?" 6 50 2>/dev/null
    mount_choice=$?

    # Chown options
    dialog --title "Permissions" \
        --yesno "Set ownership of workspace to container user?" 6 50 2>/dev/null
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
            mounts_snippet=""
            if [ "$mount_project_to_container" = true ]; then
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
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    $mounts_snippet
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
    "postCreateCommand": "bash -lc 'set -eux; if command -v sudo >/dev/null; then sudo apt-get update && sudo apt-get install -y --no-install-recommends curl git; else apt-get update && apt-get install -y --no-install-recommends curl git; fi; mkdir -p $workspace_folder$chown_snippet'"
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
            # Get available templates and features
            local templates_json
            templates_json=$(fetch_available_templates)

            local features_json
            features_json=$(fetch_available_features)

            # Use dialog interface if available, otherwise fallback to text
            if has_dialog; then
                info "Devcontainer Initialization Wizard (Enhanced UI)"
                echo ""

                # Get all config via dialog
                if ! wizard_with_dialog "$templates_json" "$features_json"; then
                    info "Wizard cancelled by user"
                    exit 0
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
                container_user_input=${container_user:-vscode}

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
            fi

            # Map template to project choice for backward compatibility
            case "$selected_template" in
                "basic"|"ubuntu")
                    project_choice=1
                    ;;
                "javascript-node"|"typescript-node"|*node*)
                    project_choice=2
                    ;;
                "python"|*python*)
                    project_choice=3
                    ;;
                "go"|*go*)
                    project_choice=4
                    ;;
                "custom")
                    project_choice=5
                    ;;
                *)
                    # For unknown templates, treat as custom
                    project_choice=5
                    ;;
            esac

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

            # Ask whether to set ownership of the workspace
            read -r -p "Set ownership of $workspace_folder to ${container_user_input}? (Y/n): " chown_choice
            chown_choice=${chown_choice:-Y}
            set_chown=false
            if [[ "$chown_choice" =~ ^[Yy] ]]; then
                set_chown=true
            fi

            # Ask whether to mount host project dir into container workspace
            read -r -p "Map host project directory ($PROJECT_DIR) to container workspace folder as bind mount? (Y/n): " mount_choice
            mount_choice=${mount_choice:-Y}
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
                        exit $EXIT_SUCCESS
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
            echo "  wizard   Interactive setup (default)"
            echo ""
            echo "Examples:"
            echo "  dcutil init          # Start wizard"
            echo "  dcutil init fast     # Quick basic setup"
            echo "  dcutil init --fast   # Quick basic setup"
            ;;
        *)
            echo -e "${RED}❌ Unknown init mode: $INIT_MODE${NC}"
            echo "Use 'dcutil init --help' for usage information"
            exit 1
            ;;
    esac
}