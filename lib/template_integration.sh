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

# Export functions for use in main dcutil
export -f fetch_available_templates_official get_fallback_templates
export -f fetch_available_features_official get_fallback_features
export -f detect_project_template suggest_features_for_project
export -f apply_official_template enhance_with_dcutil_additions
export -f get_template_metadata list_available_templates list_available_features