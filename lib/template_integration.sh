# Enhanced template integration with official devcontainer ecosystem
# This file provides integration with official templates, features, and CLI

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Constants
TEMPLATE_CACHE_TTL=3600  # 1 hour in seconds
FEATURE_CACHE_TTL=3600   # 1 hour in seconds

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
        file_time=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
        cache_delta=$((current_time - file_time))
        
        if [ "$cache_delta" -lt "$cache_age" ]; then
            cat "$cache_file" 2>/dev/null || get_fallback_templates
            return
        fi
    fi

    # Create cache directory
    mkdir -p "$(dirname "$cache_file")" 2>/dev/null || true

    # Fetch from GitHub API like VSCode does
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        info "Fetching official devcontainer templates from GitHub..."
        local templates_json="[]"
        local api_url="https://api.github.com/repos/devcontainers/templates/contents/src"
        local template_dirs=""
        template_dirs=$(curl -s "$api_url" | jq -r '.[] | select(.type == "dir") | .name' 2>/dev/null || echo "")

        if [ -n "$template_dirs" ]; then
            templates_json="["
            local first=true
            for template in $template_dirs; do
                local template_url="https://raw.githubusercontent.com/devcontainers/templates/main/src/${template}/devcontainer-template.json"
                local template_info=""
                template_info=$(curl -s "$template_url" 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$template_info" ]; then
                    if [ "$template" = "python" ]; then echo "template_info: $template_info" >&2; fi
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
        file_time=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
        cache_delta=$((current_time - file_time))
        
        if [ "$cache_delta" -lt "$cache_age" ]; then
            cat "$cache_file" 2>/dev/null || get_fallback_features
            return
        fi
    fi

    # Create cache directory
    mkdir -p "$(dirname "$cache_file")" 2>/dev/null || true

    # Fetch from GitHub API like VSCode does
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        info "Fetching official devcontainer features from GitHub..."
        local features_json="[]"
        local api_url="https://api.github.com/repos/devcontainers/features/contents/src"
        local feature_dirs=""
        feature_dirs=$(curl -s "$api_url" | jq -r '.[] | select(.type == "dir") | .name' 2>/dev/null || echo "")

        if [ -n "$feature_dirs" ]; then
            features_json="["
            local first=true
            for feature in $feature_dirs; do
                local feature_url="https://raw.githubusercontent.com/devcontainers/features/main/src/${feature}/devcontainer-feature.json"
                local feature_info=""
                feature_info=$(curl -s "$feature_url" 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$feature_info" ]; then
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
    elif ls *.csproj *.fsproj *.vbproj 2>/dev/null | head -1 | grep -q .; then
        echo "ghcr.io/devcontainers/templates/dotnet"
    elif [ -f "pom.xml" ] || [ -f "*.gradle" ] || [ -f "build.gradle" ]; then
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

# Function to suggest features based on project type
suggest_features_for_project() {
    local template_id="$1"
    local features_list='[{"id": "ghcr.io/devcontainers/features/git", "options": {}}, {"id": "ghcr.io/devcontainers/features/common-utils", "options": {}}]'
    
    case "$template_id" in
        *"go"*)
            # Go projects might want additional tools
            echo '[]'
            ;;
        *"javascript-node"*)
            # Node.js projects might want Docker support
            echo '[]'
            ;;
        *"python"*)
            # Python projects might want Docker support
            echo '[]'
            ;;
        *"java"*)
            # Java projects might want kubectl/helm
            echo '[]'
            ;;
        *)
            # Default features
            echo "$features_list"
            ;;
    esac
}

# Apply official template with enhanced error handling
apply_official_template() {
    local template_id="$1"
    local features_json="$2"
    local template_args="$3"
    
    # Ensure a valid workspace folder
    local workspace_folder
    workspace_folder="${PROJECT_DIR:-$(pwd)}"

    info "Applying official template: $template_id"
    
    # Use the official devcontainer CLI
    if ! command -v devcontainer >/dev/null 2>&1; then
        error "devcontainer CLI not found. Please install it with: brew install devcontainer"
        return 1
    fi

    # Validate features_json
    local features_arg="[]"
    if [ "$features_json" != "[]" ] && command -v jq >/dev/null 2>&1; then
        if ! echo "$features_json" | jq -e . >/dev/null 2>&1; then
            error "Invalid features JSON provided to apply_official_template"
            echo "$features_json" >&2
            return 1
        fi
        features_arg="$features_json"
    fi

    # Apply the template
    info "Applying template with template_args: $template_args and features: $features_arg"
    local cmd=(devcontainer templates apply --workspace-folder "$workspace_folder" --template-id "$template_id" --template-args "$template_args")
    if [ "$features_arg" != "[]" ]; then
        cmd+=(--features "$features_arg")
    fi
    # Run command and capture output for diagnostics
    local apply_output
    if apply_output="$("${cmd[@]}" 2>&1)"; then
        success "Template applied successfully"
        return 0
    else
        error "Failed to apply template $template_id"
        echo "$apply_output" >&2
        return 1
    fi
}

# Enhance generated configuration with dcutil additions
enhance_with_dcutil_additions() {
    local devcontainer_file=".devcontainer/devcontainer.json"
    
    if [ ! -f "$devcontainer_file" ]; then
        warning "No devcontainer.json found to enhance"
        return 1
    fi
    
    # Just add our enhancement comment at the top
    # The official template already includes features and proper structure
    local temp_file="${devcontainer_file}.tmp"
    
    # Set up cleanup trap
    trap 'rm -f "$temp_file"' RETURN EXIT INT TERM
    
    # Add our enhancement comment while preserving everything else
    # Just copy the file without adding comments to JSON
    cp "$devcontainer_file" "$temp_file"

    # Replace original
    mv "$temp_file" "$devcontainer_file"

    success "Enhanced configuration with dcutil additions"
}

# Sanitize features in existing devcontainer.json to replace numeric keys with canonical ids
sanitize_features_json() {
    local dev_file=".devcontainer/devcontainer.json"
    if [ ! -f "$dev_file" ]; then
        return 0
    fi
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    local features_json
    features_json=$(fetch_available_features_official || echo "[]")

    # If features is an object with numeric keys like ghcr.io/devcontainers/features/2, map them back
    # Use jq to transform keys in one-shot to avoid subshell issues
    if ! echo "$features_json" | jq -e . >/dev/null 2>&1; then
        return 0
    fi

    # Set up cleanup trap for temp file
    local temp_file="$dev_file.tmp"
    trap 'rm -f "$temp_file"' RETURN EXIT INT TERM

    # Run jq transformation: detect numeric suffix in feature key and map to pref array
    jq --argjson pref "$features_json" '
        def mapkey(k):
            if k | test("^ghcr.io/devcontainers/features/[0-9]+(:.*)?$") then
                (k | capture("^ghcr.io/devcontainers/features/(?<idx>[0-9]+)(?<rest>[:].*)?$") ) as $m
                | ($m.idx | tonumber - 1) as $i
                | ($pref[$i].id // "") as $fid
                | ($pref[$i].registry // "ghcr.io/devcontainers/features") as $fr
                | if $fid == "" then k else ($fr + "/" + $fid + ($m.rest // "")) end
            else k end;
        .features = (.features // {} | to_entries | map(.key = mapkey(.key)) | from_entries)
    ' "$dev_file" > "$temp_file" && mv "$temp_file" "$dev_file"
}

# Get template metadata
get_template_metadata() {
    local template_id="$1"
    
    if command -v devcontainer >/dev/null 2>&1; then
        devcontainer templates metadata "$template_id" 2>/dev/null || echo "{}"
    else
        echo "{}"
    fi
}

# List available templates with descriptions
list_available_templates() {
    local templates_json
    templates_json=$(fetch_available_templates_official)
    
    if command -v jq >/dev/null 2>&1; then
        echo "Available templates:"
        echo "$templates_json" | jq -r '.[] | "  \(.id): \(.name) - \(.description)"'
    else
        echo "Available templates (install jq for better formatting):"
        echo "$templates_json" | grep -o '"id": "[^"]*"' | sed 's/"id": "//; s/"//'
    fi
}

# List available features with descriptions  
list_available_features() {
    local features_json
    features_json=$(fetch_available_features_official)
    
    if command -v jq >/dev/null 2>&1; then
        echo "Available features:"
        echo "$features_json" | jq -r '.[] | "  \(.id) (\(.registry)): \(.name) - \(.description)"'
    else
        echo "Available features (install jq for better formatting):"
        echo "$features_json" | grep -o '"id": "[^"]*"' | sed 's/"id": "//; s/"//'
    fi
}

# Enhanced wizard mode with official devcontainer integration
wizard_with_official_integration() {
    local templates_json
    templates_json=$(fetch_available_templates_official)

    local features_json
    features_json=$(fetch_available_features_official)

    info "Devcontainer Initialization Wizard (Powered by Official Templates)"
    echo "=================================================================="
    
    # Ensure PROJECT_DIR is set to current working directory
    PROJECT_DIR="$(pwd)"
    export PROJECT_DIR
    
    # Step 1: Project type detection and selection
    echo ""
    echo "🔍 Step 1: Project Type Detection"
    echo "----------------------------------------"
    
    local detected_template
    detected_template=$(detect_project_template)
    local detected_name
    detected_name=$(echo "$templates_json" | jq -r ".[] | select(.id == \"${detected_template#ghcr.io/devcontainers/templates/}\") | .name" 2>/dev/null || echo "Unknown")
    
    echo "Automatically detected: $detected_name (${detected_template#ghcr.io/devcontainers/templates/})"
    echo ""
    
    if [ -t 0 ] && [ -t 1 ]; then
        echo "Would you like to use the detected template or choose a different one?"
        echo "1) Use detected template: $detected_name"
        echo "2) Choose from available templates"
        echo "3) Use custom image"
        read -r -p "Select option [1]: " project_choice
        project_choice=${project_choice:-1}
    else
        project_choice="1"
    fi
    
    local selected_template_id="$detected_template"
    local template_args='{"imageVariant": "noble"}'
    
    case "$project_choice" in
        2)
            echo ""
            echo "Available templates:"
            echo "$templates_json" | jq -r '.[] | "  \(.id): \(.name) - \(.description)"'
            echo ""
            read -r -p "Enter template ID [ubuntu]: " user_template
            user_template=${user_template:-ubuntu}
            selected_template_id="ghcr.io/devcontainers/templates/$user_template"
            ;;
        3)
            echo ""
            read -r -p "Enter custom Docker image: " custom_image
            selected_template_id="custom:$custom_image"
            template_args="{}"
            ;;
    esac
    
    # Step 2: Feature selection
    echo ""
    echo "🛠️  Step 2: Feature Selection"
    echo "----------------------------------------"
    
    echo "Available features:"
    echo "$features_json" | jq -r '.[] | "  \(.id) (\(.registry)): \(.name) - \(.description)"'
    echo ""
    echo "Enter comma-separated feature IDs to include [git,common-utils]: "
    read -r features_input
    features_input=${features_input:-"git,common-utils"}
    
    # Build features array (normalize IDs to canonical registry paths)
    local features_array="[]"
    if [ -n "$features_input" ]; then
        IFS=',' read -ra feature_ids <<< "$features_input"
        for feature_id in "${feature_ids[@]}"; do
            feature_id=$(echo "$feature_id" | xargs)  # trim whitespace
            local full_id registry mapped_id mapped_registry idx
            unset full_id registry mapped_id mapped_registry
            if [[ "$feature_id" != "custom:"* ]]; then
                # Numeric input: map to index in features_json (1-based)
                if [[ "$feature_id" =~ ^[0-9]+$ ]] && command -v jq >/dev/null 2>&1 && [ -n "$features_json" ]; then
                    idx=$((feature_id - 1))
                    mapped_id=$(echo "$features_json" | jq -r ".[$idx].id // empty" 2>/dev/null | head -n1)
                    mapped_registry=$(echo "$features_json" | jq -r ".[$idx].registry // empty" 2>/dev/null | head -n1)
                    # The fetched features id may already be a full registry path (ghcr.io/...)
                    if [ -n "$mapped_id" ]; then
                        feature_id="$mapped_id"
                        # If mapped_id contains 'ghcr.io' then treat full_id as mapped_id
                        if [[ "$mapped_id" == ghcr.io/* ]]; then
                            full_id="$mapped_id"
                        elif [ -n "$mapped_registry" ]; then
                            full_id="$mapped_registry/$mapped_id"
                        else
                            full_id="ghcr.io/devcontainers/features/$mapped_id"
                        fi
                    fi
                fi

                # If user provided full registry path, use it as-is
                if [[ -z "${full_id:-}" ]]; then
                    if [[ "$feature_id" == ghcr.io/* ]]; then
                        full_id="$feature_id"
                    else
                        # Try to find registry for this feature in fetched features list
                        if command -v jq >/dev/null 2>&1 && [ -n "$features_json" ]; then
                            registry=$(echo "$features_json" | jq -r --arg id "$feature_id" '.[] | select(.id == $id) | .registry' 2>/dev/null | head -n1)
                            # If registry empty, try matching alternate id forms
                            if [ -z "$registry" ]; then
                                registry=$(echo "$features_json" | jq -r --arg id "$feature_id" '.[] | select(.id == $id or .id == ("ghcr.io/devcontainers/features/" + $id)) | .registry' 2>/dev/null | head -n1)
                            fi
                        fi
                        if [ -n "$registry" ]; then
                            full_id="$registry/$feature_id"
                        else
                            # fallback to default registry prefix
                            full_id="ghcr.io/devcontainers/features/$feature_id"
                        fi
                    fi
                fi

                features_array=$(echo "$features_array" | jq ". + [{\"id\": \"$full_id\", \"options\": {}}]")
            fi
        done

    fi
    # Compact the JSON to avoid multiline issues
    info "Raw features_array before compact: $features_array"
    features_array=$(jq -c . <<< "$features_array")
    info "Compacted features_array: $features_array"
    
    # Step 3: Advanced configuration
    echo ""
    echo "⚙️  Step 3: Advanced Configuration"
    echo "----------------------------------------"
    
    if [ -t 0 ] && [ -t 1 ]; then
        read -r -p "Container name [$(basename "$PROJECT_DIR")]: " container_name
        container_name=${container_name:-$(basename "$PROJECT_DIR")}
        
        read -r -p "Workspace folder [/workspaces/$(basename "$PROJECT_DIR")]: " workspace_folder
        workspace_folder=${workspace_folder:-/workspaces/$(basename "$PROJECT_DIR")}
        
        read -r -p "Container user [vscode]: " container_user
        container_user=${container_user:-vscode}
        
        read -r -p "Remote user [$container_user]: " remote_user
        remote_user=${remote_user:-$container_user}
    else
        container_name=$(basename "$PROJECT_DIR")
        workspace_folder="/workspaces/$(basename "$PROJECT_DIR")"
        container_user="vscode"
        remote_user="vscode"
    fi
    
    # Step 4: VS Code customizations
    echo ""
    echo "📦 Step 4: VS Code Customizations"
    echo "----------------------------------------"

    # Ask if user wants to add VS Code customizations
    if [ -t 0 ] && [ -t 1 ]; then
        read -r -p "Would you like to add VS Code customizations (extensions, settings)? (Y/n): " add_vscode_customizations
        add_vscode_customizations=${add_vscode_customizations:-Y}
    else
        add_vscode_customizations="n"
    fi

    local all_extensions_array="[]"
    local vscode_settings_json="{}"

    if [[ "$add_vscode_customizations" =~ ^[Yy] ]]; then
        # Suggest extensions based on project type
        local suggested_extensions="[]"
        case "$selected_template_id" in
            *"go"*)
                suggested_extensions='["golang.Go", "ms-vscode.vscode-json", "ms-vscode.git"]'
                ;;
            *"javascript-node"*)
                suggested_extensions='["dbaeumer.vscode-eslint", "ms-vscode.vscode-json", "ms-vscode.git"]'
                ;;
            *"python"*)
                suggested_extensions='["ms-python.python", "ms-python.vscode-pylance", "ms-vscode.vscode-json", "ms-vscode.git"]'
                ;;
            *"java"*)
                suggested_extensions='["redhat.java", "vscjava.vscode-java-pack", "ms-vscode.vscode-json", "ms-vscode.git"]'
                ;;
            *"rust"*)
                suggested_extensions='["rust-lang.rust", "ms-vscode.vscode-json", "ms-vscode.git"]'
                ;;
            *)
                suggested_extensions='["ms-vscode.vscode-json", "ms-vscode.git"]'
                ;;
        esac

        echo "Suggested extensions for this project type:"
        echo "$suggested_extensions" | jq -r '.[]'
        echo ""
        read -r -p "Add additional extensions (comma-separated) []: " additional_extensions

        # Build final extensions array
        all_extensions_array=$(echo "$suggested_extensions" | jq '.')
        if [ -n "$additional_extensions" ]; then
            IFS=',' read -ra additional_exts <<< "$additional_extensions"
            for ext in "${additional_exts[@]}"; do
                ext=$(echo "$ext" | xargs)  # trim whitespace
                all_extensions_array=$(echo "$all_extensions_array" | jq ". + [\"$ext\"]")
            done
        fi

        # Remove duplicates
        all_extensions_array=$(echo "$all_extensions_array" | jq 'unique')

        # Ask for VS Code settings
        if [ -t 0 ] && [ -t 1 ]; then
            read -r -p "Would you like to add VS Code settings? (y/N): " add_vscode_settings
            add_vscode_settings=${add_vscode_settings:-N}
            if [[ "$add_vscode_settings" =~ ^[Yy] ]]; then
                # For now, we just use a basic terminal setting as an example
                # In a more advanced implementation, we could have an interactive settings editor
                read -r -p "Enter terminal shell for Linux (default: /bin/bash): " terminal_shell
                terminal_shell=${terminal_shell:-/bin/bash}
                vscode_settings_json="{\"terminal.integrated.shell.linux\": \"$terminal_shell\"}"
            fi
        fi
    else
        info "Skipping VS Code customizations"
    fi
    
    # Step 5: Apply configuration
    echo ""
    echo "🚀 Step 5: Creating Configuration"
    echo "----------------------------------------"
    
    if [[ "$selected_template_id" == custom:* ]]; then
        # Handle custom image
        local custom_image="${selected_template_id#custom:}"

        # Create devcontainer.json for custom image
        # Only include customizations if user requested them
        if [[ "$add_vscode_customizations" =~ ^[Yy] ]] && ([ "$(echo "$all_extensions_array" | jq length)" -gt 0 ] || [ "$vscode_settings_json" != "{}" ]); then
            if ! cat > .devcontainer/devcontainer.json << EOF
{
    "name": "$container_name",
    "image": "$custom_image",
    "workspaceFolder": "$workspace_folder",
    "remoteUser": "$remote_user",
    "containerUser": "$container_user",
    "customizations": {
        "vscode": {
            "extensions": $all_extensions_array,
            "settings": $vscode_settings_json
        }
    }
}
EOF
            then
                error_exit "Failed to create devcontainer.json file" "$EXIT_PERMISSION_ERROR"
            fi
        else
            # Create without VSCode customizations
            if ! cat > .devcontainer/devcontainer.json << EOF
{
    "name": "$container_name",
    "image": "$custom_image",
    "workspaceFolder": "$workspace_folder",
    "remoteUser": "$remote_user",
    "containerUser": "$container_user"
}
EOF
            then
                error_exit "Failed to create devcontainer.json file" "$EXIT_PERMISSION_ERROR"
            fi
        fi
        
    else
        # Use official template with devcontainer CLI
        if command -v devcontainer >/dev/null 2>&1; then
            info "Applying official template: $selected_template_id"
            
            if ! devcontainer templates apply \
                --workspace-folder "$PROJECT_DIR" \
                --template-id "$selected_template_id" \
                --features "$features_array" \
                --template-args "$template_args" \
                >/dev/null 2>&1; then
                
                error_exit "Failed to apply official template" "$EXIT_DEVCONTAINER_ERROR"
            fi
            
            # Enhance with our customizations using devcontainer CLI metadata (if user requested)
            if [[ "$add_vscode_customizations" =~ ^[Yy] ]] && [ -f ".devcontainer/devcontainer.json" ]; then
                # Use devcontainer CLI to enhance the configuration
                if command -v jq >/dev/null 2>&1; then
                    # Check if we have extensions or settings to add
                    local has_extensions=false
                    local has_settings=false

                    if [ "$(echo "$all_extensions_array" | jq length)" -gt 0 ]; then
                        has_extensions=true
                    fi

                    if [ "$vscode_settings_json" != "{}" ]; then
                        has_settings=true
                    fi

                    if [ "$has_extensions" = true ] || [ "$has_settings" = true ]; then
                        # Get current configuration
                        local current_config
                        current_config=$(cat .devcontainer/devcontainer.json)

                        # Add customizations based on what's requested
                        local updated_config="$current_config"

                        if [ "$has_extensions" = true ]; then
                            updated_config=$(echo "$updated_config" | jq '.customizations = (.customizations // {}) | .customizations.vscode = (.customizations.vscode // {}) | .customizations.vscode.extensions = ((.customizations.vscode.extensions // []) + '"$all_extensions_array"' | unique)')
                        fi

                        if [ "$has_settings" = true ]; then
                            updated_config=$(echo "$updated_config" | jq '.customizations = (.customizations // {}) | .customizations.vscode = (.customizations.vscode // {}) | .customizations.vscode.settings = (.customizations.vscode.settings // {} * '"$vscode_settings_json"')')
                        fi

                        # Write updated configuration
                        echo "$updated_config" > .devcontainer/devcontainer.json
                    fi
                fi
            fi
        else
            error_exit "devcontainer CLI not found. Please install it with: brew install devcontainer" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi
    
    # Add our enhancement comment
    if [ -f ".devcontainer/devcontainer.json" ]; then
        # Just update the file without adding comments to JSON
        local temp_file=".devcontainer/devcontainer.json.tmp"
        cp .devcontainer/devcontainer.json "$temp_file"
        mv "$temp_file" .devcontainer/devcontainer.json
        
        # Sanitize features entries to avoid numeric keys like ghcr.io/devcontainers/features/2
        sanitize_features_json
        
        # Validate the configuration using devcontainer CLI - required dependency
        if ! devcontainer read-configuration --workspace-folder "$PROJECT_DIR" --config ".devcontainer/devcontainer.json" >/dev/null 2>&1; then
            warning "Generated configuration may have issues. You can validate it with: devcontainer read-configuration --workspace-folder $PROJECT_DIR"
        fi
        
        success "Devcontainer configuration created with wizard"
        
        # Offer to start the container
        if [ -t 0 ] && [ -t 1 ]; then
            echo ""
            read -r -p "Ready to start your development environment? (Y/n): " start_now
            start_now=${start_now:-Y}
            if [[ "$start_now" =~ ^[Yy] ]]; then
                info "Starting devcontainer..."
                if command -v devcontainer_up >/dev/null 2>&1; then
                    devcontainer_up
                    return 0
                fi
            fi
        fi
        
        info "Run 'dcutil up' to start the container"
    else
        error_exit "Failed to generate devcontainer configuration" "$EXIT_CONFIG_ERROR"
    fi
}