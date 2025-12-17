#!/usr/bin/env bash
#!/usr/bin/env bash
#!/usr/bin/env bash
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
        template_dirs=$(curl "${DEFAULT_CURL_OPTS[@]}" "$api_url" | jq -r '.[] | select(.type == "dir") | .name' 2>/dev/null || echo "")

        if [ -n "$template_dirs" ]; then
            templates_json="["
            local first=true
            for template in $template_dirs; do
                local template_url="https://raw.githubusercontent.com/devcontainers/templates/main/src/${template}/devcontainer-template.json"
                local template_info=""
                template_info=$(curl "${DEFAULT_CURL_OPTS[@]}" "$template_url" 2>/dev/null || true)
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

# Interactive template selection with numbered menu
select_template_interactive() {
    local templates_json="$1"
    local auto_select="${2:-}" # Optional: auto-select a specific template ID

    if ! command -v jq >/dev/null 2>&1; then
        # Fallback if jq is not available
        return 1
    fi

    # Count the number of templates
    local template_count
    template_count=$(echo "$templates_json" | jq 'length')

    if [ "$template_count" -eq 0 ]; then
        echo "No templates available."
        return 1
    fi

    # If auto-select is provided and valid, just return that without interaction
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
        echo "Auto-selected template not found: $auto_select"
        return 1
    fi

    echo "Available templates:"
    echo "---------------------"

    # Display templates with numbers
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

    if [ "$selection" = "0" ]; then
        return 1  # User cancelled selection
    fi

    # Validate selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$template_count" ]; then
        local selected_idx=$((selection - 1))
        user_selected_template=$(echo "$templates_json" | jq -r ".[$selected_idx].id")
        if [ "$user_selected_template" != "null" ] && [ -n "$user_selected_template" ]; then
            return 0  # Success
        fi
    fi

    echo "Invalid selection."
    return 1
}

# Interactive feature selection with categorized menu
select_features_interactive() {
    local features_json="$1"
    local auto_select="${2:-}" # Optional: comma-separated list of feature IDs to auto-select

    if ! command -v jq >/dev/null 2>&1; then
        # Fallback if jq is not available
        return 1
    fi

    # Count the number of features
    local features_count
    features_count=$(echo "$features_json" | jq 'length')
    # Ensure features_count is a valid integer to avoid arithmetic errors when features_json is empty
    features_count=${features_count:-0}

    if [ "$features_count" -eq 0 ]; then
        echo "No features available."
        return 1
    fi

    # If auto-select is provided, just return those without interaction
    if [ -n "$auto_select" ]; then
        user_selected_features=""
        IFS=',' read -ra auto_features <<< "$auto_select"
        for feature_name in "${auto_features[@]}"; do
            feature_name=$(echo "$feature_name" | xargs)  # trim whitespace
            local found=false
            local i=0
            while [ $i -lt "$features_count" ]; do
                local id
                id=$(echo "$features_json" | jq -r ".[$i].id" 2>/dev/null)
                if [ "$id" = "$feature_name" ]; then
                    if [ -z "$user_selected_features" ]; then
                        user_selected_features="$id"
                    else
                        user_selected_features="$user_selected_features,$id"
                    fi
                    found=true
                    break
                fi
                i=$((i + 1))
            done
            if [ "$found" = false ]; then
                echo "Auto-selected feature not found: $feature_name"
                return 1
            fi
        done
        return 0
    fi

    # Initialize user selection variables
    user_selected_features=""

    echo "Available features (select multiple using space-separated numbers):"
    echo "----------------------------------------"

    # Display features with numbers in a paginated way to avoid wall of text
    local i=1
    local page=1
    local page_size=10
    local start_idx=0
    local end_idx=$((start_idx + page_size))

    while [ $start_idx -lt "$features_count" ]; do
        echo "Page $page of $(((features_count + page_size - 1) / page_size)):"
        echo "----------------------------------------"

        local display_end_idx=$end_idx
        if [ $display_end_idx -gt "$features_count" ]; then
            display_end_idx=$features_count
        fi

        local display_idx=$start_idx
        while [ $display_idx -lt "$display_end_idx" ]; do
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
            "n"|"next")
                if [ $end_idx -lt "$features_count" ]; then
                    start_idx=$end_idx
                    end_idx=$((start_idx + page_size))
                    page=$((page + 1))
                else
                    echo "Already at the last page."
                fi
                ;;
            "p"|"prev"|"previous")
                if [ $start_idx -gt 0 ]; then
                    end_idx=$start_idx
                    start_idx=$((start_idx - page_size))
                    if [ $start_idx -lt 0 ]; then
                        start_idx=0
                    fi
                    page=$((page - 1))
                    if [ $page -lt 1 ]; then
                        page=1
                    fi
                    end_idx=$((start_idx + page_size))
                else
                    echo "Already at the first page."
                fi
                ;;
            "s"|"select")
                echo "Enter space-separated numbers of features to select:"
                read -r selections
                for sel in $selections; do
                    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "$features_count" ]; then
                        local idx=$((sel - 1))
                        local feature_id
                        feature_id=$(echo "$features_json" | jq -r ".[$idx].id" 2>/dev/null)
                        if [ "$feature_id" != "null" ] && [ -n "$feature_id" ]; then
                            if [ -z "$user_selected_features" ]; then
                                user_selected_features="$feature_id"
                            else
                                user_selected_features="$user_selected_features,$feature_id"
                            fi
                        fi
                    else
                        echo "Invalid selection: $sel"
                    fi
                done

                if [ -n "$user_selected_features" ]; then
                    echo "Selected features: $user_selected_features"
                    read -r -p "Continue with these selections? (Y/n): " confirm
                    confirm=${confirm:-Y}
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        return 0  # Success
                    fi
                fi
                ;;
            "q"|"quit"|"c"|"cancel")
                return 1  # User cancelled
                ;;
            *)
                # Process if user entered direct numbers
                local valid_input=true
                for sel in $choice; do
                    if ! [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" != "n" ] && [ "$sel" != "p" ] && [ "$sel" != "q" ]; then
                        valid_input=false
                        break
                    fi
                done

                if [ "$valid_input" = true ]; then
                    # User entered numbers directly
                    for sel in $choice; do
                        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "$features_count" ]; then
                            local idx=$((sel - 1))
                            local feature_id
                            feature_id=$(echo "$features_json" | jq -r ".[$idx].id" 2>/dev/null)
                            if [ "$feature_id" != "null" ] && [ -n "$feature_id" ]; then
                                if [ -z "$user_selected_features" ]; then
                                    user_selected_features="$feature_id"
                                else
                                    user_selected_features="$user_selected_features,$feature_id"
                                fi
                            fi
                        else
                            echo "Invalid selection: $sel"
                        fi
                    done

                    if [ -n "$user_selected_features" ]; then
                        echo "Selected features: $user_selected_features"
                        read -r -p "Continue with these selections? (Y/n): " confirm
                        confirm=${confirm:-Y}
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            return 0  # Success
                        fi
                    fi
                else
                    echo "Invalid option. Please enter 'n', 'p', 's', 'q', or feature numbers."
                fi
                ;;
        esac
    done

    if [ -n "$user_selected_features" ]; then
        return 0  # Success
    else
        return 1  # User cancelled or no features selected
    fi
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
    trap 'rm -f "${temp_file:-}"' RETURN EXIT INT TERM

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

    # Run jq transformation: detect numeric keys and map to pref array
    # Handle both pure numeric keys (like "1") and registry+numeric keys (like "ghcr.io/devcontainers/features/2")
    jq --argjson pref "$features_json" '
        def mapkey(k):
            # First, check if k is purely numeric (like "1", "2", etc.)
            if k | test("^[0-9]+$") then
                (k | tonumber - 1) as $i
                | ($pref[$i].id // "") as $fid
                | ($pref[$i].registry // "ghcr.io/devcontainers/features") as $fr
                | if $fid == "" then k else ($fr + "/" + $fid) end
            # Then check if k is in registry+numeric format (like "ghcr.io/devcontainers/features/2")
            elif k | test("^ghcr.io/devcontainers/features/[0-9]+(:.*)?$") then
                (k | capture("^ghcr.io/devcontainers/features/(?<idx>[0-9]+)(?<rest>[:].*)?$") ) as $m
                | ($m.idx | tonumber - 1) as $i
                | ($pref[$i].id // "") as $fid
                | ($pref[$i].registry // "ghcr.io/devcontainers/features") as $fr
                | if $fid == "" then k else ($fr + "/" + $fid + ($m.rest // "")) end
            else k end;
        .features = (.features // {} | to_entries | map(.key = mapkey(.key)) | from_entries)
    ' "$dev_file" > "$temp_file" && mv "$temp_file" "$dev_file"
}

# ------------------------------------------------------------------
# SSH propagation management (top-level functions)
# These need to be available whenever the library is sourced so the
# main `dcutil ssh` commands can call them directly. They were
# previously defined inside the interactive wizard function which meant
# they were only created when the wizard ran.
# ------------------------------------------------------------------

# Function to enable SSH propagation in existing configuration
enable_ssh_propagation() {
    local dev_file="${1:-.devcontainer/devcontainer.json}"

    if [ ! -f "$dev_file" ]; then
        error "No devcontainer.json found at $dev_file"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        error "jq is required to modify the configuration"
        return 1
    fi

    # Check if SSH is already enabled (any occurrence of ssh-agent.sock in runArgs)
    if jq -e '(.runArgs // []) | join(" ") | test("ssh-agent.sock")' "$dev_file" >/dev/null 2>&1; then
        info "SSH propagation is already enabled"
        return 0
    fi

    # Add SSH propagation - append to existing runArgs if present instead of replacing
    local temp_file="$dev_file.tmp"
    # Use jq to ensure we preserve existing runArgs and avoid creating duplicates
    jq '(.runArgs // []) as $r | .runArgs = ($r + ["--volume", "${SSH_AUTH_SOCK:-/tmp/ssh-agent.sock}:/ssh-agent.sock", "--env", "SSH_AUTH_SOCK=/ssh-agent.sock"])' "$dev_file" > "$temp_file" && mv "$temp_file" "$dev_file"

    success "SSH propagation enabled"
    info "SSH keys and agent will now be accessible inside the container"
}


# Function to disable SSH propagation in existing configuration
disable_ssh_propagation() {
    local dev_file="${1:-.devcontainer/devcontainer.json}"

    if [ ! -f "$dev_file" ]; then
        error "No devcontainer.json found at $dev_file"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        error "jq is required to modify the configuration"
        return 1
    fi

    # Check if SSH is already disabled (no ssh-agent.sock anywhere in runArgs)
    if ! jq -e '(.runArgs // []) | join(" ") | test("ssh-agent.sock")' "$dev_file" >/dev/null 2>&1; then
        info "SSH propagation is already disabled"
        return 0
    fi

    # Remove SSH propagation - remove volume/env entries and their paired flags
    local temp_file="$dev_file.tmp"

    # Read existing runArgs into a bash array (safe with jq)
    mapfile -t existing_args < <(jq -r '.runArgs // [] | .[]' "$dev_file")

    # Build new args array by skipping --volume <ssh-agent> and --env SSH_AUTH_SOCK pairs
    new_args=()
    i=0
    while [ $i -lt ${#existing_args[@]} ]; do
        item="${existing_args[$i]}"
        next_index=$((i + 1))
        next_item="${existing_args[$next_index]:-}"

        if [ "$item" = "--volume" ] && [[ "$next_item" =~ ssh-agent.sock ]]; then
            i=$((i + 2))
            continue
        fi

        if [ "$item" = "--env" ] && [ "$next_item" = "SSH_AUTH_SOCK=/ssh-agent.sock" ]; then
            i=$((i + 2))
            continue
        fi

        if [[ "$item" =~ ssh-agent.sock ]] || [ "$item" = "SSH_AUTH_SOCK=/ssh-agent.sock" ]; then
            i=$((i + 1))
            continue
        fi

        new_args+=("$item")
        i=$((i + 1))
    done

    # Persist new args back into the JSON file
    # Convert bash array to JSON array safely using jq
    if [ ${#new_args[@]} -eq 0 ]; then
        # remove runArgs entirely if nothing left
        jq 'del(.runArgs)' "$dev_file" > "$temp_file" && mv "$temp_file" "$dev_file"
    else
        jq --argjson new_args "$(printf '%s
' "${new_args[@]}" | jq -R . | jq -s .)" '.runArgs = $new_args' "$dev_file" > "$temp_file" && mv "$temp_file" "$dev_file"
    fi

    success "SSH propagation disabled"
    info "SSH keys and agent will no longer be accessible inside the container"
}


# Function to check SSH propagation status
check_ssh_propagation_status() {
    local dev_file="${1:-.devcontainer/devcontainer.json}"

    if [ ! -f "$dev_file" ]; then
        echo "❌ No devcontainer.json found"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "❌ jq is required to check the configuration"
        return 1
    fi

    if jq -e '(.runArgs // []) | join(" ") | test("ssh-agent.sock")' "$dev_file" >/dev/null 2>&1; then
        echo "✅ SSH propagation is ENABLED"
        return 0
    else
        echo "❌ SSH propagation is DISABLED"
        return 1
    fi
}


# Function to toggle SSH propagation


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

    # In CI or when DCUTIL_NONINTERACTIVE (or the legacy DCUTIL_DISABLE_DIALOG) is set, auto-accept detected template to avoid blocking
    if [ -t 0 ] && [ -t 1 ] && [ -z "${CI:-}" ] && [ -z "${DCUTIL_NONINTERACTIVE:-}" ] && [ -z "${DCUTIL_DISABLE_DIALOG:-}" ]; then
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
            # Interactive template selection with numbered menu
            if select_template_interactive "$templates_json"; then
                selected_template_id="ghcr.io/devcontainers/templates/$user_selected_template"
            else
                # Fallback if user cancels or there's an error
                read -r -p "Enter template ID [ubuntu]: " user_template
                user_template=${user_template:-ubuntu}
                selected_template_id="ghcr.io/devcontainers/templates/$user_template"
            fi
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

    # Interactive feature selection with categorized menu
    if [ -n "${CI:-}" ] || [ -n "${DCUTIL_NONINTERACTIVE:-}" ] || [ -n "${DCUTIL_DISABLE_DIALOG:-}" ]; then
        # In CI/non-interactive mode, auto-select sensible defaults
        if select_features_interactive "$features_json" "git,common-utils"; then
            features_input="$user_selected_features"
        else
            features_input="git,common-utils"
        fi
    else
        if select_features_interactive "$features_json"; then
            # Use the selected features from the interactive selection
            features_input="$user_selected_features"
        else
            # Fallback to original comma-separated input
            echo "Available features:"
            echo "$features_json" | jq -r '.[] | "  \(.id) (\(.registry)): \(.name) - \(.description)"'
            echo ""
            echo "Enter comma-separated feature IDs to include [git,common-utils]: "
            read -r features_input
            features_input=${features_input:-"git,common-utils"}
        fi
    fi

    # Build features array (normalize IDs to canonical registry paths)
    local features_array="[]"
    if [ -n "$features_input" ]; then
        IFS=',' read -ra feature_ids <<< "$features_input"
        for feature_id in "${feature_ids[@]}"; do
            feature_id=$(echo "$feature_id" | xargs)  # trim whitespace
            if [ -n "$feature_id" ]; then
                # Default to ghcr.io/devcontainers/features registry
                local full_id="$feature_id"
                if [[ "$feature_id" != ghcr.io/* ]] && [[ "$feature_id" != "custom:"* ]]; then
                    full_id="ghcr.io/devcontainers/features/$feature_id"
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

    # Use interactive reads only when both stdin/stdout are TTY and not running in CI/non-interactive mode
    if [ -t 0 ] && [ -t 1 ] && [ -z "${CI:-}" ] && [ -z "${DCUTIL_NONINTERACTIVE:-}" ]; then
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
    echo "🔐 Step 4: SSH Configuration"
    echo "----------------------------------------"

    # Ask if user wants SSH propagation (SECURITY: Default to OFF)
    if [ -t 0 ] && [ -t 1 ]; then
        echo "SSH propagation allows your host SSH keys and agent to be accessible inside the container."
        echo "This is convenient but has security implications."
        echo ""
        # Prompt only in fully interactive sessions
        if [ -t 0 ] && [ -t 1 ] && [ -z "${CI:-}" ] && [ -z "${DCUTIL_NONINTERACTIVE:-}" ]; then
            read -r -p "Enable SSH propagation? (y/N): " enable_ssh_propagation
            enable_ssh_propagation=${enable_ssh_propagation:-N}
        else
            enable_ssh_propagation="n"
        fi
    fi

    # Step 5: VS Code customizations
    echo ""
    echo "📦 Step 5: VS Code Customizations"
    echo "----------------------------------------"

    # Ask if user wants to add VS Code customizations (only in fully interactive non-CI sessions)
    if [ -t 0 ] && [ -t 1 ] && [ -z "${CI:-}" ] && [ -z "${DCUTIL_NONINTERACTIVE:-}" ]; then
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
    echo "🚀 Step 6: Creating Configuration"
    echo "----------------------------------------"

    if [[ "$selected_template_id" == custom:* ]]; then
        # Handle custom image
        local custom_image="${selected_template_id#custom:}"

        # Create devcontainer.json for custom image
        # Build base configuration
        local base_config="{\"name\": \"$container_name\", \"image\": \"$custom_image\", \"workspaceFolder\": \"$workspace_folder\", \"remoteUser\": \"$remote_user\", \"containerUser\": \"$container_user\"}"

        # Add SSH propagation if enabled
        if [[ "$enable_ssh_propagation" =~ ^[Yy] ]]; then
            base_config=$(echo "$base_config" | jq '. + {"runArgs": ["--volume", "${SSH_AUTH_SOCK:-/tmp/ssh-agent.sock}:/ssh-agent.sock", "--env", "SSH_AUTH_SOCK=/ssh-agent.sock"]}')
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
                    # Get current configuration
                    local current_config
                    current_config=$(cat .devcontainer/devcontainer.json)
                    local updated_config="$current_config"

                    # Add SSH propagation if enabled
                    if [[ "$enable_ssh_propagation" =~ ^[Yy] ]]; then
                        info "Adding SSH propagation to configuration"
                        # Append runArgs while preserving any existing runArgs
                        updated_config=$(echo "$updated_config" | jq '(.runArgs // []) as $r | .runArgs = ($r + ["--volume", "${SSH_AUTH_SOCK:-/tmp/ssh-agent.sock}:/ssh-agent.sock", "--env", "SSH_AUTH_SOCK=/ssh-agent.sock"])')
                    else
                        info "SSH propagation disabled"
                    fi

                    # Only add VS Code customizations if user requested them
                    if [[ "$add_vscode_customizations" =~ ^[Yy] ]]; then
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
                            if [ "$has_extensions" = true ]; then
                                updated_config=$(echo "$updated_config" | jq --argjson ext "$all_extensions_array" '.customizations = (.customizations // {}) | .customizations.vscode = (.customizations.vscode // {}) | .customizations.vscode.extensions = ((.customizations.vscode.extensions // []) + $ext | unique)')
                            fi

                            if [ "$has_settings" = true ]; then
                                updated_config=$(echo "$updated_config" | jq --argjson settings "$vscode_settings_json" '.customizations = (.customizations // {}) | .customizations.vscode = (.customizations.vscode // {}) | .customizations.vscode.settings = (.customizations.vscode.settings // {} * $settings)')
                            fi
                        fi
                    fi

                    # Write updated configuration
                    local temp_file=".devcontainer/devcontainer.json.tmp"
                    echo "$updated_config" > "$temp_file"
                    mv "$temp_file" .devcontainer/devcontainer.json
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
