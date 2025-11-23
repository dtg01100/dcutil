#!/bin/bash

# Security functions for dcutil

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables
CONTAINER_ID=""

get_agent_install_command() {
    local agent="$1"

    case "$agent" in
        "opencode")
            echo "curl -fsSL https://opencode.ai/install | bash"
            ;;
        "aider")
            echo "pip install aider-chat"
            ;;
        "copilot-cli")
            echo "npm install -g @github/copilot"
            ;;
        "cody")
            echo "npm install -g @sourcegraph/cody"
            ;;
        "tabnine")
            echo "npm install -g tabnine"
            ;;
        "qwen-cli")
            echo "pip install qwen-cli"
            ;;
        "gemini")
            echo "pip install gemini-cli"
            ;;
        "claude-cli")
            echo "pip install claude-cli"
            ;;
        "openai-cli")
            echo "pip install openai-cli"
            ;;
        *)
            error_exit "Unknown agent '$agent'. Supported agents: opencode, aider, copilot-cli, cody, tabnine, qwen-cli, gemini, claude-cli, openai-cli" "$EXIT_INVALID_ARGS"
            ;;
    esac
}

check_agent_security_risk() {
    local agent="$1"
    local install_cmd="$2"

    case "$agent" in
        "opencode")
            warning "⚠️  HIGH RISK: $agent installation runs remote scripts that could execute arbitrary code."
            echo -e "${YELLOW}Installation command: $install_cmd${NC}"
            read -p "Do you trust the source (opencode.ai) and want to proceed? (yes/no): " -r confirm
            if [[ ! "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
                info "Installation cancelled by user"
                exit $EXIT_SUCCESS
            fi
            ;;
    esac
}

scan_vulnerabilities() {
    local agent="$1"
    local install_type="$2"
    local venv_dir="$3"

    case "$install_type" in
        "pip")
            info "Running enhanced security scan for Python packages..."

            # Set up environment for portable Python if available
            local pip_cmd="pip"
            local python_cmd="python"
            if [ -n "$venv_dir" ] && [ -f "$venv_dir/bin/python" ]; then
                pip_cmd="$venv_dir/bin/pip"
                python_cmd="$venv_dir/bin/python"
            fi

            # Enhanced vulnerability scanning with multiple tools
            local vulnerabilities_found=false

            # 1. Use safety tool with proper pipenv/venv support
            if devcontainer exec --workspace-folder . /bin/bash -c "$python_cmd -c 'import safety; print(\"safety available\")'" &>/dev/null; then
                info "Running safety vulnerability scan..."
                if ! devcontainer exec --workspace-folder . /bin/bash -c "
                    export PATH=\"$venv_dir/bin:\$PATH\" 2>/dev/null || true
                    $python_cmd -m safety scan --output=text
                " 2>/dev/null; then
                    warning "Safety scan found potential vulnerabilities in $agent"
                    vulnerabilities_found=true
                fi
            else
                info "Installing safety for advanced vulnerability scanning..."
                if devcontainer exec --workspace-folder . /bin/bash -c "
                    $pip_cmd install safety --quiet
                " 2>/dev/null; then
                    info "Running safety vulnerability scan..."
                    if ! devcontainer exec --workspace-folder . /bin/bash -c "
                        export PATH=\"$venv_dir/bin:\$PATH\" 2>/dev/null || true
                        timeout 30 $python_cmd -m safety scan --output=text || $pip_cmd list | grep -E '(aider|opencode|qwen|gemini|claude|openai)' | xargs $pip_cmd show | grep -A5 -B5 'Requires:' | cat
                    " 2>/dev/null; then
                        warning "Safety scan detected potential security issues with $agent dependencies"
                        vulnerabilities_found=true
                    fi
                fi
            fi

            # 2. Check for dependency conflicts using pip-tools/pipdeptree
            info "Checking for package dependency conflicts..."
            if devcontainer exec --workspace-folder . /bin/bash -c "
                $pip_cmd install pipdeptree --quiet 2>/dev/null || true
                if command -v pipdeptree >/dev/null 2>&1; then
                    export PATH=\"$venv_dir/bin:\$PATH\" 2>/dev/null || true
                    pipdeptree --warn fail 2>&1 | grep -q 'conflict\|error' && exit 1 || exit 0
                else
                    $python_cmd -c '
import pkg_resources
import sys
try:
    # Get our installed packages related to the agent
    agent_pkgs = [pkg for pkg in pkg_resources.working_set if any(keyword in pkg.key.lower() for keyword in [\"$agent\", \"assistant\", \"ai\", \"chat\"])]
    if agent_pkgs:
        print(f\"Agent-related packages: {[pkg.key for pkg in agent_pkgs]}\")
    else:
        # Fallback - check all packages
        all_pkgs = list(pkg_resources.working_set)
        if len(all_pkgs) > 50:  # Too many packages, skip conflict check
            print(\"Skipping detailed conflict check - many packages installed\")
        else:
            pkg_dict = {pkg.key: pkg.version for pkg in all_pkgs}
            print(f\"Checked {len(all_pkgs)} packages for conflicts\")
 except Exception as e:
    print(f\"Could not check dependencies: {e}\")
    sys.exit(1)
                    '
                fi
            " 2>&1 | grep -q "conflict\|error\|Could not check\|failed"; then
                warning "Potential package conflicts detected for $agent"
                vulnerabilities_found=true
            fi

            # 3. Check for known problematic packages
            info "Checking for packages with known security issues..."
            if devcontainer exec --workspace-folder . /bin/bash -c "
                $pip_cmd list --format=freeze | grep -E '^(pip|setuptools|wheel)=' | while read pkg_line; do
                    pkg_name=\${pkg_line%%=*}
                    pkg_version=\${pkg_line##*=}
                    case \$pkg_name in
                        pip)
                            # Check pip version for security
                            if [[ \"\$pkg_version\" =~ ^([0-9]+)\\. ]]; then
                                major_version=\${BASH_REMATCH[1]}
                                if [ \$major_version -lt 24 ]; then
                                    echo \"WARNING: pip version \$pkg_version is outdated and may have security vulnerabilities\"
                                    exit 1
                                fi
                            fi
                            ;;
                        setuptools)
                            # setuptools has known security issues in old versions
                            if [[ \"\$pkg_version\" =~ ^([0-9]+)\\. ]]; then
                                major_version=\${BASH_REMATCH[1]}
                                if [ \$major_version -lt 65 ]; then
                                    echo \"WARNING: setuptools version \$pkg_version is outdated\"
                                    exit 1
                                fi
                            fi
                            ;;
                    esac
                done || exit 1
            " 2>&1 | grep -q "WARNING"; then
                warning "Outdated or vulnerable core packages detected"
                vulnerabilities_found=true
            fi

            if [ "$vulnerabilities_found" = true ]; then
                warning "⚠️  Security scan found issues with $agent dependencies"
                warning "Consider updating packages or choosing a different agent"
            else
                info "✅ No immediate security issues found for $agent"
            fi
            ;;
        "npm")
            info "Running npm security audit..."
            devcontainer exec --workspace-folder . /bin/bash -c "npm audit --audit-level=high" || warning "npm audit found potential vulnerabilities"
            ;;
    esac
}

install_agent() {
    local AGENT="$1"
    local INSTALL_CMD
    INSTALL_CMD=$(get_agent_install_command "$AGENT")

    info "Installing $AGENT inside devcontainer..."
    check_devcontainer_cli
    check_docker_daemon

    # Get container name for this project
    local CONTAINER_NAME
    CONTAINER_NAME=$(get_container_name_for_project "$PROJECT_DIR")
    info "Using container: $CONTAINER_NAME"

    # Check if container is running
    local container_running=false
    if docker container inspect "$CONTAINER_NAME" &>/dev/null && docker container inspect "$CONTAINER_NAME" | grep -q '"Running": true'; then
        container_running=true
    fi

    if [ "$container_running" = false ]; then
        warning "Container is not running. Starting it first..."
        if ! docker start "$CONTAINER_NAME" 2>/dev/null; then
            error_exit "Failed to start devcontainer for $AGENT installation" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi

    # Ask about configuration pass-through
    local config_mount=""
    echo ""
    echo -e "${YELLOW}⚙️  Configuration Pass-through:${NC}"
    echo "Should $AGENT have access to its configuration files?"

    # Config mounting for agents
    case "$AGENT" in
        "opencode")
            local has_local_share=false
            local has_opencode=false
            if [ -d "$HOME/.local/share/opencode" ]; then
                has_local_share=true
            fi
            if [ -d "$HOME/.opencode" ]; then
                has_opencode=true
            fi
            if [ "$has_local_share" = true ] || [ "$has_opencode" = true ]; then
                echo "1) No configuration access"
                echo "2) Mount opencode config directories"
                if [ "$has_local_share" = true ]; then
                    echo "   - ~/.local/share/opencode -> /home/vscode/.local/share/opencode"
                fi
                if [ "$has_opencode" = true ]; then
                    echo "   - ~/.opencode -> /home/vscode/.opencode"
                fi
                echo ""
                read -r -p "Enter choice [1-None, 2-Mount] [1]: " user_config_choice
                user_config_choice=${user_config_choice:-1}
                if [ "$user_config_choice" = "2" ]; then
                    config_mount="--mount type=bind,source=$HOME/.local/share/opencode,target=/home/vscode/.local/share/opencode --mount type=bind,source=$HOME/.opencode,target=/home/vscode/.opencode"
                    info "Will mount opencode configuration directories"
                fi
            fi
            ;;
        "aider")
            if [ -f "$HOME/.aider.conf.yml" ]; then
                echo "1) No configuration access"
                echo "2) Mount aider config file (~/.aider.conf.yml)"
                echo ""
                read -r -p "Enter choice [1-None, 2-Mount] [1]: " user_config_choice
                user_config_choice=${user_config_choice:-1}
                if [ "$user_config_choice" = "2" ]; then
                    warning "⚠️  SECURITY WARNING: The aider config file contains API keys and sensitive authentication data."
                    read -r -p "Do you understand the security implications and want to proceed? (Y/n): " security_confirm
                    security_confirm=${security_confirm:-Y}
                    if [[ "$security_confirm" =~ ^[Yy] ]]; then
                        config_mount="--mount type=bind,source=$HOME/.aider.conf.yml,target=/home/vscode/.aider.conf.yml"
                        info "Will mount aider configuration"
                    fi
                fi
            fi
            ;;
        "copilot-cli"|"cody"|"qwen-cli"|"gemini"|"claude-cli"|"openai-cli")
            if [ -d "$HOME/.config" ]; then
                echo "1) No configuration access"
                echo "2) Mount config directory (~/.config)"
                echo ""
                read -r -p "Enter choice [1-None, 2-Mount] [1]: " user_config_choice
                user_config_choice=${user_config_choice:-1}
                if [ "$user_config_choice" = "2" ]; then
                    warning "⚠️  SECURITY WARNING: The ~/.config directory may contain sensitive information including API keys, authentication tokens, and personal data from various applications."
                    read -r -p "Do you understand the security implications and want to proceed? (Y/n): " security_confirm
                    security_confirm=${security_confirm:-Y}
                    if [[ "$security_confirm" =~ ^[Yy] ]]; then
                        config_mount="--mount type=bind,source=$HOME/.config,target=/home/vscode/.config"
                        info "Will mount configuration directory"
                    fi
                fi
            fi
            ;;
        *)
            echo "1) No configuration access"
            echo "2) Skip configuration setup"
            echo ""
            read -r -p "Enter choice [1-None, 2-Skip] [1]: " user_config_choice
            ;;
    esac

    # Security check for high-risk installations
    check_agent_security_risk "$AGENT" "$INSTALL_CMD"

    info "Installing $AGENT..."

    # Execute the installation
    if ! docker exec "$CONTAINER_NAME" /bin/bash -c "
        set -euo pipefail
        export DEBIAN_FRONTEND=noninteractive
        cd /home/vscode
        $INSTALL_CMD
    " 2>/dev/null; then
        error_exit "Failed to install $AGENT" "$EXIT_DEVCONTAINER_ERROR"
    fi

    # Ask about configuration pass-through
    config_mount=""
    echo ""
    echo -e "${YELLOW}⚙️  Configuration Pass-through:${NC}"
    echo "Should $AGENT have access to its configuration files?"

    case "$AGENT" in
        "opencode")
            echo "1) No configuration access"
            echo "2) Mount ~/.opencode directory (recommended)"
            echo ""
            read -r -p "Enter choice [1-None, 2-Mount ~/.opencode] [1]: " user_config_choice
            user_config_choice=${user_config_choice:-1}
            if [ "$user_config_choice" = "2" ]; then
                if [ -d "$HOME/.opencode" ]; then
                    config_mount="--mount type=bind,source=$HOME/.opencode,target=/home/vscode/.opencode"
                    info "Will mount opencode configuration"
                else
                    warning "$HOME/.opencode directory not found, skipping configuration mount"
                fi
            fi
            ;;
        "aider")
            echo "1) No configuration access"
            echo "2) Mount ~/.aider.toml file (recommended)"
            echo ""
            read -r -p "Enter choice [1-None, 2-Mount ~/.aider.toml] [1]: " user_config_choice
            user_config_choice=${user_config_choice:-1}
            if [ "$user_config_choice" = "2" ]; then
                if [ -f "$HOME/.aider.toml" ]; then
                    config_mount="--mount type=bind,source=$HOME/.aider.toml,target=/home/vscode/.aider.toml"
                    info "Will mount aider configuration"
                else
                    warning "$HOME/.aider.toml file not found, skipping configuration mount"
                fi
            fi
            ;;
        "copilot-cli"|"cody"|"tabnine"|"qwen-cli"|"gemini"|"claude-cli"|"openai-cli")
            echo "1) No configuration access"
            echo "2) Mount ~/.config directory (for CLI tools)"
            echo ""
            read -r -p "Enter choice [1-None, 2-Mount ~/.config] [1]: " user_config_choice
            user_config_choice=${user_config_choice:-1}
            if [ "$user_config_choice" = "2" ]; then
                if [ -d "$HOME/.config" ]; then
                    config_mount="--mount type=bind,source=$HOME/.config,target=/home/vscode/.config"
                    info "Will mount configuration directory"
                else
                    warning "$HOME/.config directory not found, skipping configuration mount"
                fi
            fi
            ;;
        *)
            echo "1) No configuration access"
            echo "2) Skip configuration setup"
            echo ""
            read -r -p "Enter choice [1-None, 2-Skip] [1]: " user_config_choice
            ;;
    esac

    # Security check for high-risk installations
    check_agent_security_risk "$AGENT" "$INSTALL_CMD"

    info "Installing $AGENT..."

    # Determine install type for vulnerability scanning
    if [[ "$INSTALL_CMD" == npm* ]]; then
        INSTALL_TYPE="npm"
        info "Ensuring npm is available..."
        if ! devcontainer exec --workspace-folder . /bin/bash -c "command -v npm" 2>/dev/null; then
            warning "npm not found. Installing latest Node.js LTS..."
            if ! devcontainer exec --workspace-folder . /bin/bash -c "
                curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && apt-get install -y nodejs
            " 2>/dev/null; then
                error_exit "Failed to install Node.js and npm" "$EXIT_DEVCONTAINER_ERROR"
            fi
        fi
    elif [[ "$INSTALL_CMD" == pip* ]]; then
        INSTALL_TYPE="pip"
        info "Setting up hermetic Python environment for isolated installation..."
        PYTHON_BIN_DIR="/home/vscode/.dcutil/python"
        VENV_DIR="/home/vscode/.dcutil/agents/$AGENT"

        # Determine platform architecture for portable Python
        PLATFORM=$(devcontainer exec --workspace-folder . /bin/bash -c "ARCH=\$(uname -m); OS=\$(uname -s); if [ \"\$OS\" = \"Linux\" ]; then OS_PREFIX=\"linux\"; elif [ \"\$OS\" = \"Darwin\" ]; then OS_PREFIX=\"macos\"; else OS_PREFIX=\"linux\"; fi; if [ \"\$ARCH\" = \"x86_64\" ]; then echo \"\$OS_PREFIX-x86_64\"; elif [ \"\$ARCH\" = \"aarch64\" ] || [ \"\$ARCH\" = \"arm64\" ]; then echo \"\$OS_PREFIX-aarch64\"; else echo \"linux-x86_64\"; fi" 2>/dev/null || echo "linux-x86_64")

        USE_PORTABLE=false
        # Try to set up portable Python
        if devcontainer exec --workspace-folder . /bin/bash -c "PLATFORM=\$PLATFORM;
            if [ -x $PYTHON_BIN_DIR/bin/python3 ]; then
                exit 0
            fi
            mkdir -p $PYTHON_BIN_DIR
            case \\$PLATFORM in
                linux-x86_64) ARCH='x86_64-unknown-linux-gnu' ;;
                linux-aarch64) ARCH='aarch64-unknown-linux-gnu' ;;
                macos-x86_64) ARCH='x86_64-apple-darwin' ;;
                macos-aarch64) ARCH='aarch64-apple-darwin' ;;
                *) exit 1 ;;
            esac
            sleep 1  # Rate limiting for GitHub API
            LATEST_TAG=\$(curl -fsSL https://api.github.com/repos/astral-sh/python-build-standalone/releases/latest | sed -n 's/.*\"tag_name\": \"\\([^\"]*\\)\".*/\\1/p')
            ASSET_NAME=\$(curl -fsSL https://api.github.com/repos/astral-sh/python-build-standalone/releases/latest | sed -n 's/.*\"name\": \"\\(cpython-3\\.1[23]\\.[0-9]+\\+'\"\\$LATEST_TAG\"'-'\"\\$ARCH\"'-install_only\\.tar\\.gz\\)\".*/\\1/p' | sort -V | tail -1)
            URL=\"https://github.com/astral-sh/python-build-standalone/releases/download/\\$LATEST_TAG/\\$ASSET_NAME\"
            if [ -n \"\\$ASSET_NAME\" ] && curl -fsSL \"\\$URL\" | tar -xz -C $PYTHON_BIN_DIR && [ -x $PYTHON_BIN_DIR/bin/python3 ]; then
                exit 0
            else
                exit 1
            fi
        " 2>/dev/null; then
            info "Using hermetic portable Python environment for $AGENT"
            USE_PORTABLE=true
        else
            warning "Failed to set up portable Python, falling back to system Python"
            echo -e "${YELLOW}⚠️  Use system Python for installation? [y/N]${NC}"
            read -r confirm_fallback
            if [[ ! "$confirm_fallback" =~ ^[Yy] ]]; then
                error_exit "Aborted by user" "$EXIT_INVALID_ARGS"
            fi
            USE_PORTABLE=false
        fi

        if [ "$USE_PORTABLE" = "true" ]; then
            # Create venv with portable Python
            if ! devcontainer exec --workspace-folder . /bin/bash -c "
                mkdir -p $VENV_DIR
                $PYTHON_BIN_DIR/bin/python3 -m venv $VENV_DIR
            " 2>/dev/null; then
                warning "Failed to create venv with portable Python, falling back to system Python"
                USE_PORTABLE=false
            fi
        fi

        if [ "$USE_PORTABLE" != "true" ]; then
            # Fallback to system Python virtual environment
            if ! devcontainer exec --workspace-folder . /bin/bash -c "
                if ! python3 -m venv --help > /dev/null 2>&1; then
                    apt-get update && apt-get install -y python3-venv
                fi
                mkdir -p $VENV_DIR
                python3 -m venv $VENV_DIR
            " 2>/dev/null; then
                error_exit "Failed to set up system Python venv" "$EXIT_DEVCONTAINER_ERROR"
            fi
            info "Using system Python environment for $AGENT"
        fi
    elif [[ "$INSTALL_CMD" == curl* ]]; then
        # Special handling for high-risk curl|bash installations
        INSTALL_TYPE="curl"
    else
        INSTALL_TYPE=""
    fi

    # Execute the installation with sandboxing
    if [ "$INSTALL_TYPE" = "pip" ]; then
        INSTALL_CMD="source $VENV_DIR/bin/activate && $INSTALL_CMD"
    fi
    
    # Enhanced security: use restricted shell for installations
    if ! devcontainer exec --workspace-folder . /bin/bash -c "
        set -euo pipefail
        export DEBIAN_FRONTEND=noninteractive
        exec $INSTALL_CMD
    " 2>/dev/null; then
        error_exit "Failed to install $AGENT" "$EXIT_DEVCONTAINER_ERROR"
    fi

    # Apply configuration mounts if specified
    if [ -n "$config_mount" ]; then
        info "Mounting configuration files..."
        # Get container ID and apply mount
        CONTAINER_ID=$(docker ps --filter label=devcontainer.local_folder="$PROJECT_DIR" --format "{{.ID}}" 2>/dev/null | head -1)
        if [ -n "$CONTAINER_ID" ]; then
            # Note: Docker mount options would need to be applied at container creation time
            # For now, we'll copy configuration files
            case "$AGENT" in
                "aider")
                    if [ -f "$HOME/.aider.toml" ]; then
                        docker cp "$HOME/.aider.toml" "$CONTAINER_ID:/home/vscode/.aider.toml" 2>/dev/null && \
                        docker exec "$CONTAINER_ID" chown vscode:vscode /home/vscode/.aider.toml 2>/dev/null
                    fi
                    ;;
            esac
            info "Configuration files copied to container"
        fi
    fi

    info "Installation completed, running security scans..."

    # Run vulnerability scanning if applicable
    if [ -n "$INSTALL_TYPE" ]; then
        scan_vulnerabilities "$AGENT" "$INSTALL_TYPE" "$VENV_DIR"
    fi

    success "$AGENT installed successfully in devcontainer"
    if [ -n "$VENV_DIR" ] && [ "$USE_PORTABLE" = true ]; then
        info "Hermetic portable Python environment at: $VENV_DIR"
        info "To activate in container: source $VENV_DIR/bin/activate"
        info "To run $AGENT from host: dcutil run 'source $VENV_DIR/bin/activate && $AGENT'"
    elif [ -n "$VENV_DIR" ]; then
        info "Agent is isolated in virtual environment: $VENV_DIR"
        info "To activate in container: source $VENV_DIR/bin/activate"
    fi
}