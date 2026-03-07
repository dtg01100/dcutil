#!/usr/bin/env bash
# Enhanced template integration with official devcontainer ecosystem
# This file provides integration with official templates, features, and CLI

# Source core functionality
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Constants
TEMPLATE_CACHE_TTL=3600  # 1 hour in seconds
FEATURE_CACHE_TTL=3600   # 1 hour in seconds
DEFAULT_CURL_OPTS=(--fail --silent --show-error --location --max-time 10 --connect-timeout 5)

# Global variables for interactive selection
user_selected_template=""
user_selected_features=""

# Get available templates from official registry
fetch_available_templates_official() {
    local cache_file="$HOME/.cache/dcutil/official_templates.json"
    local cache_age=$TEMPLATE_CACHE_TTL

    # Check if cache exists and is recent
    if [ -f "$cache_file" ]; then
        local current_time
        local file_time
        local cache_delta
        current_time=$(date +%s)
        # Use python for portable mtime (stat -c not on macOS)
        file_time=$(python3 - "$cache_file" 2>/dev/null <<'PY'
import os, sys
try:
    print(int(os.path.getmtime(sys.argv[1])))
except Exception:
    print(0)
PY
        )
        cache_delta=$((current_time - file_time))

        if [ "$cache_delta" -lt "$cache_age" ]; then
            cat "$cache_file" 2>/dev/null || get_fallback_templates
            return
        fi
    fi

    # Create cache directory (if possible).
    local cache_dir
    cache_dir="$(dirname "$cache_file")"
    mkdir -p "$cache_dir" 2>/dev/null || true
    if [ ! -d "$cache_dir" ] || [ ! -w "$cache_dir" ]; then
        # Can't use cache; fall back to the bundled templates list
        get_fallback_templates
        return
    fi

    # Fetch from GitHub API like VSCode does
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        info "Fetching official devcontainer templates from GitHub..."
        local templates_json="[]"
        local api_url="https://api.github.com/repos/devcontainers/templates/contents/src"
        local template_dirs=""
        template_dirs=$(curl "${DEFAULT_CURL_OPTS[@]}" "$api_url" | jq -r '.[] | select(.type == "dir") | .name' 2>/dev/null || echo "")

        if [ -n "$template_dirs" ]; then
            templates_json="["
            local first=true
            for template in $template_dirs; do
                local feature_url="https://raw.githubusercontent.com/devcontainers/templates/main/src/${template}/devcontainer-template.json"
                local template_info=""
                template_info=$(curl "${DEFAULT_CURL_OPTS[@]}" "$feature_url" 2>/dev/null || true)
                if [ -n "$template_info" ]; then
                    local id name description
                    id=$(echo "$template_info" | jq -r '.id' 2>/dev/null || echo "$template")
                    name=$(echo "$template_info" | jq -r '.name' 2>/dev/null || echo "$template")
                    description=$(echo "$template_info" | jq -r '.description' 2>/dev/null || echo "")
                    if [ -n "$id" ] && [ -n "$name" ]; then
                        if [ "$first" = true ]; then
                            first=false
                        else
                            templates_json="${templates_json},"
                        fi
                        templates_json="${templates_json}{\"id\": \"$id\", \"name\": \"$name\", \"description\": \"$description\"}"
                    fi
                fi
            done
            templates_json="${templates_json}]"
            echo "$templates_json" > "$cache_file"
            echo "$templates_json"
            return
        fi
    fi

    # Fallback
    get_fallback_templates
}

# Fallback template list (kept minimal and updated manually)
get_fallback_templates() {
    cat << 'EOF'
[
  {"id": "ubuntu", "name": "Ubuntu", "description": "A simple Ubuntu container with Git and other common utilities installed."},
  {"id": "go", "name": "Go", "description": "Official Go programming language container."},
  {"id": "javascript-node", "name": "Node.js", "description": "Node.js development with JavaScript/TypeScript."},
  {"id": "python", "name": "Python", "description": "Python development environment."},
  {"id": "rust", "name": "Rust", "description": "Rust programming language development."},
  {"id": "dotnet", "name": "C# (.NET)", "description": "C# and .NET development."},
  {"id": "java", "name": "Java", "description": "Java development environment."},
  {"id": "cpp", "name": "C/C++", "description": "C and C++ development."},
  {"id": "php", "name": "PHP", "description": "PHP development environment."},
  {"id": "ruby", "name": "Ruby", "description": "Ruby programming language development."},
  {"id": "alpine", "name": "Alpine Linux", "description": "Lightweight Alpine Linux base container."}
]
EOF
}

# Get available features from official registry
fetch_available_features_official() {
    local cache_file="$HOME/.cache/dcutil/official_features.json"
    local cache_age=$FEATURE_CACHE_TTL

    # Check if cache exists and is recent
    if [ -f "$cache_file" ]; then
        local current_time
        local file_time
        local cache_delta
        current_time=$(date +%s)
        file_time=$(python3 - "$cache_file" 2>/dev/null <<'PY'
import os, sys
try:
    print(int(os.path.getmtime(sys.argv[1])))
except Exception:
    print(0)
PY
        )
        cache_delta=$((current_time - file_time))

        if [ "$cache_delta" -lt "$cache_age" ]; then
            cat "$cache_file" 2>/dev/null || get_fallback_features
            return
        fi
    fi

    # Create cache directory
    local cache_dir
    cache_dir="$(dirname "$cache_file")"
    mkdir -p "$cache_dir" 2>/dev/null || true
    if [ ! -d "$cache_dir" ] || [ ! -w "$cache_dir" ]; then
        # Can't use cache; fall back to the bundled features list
        get_fallback_features
        return
    fi

    # Fetch from GitHub API like VSCode does
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        info "Fetching official devcontainer features from GitHub..."
        local features_json="[]"
        local api_url="https://api.github.com/repos/devcontainers/features/contents/src"
        local feature_dirs=""
        feature_dirs=$(curl "${DEFAULT_CURL_OPTS[@]}" "$api_url" | jq -r '.[] | select(.type == "dir") | .name' 2>/dev/null || echo "")

        if [ -n "$feature_dirs" ]; then
            features_json="["
            local first=true
            for feature in $feature_dirs; do
                local feature_url="https://raw.githubusercontent.com/devcontainers/features/main/src/${feature}/devcontainer-feature.json"
                local feature_info=""
                feature_info=$(curl "${DEFAULT_CURL_OPTS[@]}" "$feature_url" 2>/dev/null || true)
                if [ -n "$feature_info" ]; then
                    local id name description
                    id=$(echo "$feature_info" | jq -r '.id // empty' 2>/dev/null || echo "$feature")
                    name=$(echo "$feature_info" | jq -r '.name // empty' 2>/dev/null || echo "$feature")
                    description=$(echo "$feature_info" | jq -r '.description // empty' 2>/dev/null || echo "")
                    if [ -n "$id" ] && [ -n "$name" ]; then
                        if [ "$first" = true ]; then
                            first=false
                        else
                            features_json="${features_json},"
                        fi
                        features_json="${features_json}{\"id\": \"$id\", \"name\": \"$name\", \"description\": \"$description\", \"registry\": \"ghcr.io/devcontainers/features\"}"
                    fi
                fi
            done
            features_json="${features_json}]"
            echo "$features_json" > "$cache_file"
            echo "$features_json"
            return
        fi
    fi

    # Fallback
    get_fallback_features
}

# Fallback feature list (curated selection of popular features)
get_fallback_features() {
    cat << 'EOF'
[
  {"id": "git", "name": "Git", "description": "Install Git from source (latest version)", "registry": "ghcr.io/devcontainers/features"},
  {"id": "common-utils", "name": "Common Utils", "description": "Common command line utilities, zsh, and non-root setup", "registry": "ghcr.io/devcontainers/features"},
  {"id": "docker-in-docker", "name": "Docker-in-Docker", "description": "Docker Engine and CLI in container with DinD", "registry": "ghcr.io/devcontainers/features"},
  {"id": "github-cli", "name": "GitHub CLI", "description": "GitHub CLI (gh) with auth support", "registry": "ghcr.io/devcontainers/features"},
  {"id": "azure-cli", "name": "Azure CLI", "description": "Azure command-line interface", "registry": "ghcr.io/devcontainers/features"},
  {"id": "aws-cli", "name": "AWS CLI", "description": "Amazon Web Services CLI", "registry": "ghcr.io/devcontainers/features"},
  {"id": "docker-from-docker", "name": "Docker from Docker", "description": "Docker CLI and tools from Docker socket", "registry": "ghcr.io/devcontainers/features"},
  {"id": "kubectl-helm", "name": "kubectl & Helm", "description": "Kubernetes CLI (kubectl) and Helm", "registry": "ghcr.io/devcontainers/features"},
  {"id": "postgreSQL", "name": "PostgreSQL", "description": "PostgreSQL client and tools", "registry": "ghcr.io/devcontainers/features"},
  {"id": "mysql", "name": "MySQL", "description": "MySQL client and tools", "registry": "ghcr.io/devcontainers/features"}
]
EOF
}

# Function to detect project type and suggest template
detect_project_template() {
    # Auto-detect language and return appropriate template ID
    if [ -f "go.mod" ]; then
        echo "ghcr.io/devcontainers/templates/go"
    elif [ -f "package.json" ]; then
        echo "ghcr.io/devcontainers/templates/javascript-node"
    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
        echo "ghcr.io/devcontainers/templates/python"
    elif [ -f "Cargo.toml" ]; then
        echo "ghcr.io/devcontainers/templates/rust"
    elif find . -maxdepth 1 -type f \( -name "*.csproj" -o -name "*.fsproj" -o -name "*.vbproj" \) -print -quit | grep -q .; then
        echo "ghcr.io/devcontainers/templates/dotnet"
    elif [ -f "pom.xml" ] || find . -maxdepth 2 -type f -name "*.gradle" -print -quit | grep -q . || [ -f "build.gradle" ]; then
        echo "ghcr.io/devcontainers/templates/java"
    elif [ -f "composer.json" ]; then
        echo "ghcr.io/devcontainers/templates/php"
    elif [ -f "Gemfile" ]; then
        echo "ghcr.io/devcontainers/templates/ruby"
    elif [ -f "CMakeLists.txt" ] || [ -f "Makefile" ]; then
        echo "ghcr.io/devcontainers/templates/cpp"
    else
        echo "ghcr.io/devcontainers/templates/ubuntu"
    fi
}

# Interactive template selection with numbered menu
select_template_interactive() {
    local templates_json="$1"
    local auto_select="${2:-}"

    if has_dialog; then
        select_template_dialog "$templates_json" "$auto_select"
        return $?
    fi

    if ! command -v jq >/dev/null 2>&1; then return 1; fi

    local template_count
    template_count=$(echo "$templates_json" | jq 'length')
    if [ "$template_count" -eq 0 ]; then return 1; fi

    if [ -n "$auto_select" ]; then
        local i=0
        while [ $i -lt "$template_count" ]; do
            local id
            id=$(echo "$templates_json" | jq -r ".[$i].id" 2>/dev/null)
            if [ "$id" = "$auto_select" ]; then
                user_selected_template="$id"
                return 0
            fi
            i=$((i + 1))
        done
    fi

    echo "Available templates:"
    echo "---------------------"
    local i=1
    while [ $i -le "$template_count" ]; do
        local idx=$((i - 1))
        local id name description
        id=$(echo "$templates_json" | jq -r ".[$idx].id" 2>/dev/null)
        name=$(echo "$templates_json" | jq -r ".[$idx].name" 2>/dev/null)
        description=$(echo "$templates_json" | jq -r ".[$idx].description" 2>/dev/null)
        printf "%2d) %-20s - %s\n" "$i" "$name" "$description"
        i=$((i + 1))
    done
    echo ""
    echo "0) Back to previous menu"
    echo ""
    read -r -p "Select a template (1-$template_count, or 0 to cancel): " selection
    if [ "$selection" = "0" ] || [ -z "$selection" ]; then return 1; fi
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$template_count" ]; then
        local selected_idx=$((selection - 1))
        user_selected_template=$(echo "$templates_json" | jq -r ".[$selected_idx].id")
        return 0
    fi
    return 1
}

# Dialog-based template selection
select_template_dialog() {
    local templates_json="$1"
    local auto_select="${2:-}"

    if ! command -v jq >/dev/null 2>&1; then return 1; fi

    local template_count
    template_count=$(echo "$templates_json" | jq 'length')
    if [ "$template_count" -eq 0 ]; then return 1; fi

    local -a dialog_args=()
    local i=0
    while [ $i -lt "$template_count" ]; do
        local id name description
        id=$(echo "$templates_json" | jq -r ".[$i].id" 2>/dev/null)
        name=$(echo "$templates_json" | jq -r ".[$i].name" 2>/dev/null)
        description=$(echo "$templates_json" | jq -r ".[$i].description" 2>/dev/null)
        dialog_args+=("$id" "$name - $description")
        i=$((i + 1))
    done

    user_selected_template=$(DIALOG_TITLE="Select Template" safe_dialog \
        --menu "Choose a base template for your devcontainer:" 20 75 12 \
        "${dialog_args[@]}")

    if [ $? -eq 0 ] && [ -n "$user_selected_template" ]; then
        return 0
    fi
    return 1
}

# Interactive feature selection
select_features_interactive() {
    local features_json="$1"
    local auto_select="${2:-}"

    if has_dialog; then
        select_features_dialog "$features_json" "$auto_select"
        return $?
    fi

    if ! command -v jq >/dev/null 2>&1; then return 1; fi

    local features_count
    features_count=$(echo "$features_json" | jq 'length')
    if [ "${features_count:-0}" -eq 0 ]; then return 1; fi

    if [ -n "$auto_select" ]; then
        user_selected_features="$auto_select"
        return 0
    fi

    user_selected_features=""
    echo "Available features (select multiple using space-separated numbers):"
    echo "----------------------------------------"
    local page=1; local page_size=10; local start_idx=0
    while [ $start_idx -lt "$features_count" ]; do
        echo "Page $page of $(((features_count + page_size - 1) / page_size)):"
        echo "----------------------------------------"
        local display_idx=$start_idx
        local display_end=$((start_idx + page_size))
        if [ $display_end -gt "$features_count" ]; then display_end=$features_count; fi
        while [ $display_idx -lt $display_end ]; do
            local id name description
            id=$(echo "$features_json" | jq -r ".[$display_idx].id" 2>/dev/null)
            name=$(echo "$features_json" | jq -r ".[$display_idx].name" 2>/dev/null)
            description=$(echo "$features_json" | jq -r ".[$display_idx].description" 2>/dev/null)
            printf "%2d) %-25s - %s\n" "$((display_idx + 1))" "$name" "$description"
            display_idx=$((display_idx + 1))
        done
        echo ""
        echo "Commands: [n]ext page, [p]revious page, [s]elect items, [q]uit"
        read -r -p "Enter your choice: " choice
        case "$choice" in
            "n") start_idx=$((start_idx + page_size)); page=$((page + 1)) ;;
            "p") start_idx=$((start_idx - page_size)); page=$((page - 1)) ;;
            "q") return 1 ;;
            *)
                for sel in $choice; do
                    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "$features_count" ]; then
                        local feature_id=$(echo "$features_json" | jq -r ".[$((sel - 1))].id")
                        if [ -z "$user_selected_features" ]; then user_selected_features="$feature_id"
                        else user_selected_features="$user_selected_features,$feature_id"; fi
                    fi
                done
                if [ -n "$user_selected_features" ]; then return 0; fi
                ;;
        esac
    done
    return 0
}

# Dialog-based feature selection
select_features_dialog() {
    local features_json="$1"
    local auto_select="${2:-}"

    if ! command -v jq >/dev/null 2>&1; then return 1; fi

    local features_count
    features_count=$(echo "$features_json" | jq 'length')
    if [ "${features_count:-0}" -eq 0 ]; then return 1; fi

    if [ -n "$auto_select" ]; then
        user_selected_features="$auto_select"
        return 0
    fi

    local -a dialog_args=()
    local i=0
    while [ $i -lt "$features_count" ]; do
        local id name description
        id=$(echo "$features_json" | jq -r ".[$i].id" 2>/dev/null)
        name=$(echo "$features_json" | jq -r ".[$i].name" 2>/dev/null)
        description=$(echo "$features_json" | jq -r ".[$i].description" 2>/dev/null)
        dialog_args+=("$id" "$name - $description" "off")
        i=$((i + 1))
    done

    local selections
    selections=$(DIALOG_TITLE="Select Features" safe_dialog \
        --checklist "Select features to include (Space to toggle):" 20 75 12 \
        "${dialog_args[@]}")

    if [ $? -eq 0 ]; then
        user_selected_features=$(echo "$selections" | tr ' ' ',')
        return 0
    fi
    return 1
}

# Main wizard function
wizard_with_official_integration() {
    local templates_json=$(fetch_available_templates_official)
    local features_json=$(fetch_available_features_official)

    if has_dialog; then
        # info "Using dialog mode for wizard"
        wizard_dialog_mode "$templates_json" "$features_json"
        return $?
    fi
    # info "Using text mode for wizard"

    info "Devcontainer Initialization Wizard (Powered by Official Templates)"
    echo "=================================================================="
    PROJECT_DIR="$(pwd)"; export PROJECT_DIR

    echo ""; echo "🔍 Step 1: Project Type Detection"; echo "----------------------------------------"
    local detected_template=$(detect_project_template)
    local detected_name=$(echo "$templates_json" | jq -r ".[] | select(.id == \"${detected_template#ghcr.io/devcontainers/templates/}\") | .name" 2>/dev/null || echo "Unknown")
    echo "Automatically detected: $detected_name (${detected_template#ghcr.io/devcontainers/templates/})"

    local project_choice="1"
    if [ -t 0 ] && [ -t 1 ] && [ -z "${CI:-}" ]; then
        echo "1) Use detected template: $detected_name"; echo "2) Choose from available templates"; echo "3) Use custom image"
        read -r -p "Select option [1]: " project_choice; project_choice=${project_choice:-1}
    fi

    local selected_template_id="$detected_template"
    local template_args='{"imageVariant": "noble"}'
    case "$project_choice" in
        2) if select_template_interactive "$templates_json"; then selected_template_id="ghcr.io/devcontainers/templates/$user_selected_template"; fi ;;
        3) read -r -p "Enter custom Docker image: " custom_image; selected_template_id="custom:$custom_image"; template_args="{}" ;;
    esac

    echo ""; echo "🛠️  Step 2: Feature Selection"; echo "----------------------------------------"
    local features_input="git,common-utils"
    if [ -z "${CI:-}" ]; then
        if select_features_interactive "$features_json"; then features_input="$user_selected_features"; fi
    fi

    local features_array="[]"
    IFS=',' read -ra feature_ids <<< "$features_input"
    for feature_id in "${feature_ids[@]}"; do
        feature_id=$(echo "$feature_id" | xargs)
        if [ -n "$feature_id" ]; then
            local full_id="$feature_id"
            if [[ "$feature_id" != ghcr.io/* ]] && [[ "$feature_id" != "custom:"* ]]; then full_id="ghcr.io/devcontainers/features/$feature_id"; fi
            features_array=$(echo "$features_array" | jq -c ". + [{\"id\": \"$full_id\", \"options\": {}}]")
        fi
    done

    echo ""; echo "⚙️  Step 3: Advanced Configuration"; echo "----------------------------------------"
    local container_name=$(basename "$PROJECT_DIR")
    local workspace_folder="/workspaces/$container_name"
    local container_user="vscode"; local remote_user="vscode"
    if [ -t 0 ] && [ -t 1 ] && [ -z "${CI:-}" ]; then
        read -r -p "Container name [$container_name]: " t; container_name=${t:-$container_name}
        read -r -p "Workspace folder [$workspace_folder]: " t; workspace_folder=${t:-$workspace_folder}
    fi

    echo ""; echo "🔐 Step 4: SSH Configuration"; echo "----------------------------------------"
    local enable_ssh_propagation="n"
    if [ -t 0 ] && [ -t 1 ] && [ -z "${CI:-}" ]; then
        read -r -p "Enable SSH propagation? (y/N): " enable_ssh_propagation
    fi

    echo ""; echo "📦 Step 5: VS Code Customizations"; echo "----------------------------------------"
    local add_vscode_customizations="n"
    if [ -t 0 ] && [ -t 1 ] && [ -z "${CI:-}" ]; then
        read -r -p "Add VS Code customizations? (Y/n): " add_vscode_customizations
    fi

    apply_wizard_config "$selected_template_id" "$features_array" "$template_args" "$container_name" "$workspace_folder" "$container_user" "$remote_user" "$enable_ssh_propagation" "$add_vscode_customizations"
}

# Dialog-based wizard implementation
wizard_dialog_mode() {
    local templates_json="$1"
    local features_json="$2"
    PROJECT_DIR="$(pwd)"; export PROJECT_DIR

    # Step 1: Template selection
    local detected_template=$(detect_project_template)
    local detected_id="${detected_template#ghcr.io/devcontainers/templates/}"
    local detected_name=$(echo "$templates_json" | jq -r ".[] | select(.id == \"$detected_id\") | .name" 2>/dev/null || echo "Unknown")

    local project_choice
    project_choice=$(DIALOG_TITLE="dcutil Wizard - Step 1" safe_dialog \
        --menu "Project Type Detection\n\nAutomatically detected: $detected_name\n\nChoose an option:" 15 70 3 \
        "1" "Use detected template: $detected_name" \
        "2" "Choose from all available templates" \
        "3" "Use a custom Docker image")
    
    if [ $? -ne 0 ]; then return 1; fi

    local selected_template_id="$detected_template"
    local template_args='{"imageVariant": "noble"}'
    
    if [ "$project_choice" = "2" ]; then
        if ! select_template_dialog "$templates_json"; then return 1; fi
        selected_template_id="ghcr.io/devcontainers/templates/$user_selected_template"
    elif [ "$project_choice" = "3" ]; then
        local custom_image
        custom_image=$(DIALOG_TITLE="Custom Image" safe_dialog --inputbox "Enter custom Docker image name:" 10 60)
        if [ $? -ne 0 ]; then return 1; fi
        selected_template_id="custom:$custom_image"
        template_args="{}"
    fi

    # Step 2: Features
    if ! select_features_dialog "$features_json"; then return 1; fi
    local features_input="$user_selected_features"
    local features_array="[]"
    IFS=',' read -ra feature_ids <<< "$features_input"
    for feature_id in "${feature_ids[@]}"; do
        feature_id=$(echo "$feature_id" | xargs)
        if [ -n "$feature_id" ]; then
            local full_id="$feature_id"
            if [[ "$feature_id" != ghcr.io/* ]] && [[ "$feature_id" != "custom:"* ]]; then full_id="ghcr.io/devcontainers/features/$feature_id"; fi
            features_array=$(echo "$features_array" | jq -c ". + [{\"id\": \"$full_id\", \"options\": {}}]")
        fi
    done

    # Step 3: Advanced
    local container_name=$(basename "$PROJECT_DIR")
    container_name=$(DIALOG_TITLE="Advanced Configuration" safe_dialog --inputbox "Enter container name:" 10 60 "$container_name")
    
    # Step 4: SSH
    local enable_ssh_propagation="n"
    if safe_dialog --yesno "Enable SSH propagation?\n\nAllows host SSH keys to be used inside the container." 10 60; then
        enable_ssh_propagation="y"
    fi

    # Step 5: VS Code
    local add_vscode_customizations="n"
    if safe_dialog --yesno "Add VS Code customizations (extensions, settings)?" 10 60; then
        add_vscode_customizations="y"
    fi

    apply_wizard_config "$selected_template_id" "$features_array" "$template_args" "$container_name" "/workspaces/$container_name" "vscode" "vscode" "$enable_ssh_propagation" "$add_vscode_customizations"
}

# Helper to apply configuration (shared between text and dialog wizard)
apply_wizard_config() {
    local selected_template_id="$1"
    local features_array="$2"
    local template_args="$3"
    local container_name="$4"
    local workspace_folder="$5"
    local container_user="$6"
    local remote_user="$7"
    local enable_ssh_propagation="$8"
    local add_vscode_customizations="$9"

    info "Creating configuration..."
    
    if [[ "$selected_template_id" == custom:* ]]; then
        local custom_image="${selected_template_id#custom:}"
        mkdir -p .devcontainer
        echo "{\"name\": \"$container_name\", \"image\": \"$custom_image\", \"workspaceFolder\": \"$workspace_folder\", \"remoteUser\": \"$remote_user\", \"containerUser\": \"$container_user\"}" > .devcontainer/devcontainer.json
    else
        devcontainer templates apply --workspace-folder "$PROJECT_DIR" --template-id "$selected_template_id" --features "$features_array" --template-args "$template_args" >/dev/null 2>&1 || error_exit "Failed to apply template" "$EXIT_DEVCONTAINER_ERROR"
    fi

    # Post-processing
    if [ -f ".devcontainer/devcontainer.json" ]; then
        if [[ "$enable_ssh_propagation" =~ ^[Yy] ]]; then
            enable_ssh_propagation ".devcontainer/devcontainer.json" >/dev/null
        fi
        sanitize_features_json
        success "Devcontainer configuration created successfully"
        return 0
    fi
    return 1
}

# Sanitize features in existing devcontainer.json to replace numeric keys with canonical ids
sanitize_features_json() {
    local dev_file=".devcontainer/devcontainer.json"
    if [ ! -f "$dev_file" ]; then return 0; fi
    if ! command -v jq >/dev/null 2>&1; then return 0; fi
    local temp_file="${dev_file}.tmp"
    local features_json=$(fetch_available_features_official || echo "[]")
    jq --argjson pref "$features_json" '
        def mapkey(k):
            if k | test("^[0-9]+$") then
                (k | tonumber - 1) as $i | ($pref[$i].id // k)
            else k end;
        .features = (.features // {} | to_entries | map(.key = mapkey(.key)) | from_entries)
    ' "$dev_file" > "$temp_file" && mv "$temp_file" "$dev_file"
}
