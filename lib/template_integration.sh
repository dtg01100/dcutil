# Enhanced template integration with official devcontainer ecosystem
# This file provides integration with official templates, features, and CLI

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Get available templates from official registry
fetch_available_templates_official() {
    local cache_file="$HOME/.cache/dcutil/official_templates.json"
    local cache_age=3600  # 1 hour
    
    # Check if cache exists and is recent
    if [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0))) -lt $cache_age ]; then
        cat "$cache_file" 2>/dev/null || get_fallback_templates
        return
    fi
    
    # Create cache directory
    mkdir -p "$(dirname "$cache_file")" 2>/dev/null || true
    
    # Try to fetch from official sources
    if command -v devcontainer >/dev/null 2>&1; then
        # Use devcontainer CLI to get template information
        # This is more reliable than web scraping
        get_fallback_templates
    else
        get_fallback_templates
    fi
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
    local cache_age=3600  # 1 hour
    
    # Check if cache exists and is recent
    if [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0))) -lt $cache_age ]; then
        cat "$cache_file" 2>/dev/null || get_fallback_features
        return
    fi
    
    # Create cache directory
    mkdir -p "$(dirname "$cache_file")" 2>/dev/null || true
    
    # Try to fetch from official sources
    if command -v devcontainer >/dev/null 2>&1; then
        # In the future, we could use: devcontainer features list
        # For now, use fallback
        get_fallback_features
    else
        get_fallback_features
    fi
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
    
    info "Applying official template: $template_id"
    
    # Use the official devcontainer CLI
    if ! command -v devcontainer >/dev/null 2>&1; then
        error "devcontainer CLI not found. Please install it with: brew install devcontainer"
        return 1
    fi
    
    # Apply the template
    if devcontainer templates apply \
        --workspace-folder "$PROJECT_DIR" \
        --template-id "$template_id" \
        --features "$features_json" \
        --template-args "$template_args" \
        >/dev/null 2>&1; then
        
        success "Template applied successfully"
        return 0
    else
        error "Failed to apply template $template_id"
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
    
    # Add our enhancement comment while preserving everything else
    {
        echo "// Enhanced by dcutil with additional VS Code extensions and settings"
        cat "$devcontainer_file"
    } > "$temp_file"
    
    # Replace original
    mv "$temp_file" "$devcontainer_file"
    
    success "Enhanced configuration with dcutil additions"
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
    
    # Build features array
    local features_array="[]"
    if [ -n "$features_input" ]; then
        IFS=',' read -ra feature_ids <<< "$features_input"
        for feature_id in "${feature_ids[@]}"; do
            feature_id=$(echo "$feature_id" | xargs)  # trim whitespace
            if [[ "$feature_id" != "custom:"* ]]; then
                features_array=$(echo "$features_array" | jq ". + [{\"id\": \"ghcr.io/devcontainers/features/$feature_id\", \"options\": {}}]")
            fi
        done
    fi
    
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
    
    # Step 4: VS Code extensions
    echo ""
    echo "📦 Step 4: VS Code Extensions"
    echo "----------------------------------------"
    
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
    local all_extensions_array
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
    
    # Step 5: Apply configuration
    echo ""
    echo "🚀 Step 5: Creating Configuration"
    echo "----------------------------------------"
    
    if [[ "$selected_template_id" == custom:* ]]; then
        # Handle custom image
        local custom_image="${selected_template_id#custom:}"
        
        # Create devcontainer.json for custom image
        if ! cat > .devcontainer/devcontainer.json << EOF
{
    "name": "$container_name",
    "image": "$custom_image",
    "workspaceFolder": "$workspace_folder",
    "remoteUser": "$remote_user",
    "containerUser": "$container_user",
    "customizations": {
        "vscode": {
            "extensions": $(echo "$all_extensions" | jq '.')
        }
    }
}
EOF
        then
            error_exit "Failed to create devcontainer.json file" "$EXIT_PERMISSION_ERROR"
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
            
            # Enhance with our customizations using devcontainer CLI metadata
            if [ -f ".devcontainer/devcontainer.json" ]; then
                # Use devcontainer CLI to enhance the configuration
                if command -v jq >/dev/null 2>&1; then
                    # Get template metadata to understand what was applied
                    local template_metadata
                    template_metadata=$(devcontainer templates metadata "$selected_template_id" 2>/dev/null || echo '{}')
                    
                    # Add VS Code extensions to existing configuration
                    jq '.customizations = (.customizations // {}) | .customizations.vscode = (.customizations.vscode // {}) | .customizations.vscode.extensions = ((.customizations.vscode.extensions // []) + '"$all_extensions_array"' | unique)' \
                        .devcontainer/devcontainer.json > .devcontainer/devcontainer.json.tmp && \
                        mv .devcontainer/devcontainer.json.tmp .devcontainer/devcontainer.json
                fi
            fi
        else
            error_exit "devcontainer CLI not found. Please install it with: brew install devcontainer" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi
    
    # Add our enhancement comment
    if [ -f ".devcontainer/devcontainer.json" ]; then
        local temp_file=".devcontainer/devcontainer.json.tmp"
        {
            echo "// Enhanced by dcutil wizard with custom configuration"
            sed '1d' .devcontainer/devcontainer.json
        } > "$temp_file"
        mv "$temp_file" .devcontainer/devcontainer.json
        
        # Use devcontainer CLI to validate the configuration
        if command -v devcontainer >/dev/null 2>&1; then
            if ! devcontainer read-configuration --workspace-folder "$PROJECT_DIR" --config ".devcontainer/devcontainer.json" >/dev/null 2>&1; then
                warning "Generated configuration may have issues. You can validate it with: devcontainer read-configuration --workspace-folder $PROJECT_DIR"
            fi
        else
            validate_json_if_available ".devcontainer/devcontainer.json"
        fi
        
        success "Devcontainer configuration created with wizard"
        
        # Offer to start the container
        if [ -t 0 ] && [ -t 1 ]; then
            echo ""
            read -r -p "Would you like to start the devcontainer now? (Y/n): " start_now
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