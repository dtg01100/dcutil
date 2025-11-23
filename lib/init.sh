#!/usr/bin/env bash

# Initialization functionality for dcutil

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

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
            info "Run 'dcutil up' to start the container"
            ;;
        "--wizard"|"wizard"|"")
            info "Devcontainer Initialization Wizard"
            echo ""

            # Get project type
            echo -e "${YELLOW}📋 Choose project type:${NC}"
            echo "1) Basic (Ubuntu + common tools)"
            echo "2) Node.js"
            echo "3) Python"
            echo "4) Go"
            echo "5) Custom image"
            echo ""
            read -r -p "Enter choice [1-5]: " project_choice

            # Validate project choice
            if [[ ! "$project_choice" =~ ^[1-5]$ ]]; then
                error_exit "Invalid choice. Please enter a number between 1-5." "$EXIT_INVALID_ARGS"
            fi

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

            case "$project_choice" in
                "1")
                    image="mcr.microsoft.com/devcontainers/base:ubuntu"
                    ;;
                "2")
                    image="mcr.microsoft.com/devcontainers/javascript-node:18"
                    ;;
                "3")
                    image="mcr.microsoft.com/devcontainers/python:3.10"
                    ;;
                "4")
                    image="mcr.microsoft.com/devcontainers/go:1.21"
                    ;;
                "5")
                    read -r -p "Enter Docker image name: " custom_image
                    if [ -z "$custom_image" ]; then
                        error_exit "Docker image name cannot be empty" "$EXIT_INVALID_ARGS"
                    fi
                    image="$custom_image"
                    ;;
                *)
                    error_exit "Invalid choice" "$EXIT_INVALID_ARGS"
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

            # Create devcontainer.json depending on image and selected options
            if ! cat > .devcontainer/devcontainer.json << EOF
{
    "name": "$container_name",
    "image": "$image",
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
            info "Run 'dcutil up' to start the container"

            success "Devcontainer configuration created"
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