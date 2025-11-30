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

    # Create cache directory (if possible). If we can't create the cache directory
    # make a best-effort attempt but fall back to the static list so we don't
    # end up attempting network operations in environments that cannot write
    # to $HOME (CI or restricted shells). This avoids long network timeouts
    # or permission errors when $HOME is unwritable.
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
        template_dirs=$(curl -s "$api_url" | jq -r '.[] | select(.type == "dir") | .name' 2>/dev/null || echo "")

        if [ -n "$template_dirs" ]; then
            templates_json="["
            local first=true
            for template in $template_dirs; do
                local template_url="https://raw.githubusercontent.com/devcontainers/templates/main/src/${template}/devcontainer-template.json"
                local template_info=""
                template_info=$(curl -s "$template_url" 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$template_info" ]; then
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

    # Create cache directory (see note above for behavior in restricted environments)
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
