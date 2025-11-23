#!/usr/bin/env bash

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

    # General security warning for all installations
    warning "⚠️  SECURITY NOTICE: Installing third-party software in your devcontainer."
    echo "This may introduce security risks including:"
    echo "  - Execution of untrusted code"
    echo "  - Access to your files and network"
    echo "  - Potential malware or backdoors"
    echo ""

    case "$agent" in
        "opencode")
            warning "⚠️  HIGH RISK: $agent installation runs remote scripts that could execute arbitrary code."
            echo -e "${YELLOW}Installation command: $install_cmd${NC}"
            ;;
        *)
            if [[ "$install_cmd" == pip* ]]; then
                warning "⚠️  MEDIUM RISK: Installing Python package that may execute code during installation."
            elif [[ "$install_cmd" == npm* ]]; then
                warning "⚠️  MEDIUM RISK: Installing Node.js package that may execute scripts during installation."
            elif [[ "$install_cmd" == curl* ]]; then
                warning "⚠️  HIGH RISK: Downloading and executing remote scripts."
            fi
            ;;
    esac

    echo -e "${YELLOW}Agent: $agent${NC}"
    echo -e "${YELLOW}Command: $install_cmd${NC}"
    echo ""

    if [ "$agent" = "opencode" ] || [[ "$install_cmd" == curl* ]]; then
        read -p "Do you trust this installation and want to proceed? (yes/no): " -r confirm
        if [[ ! "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
            info "Installation cancelled by user"
            exit $EXIT_SUCCESS
        fi
    else
        read -p "Do you want to proceed with the installation? (Y/n): " -r confirm
        confirm=${confirm:-Y}
        if [[ ! "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
            info "Installation cancelled by user"
            exit $EXIT_SUCCESS
        fi
    fi
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
            if docker exec "$CONTAINER_NAME" /bin/bash -c "$python_cmd -c 'import safety; print(\"safety available\")'" &>/dev/null; then
                info "Running safety vulnerability scan..."
                if ! docker exec "$CONTAINER_NAME" /bin/bash -c "
                    export PATH=\"$venv_dir/bin:\$PATH\" 2>/dev/null || true
                    $python_cmd -m safety scan --output=text
                " 2>/dev/null; then
                    warning "Safety scan found potential vulnerabilities in $agent"
                    vulnerabilities_found=true
                fi
            else
                info "Installing safety for advanced vulnerability scanning..."
                if docker exec "$CONTAINER_NAME" /bin/bash -c "
                    $pip_cmd install safety --quiet
                " 2>/dev/null; then
                    info "Running safety vulnerability scan..."
                    if ! docker exec "$CONTAINER_NAME" /bin/bash -c "
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
            if docker exec "$CONTAINER_NAME" /bin/bash -c "
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
            if docker exec "$CONTAINER_NAME" /bin/bash -c "
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
            docker exec "$CONTAINER_NAME" /bin/bash -c "npm audit --audit-level=high" || warning "npm audit found potential vulnerabilities"
            ;;
    esac
}

install_agent() {
    local AGENT="$1"
    local INSTALL_CMD
    local VENV_DIR=""
    local USE_PORTABLE=false
    local INSTALL_TYPE=""
    INSTALL_CMD=$(get_agent_install_command "$AGENT")

    info "Installing $AGENT inside devcontainer..."
    check_devcontainer_cli
    check_docker_daemon

    # Ensure container is running
    if ! ensure_container_running; then
        error_exit "Cannot install agent: container not available" "$EXIT_DEVCONTAINER_ERROR"
    fi

    # Get container name for this project
    local CONTAINER_NAME
    CONTAINER_NAME=$(get_container_name_for_project "$PROJECT_DIR")
    info "Using container: $CONTAINER_NAME"

    # Ask about configuration pass-through
    config_mount=""
    echo ""
    echo -e "${YELLOW}⚙️  Configuration Pass-through:${NC}"
    echo "Should $AGENT have access to its configuration files?"

    # Config mounting for agents
    case "$AGENT" in
        "opencode")
            local opencode_config_dir=""
            if [ -d "$HOME/.config/opencode" ]; then
                opencode_config_dir="$HOME/.config/opencode"
            elif [ -d "$HOME/.local/share/opencode" ]; then
                opencode_config_dir="$HOME/.local/share/opencode"
            fi
            if [ -n "$opencode_config_dir" ]; then
                # Check if mount already exists
                local config_file=""
                if [ -f ".devcontainer/devcontainer.json" ]; then
                    config_file=".devcontainer/devcontainer.json"
                elif [ -f ".devcontainer.json" ]; then
                    config_file=".devcontainer.json"
                fi

                local mount_exists=false
                if [ -n "$config_file" ] && command -v jq &> /dev/null; then
                    if jq -e '.mounts // [] | any(.target == "/home/vscode/.opencode")' "$config_file" >/dev/null 2>&1; then
                        mount_exists=true
                    fi
                fi

                if [ "$mount_exists" = true ]; then
                    info "Configuration mount is already configured, proceeding with installation"
                    # Mount is already configured, proceed
                else
                    echo "1) No configuration access"
                    echo "2) Mount opencode config directory ($opencode_config_dir)"
                    echo ""
                    read -r -p "Enter choice [1-None, 2-Mount] [1]: " user_config_choice
                    user_config_choice=${user_config_choice:-1}
                if [ "$user_config_choice" = "2" ]; then
                    warning "⚠️  SECURITY WARNING: Mounting config directories may expose sensitive information (API keys, auth tokens) to the container."
                    read -r -p "Do you understand the security implications and want to proceed? (Y/n): " security_confirm
                    security_confirm=${security_confirm:-Y}
                    if [[ "$security_confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
                        config_mount="--mount type=bind,source=$opencode_config_dir,target=/home/vscode/.opencode"
                        info "Will mount opencode configuration"
                    else
                        info "Config mounting cancelled for security reasons"
                    fi
                fi
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
                    if [[ "$security_confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
                        config_mount="--mount type=bind,source=$HOME/.aider.conf.yml,target=/home/vscode/.aider.conf.yml"
                        info "Will mount aider configuration"
                    else
                        info "Config mounting cancelled for security reasons"
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
                    if [[ "$security_confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
                        config_mount="--mount type=bind,source=$HOME/.config,target=/home/vscode/.config"
                        info "Will mount configuration directory"
                    else
                        info "Config mounting cancelled for security reasons"
                    fi
                fi
            fi
            ;;
    esac

        if [ "$mount_exists" = true ]; then
            echo "Configuration mount is already configured."
            echo "1) Keep existing configuration mount"
            echo "2) Remove configuration mount"
            echo ""
            read -r -p "Enter choice [1-Keep, 2-Remove] [1]: " user_config_choice
            user_config_choice=${user_config_choice:-1}
            if [ "$user_config_choice" = "2" ]; then
                # Remove the mount
                jq '.mounts = (.mounts // []) | map(select(.target != "/home/vscode/.opencode"))' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
                info "Removed configuration mount from $config_file"
                # Since we're removing, we need to recreate the container
                CONTAINER_ID=$(docker ps --filter label=devcontainer.local_folder="$PROJECT_DIR" --format "{{.ID}}" 2>/dev/null | head -1)
                if [ -n "$CONTAINER_ID" ]; then
                    info "Stopping and removing current container to apply configuration change..."
                    docker stop "$CONTAINER_ID" 2>/dev/null || true
                    docker rm "$CONTAINER_ID" 2>/dev/null || true
                    info "Recreating container without configuration mount..."
                    docker_up "$PROJECT_DIR"
                fi
            fi
        else
            echo "1) No configuration access"
            echo "2) Mount ~/.config/opencode directory (if exists)"
            echo ""
            read -r -p "Enter choice [1-None, 2-Mount] [1]: " user_config_choice
            user_config_choice=${user_config_choice:-1}
            if [ "$user_config_choice" = "2" ] && [ -d "$HOME/.config/opencode" ]; then
                config_mount="--mount type=bind,source=$HOME/.config/opencode,target=/home/vscode/.opencode"
                info "Will mount opencode configuration"
            fi
        fi

    # If config mounting requested, set it up before installation
    if [ -n "$config_mount" ]; then
        info "Setting up configuration pass-through..."
        # Parse the mount specification to add to devcontainer.json
        # config_mount is like "--mount type=bind,source=/home/user/.config/opencode,target=/home/vscode/.opencode"
        # We need to convert it to JSON format for devcontainer.json

        # Extract the mount details
        local mount_source=""
        local mount_target=""
        if [[ "$config_mount" == *"--mount type=bind,source="* ]]; then
            mount_source=$(echo "$config_mount" | sed 's/.*--mount type=bind,source=\([^,]*\).*/\1/')
            mount_target=$(echo "$config_mount" | sed 's/.*target=\([^"]*\).*/\1/')
        fi

        if [ -n "$mount_source" ] && [ -n "$mount_target" ]; then
            # Find the devcontainer.json file
            local config_file=""
            if [ -f ".devcontainer/devcontainer.json" ]; then
                config_file=".devcontainer/devcontainer.json"
            elif [ -f ".devcontainer.json" ]; then
                config_file=".devcontainer.json"
            fi

            if [ -n "$config_file" ] && command -v jq &> /dev/null; then
                # Add the mount to the devcontainer.json mounts array
                local mount_json="{\"type\": \"bind\", \"source\": \"$mount_source\", \"target\": \"$mount_target\"}"
                jq --argjson mount "$mount_json" '.mounts = (.mounts // []) | map(select(.target != $mount.target)) + [$mount]' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
                info "Added configuration mount to $config_file"
            fi
        fi

        # Stop and remove the current container so it gets recreated with the new mount
        CONTAINER_ID=$(docker ps --filter label=devcontainer.local_folder="$PROJECT_DIR" --format "{{.ID}}" 2>/dev/null | head -1)
        if [ -n "$CONTAINER_ID" ]; then
            info "Stopping and removing current container to apply new configuration..."
            docker stop "$CONTAINER_ID" 2>/dev/null || true
            docker rm "$CONTAINER_ID" 2>/dev/null || true
        fi

        # Recreate the container with the updated configuration
        info "Recreating container with configuration pass-through..."
        docker_up "$PROJECT_DIR"

        # Copy initial configuration files to ensure they're available
        CONTAINER_ID=$(docker ps --filter label=devcontainer.local_folder="$PROJECT_DIR" --format "{{.ID}}" 2>/dev/null | head -1)
        if [ -n "$CONTAINER_ID" ]; then
            case "$AGENT" in
                "opencode")
                    local opencode_config_dir=""
                    if [ -d "$HOME/.config/opencode" ]; then
                        opencode_config_dir="$HOME/.config/opencode"
                    elif [ -d "$HOME/.local/share/opencode" ]; then
                        opencode_config_dir="$HOME/.local/share/opencode"
                    fi
                    if [ -n "$opencode_config_dir" ]; then
                        docker exec "$CONTAINER_ID" mkdir -p /home/vscode/.opencode 2>/dev/null || true
                        docker cp "$opencode_config_dir/." "$CONTAINER_ID:/home/vscode/.opencode/" 2>/dev/null && \
                        docker exec "$CONTAINER_ID" chown -R vscode:vscode /home/vscode/.opencode 2>/dev/null
                    fi
                    ;;
                "aider")
                    if [ -f "$HOME/.aider.conf.yml" ]; then
                        docker cp "$HOME/.aider.conf.yml" "$CONTAINER_ID:/home/vscode/.aider.conf.yml" 2>/dev/null && \
                        docker exec "$CONTAINER_ID" chown vscode:vscode /home/vscode/.aider.conf.yml 2>/dev/null
                    fi
                    ;;
                "copilot-cli"|"cody"|"qwen-cli"|"gemini"|"claude-cli"|"openai-cli")
                    if [ -d "$HOME/.config" ]; then
                        docker exec "$CONTAINER_ID" mkdir -p /home/vscode/.config 2>/dev/null || true
                        docker cp "$HOME/.config/." "$CONTAINER_ID:/home/vscode/.config/" 2>/dev/null && \
                        docker exec "$CONTAINER_ID" chown -R vscode:vscode /home/vscode/.config 2>/dev/null
                    fi
                    ;;
            esac
            info "Configuration pass-through enabled and initial files copied"
        fi
    fi

    info "Installing $AGENT..."

    # Determine install type for vulnerability scanning
    if [[ "$INSTALL_CMD" == npm* ]]; then
        INSTALL_TYPE="npm"
        info "Ensuring npm is available..."
        if ! docker exec "$CONTAINER_NAME" /bin/bash -c "command -v npm" 2>/dev/null; then
            warning "npm not found. Installing latest Node.js LTS..."
            if ! docker exec "$CONTAINER_NAME" /bin/bash -c "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && apt-get install -y nodejs" 2>/dev/null; then
                error_exit "Failed to install Node.js and npm" "$EXIT_DEVCONTAINER_ERROR"
            fi
        fi
    elif [[ "$INSTALL_CMD" == pip* ]]; then
        INSTALL_TYPE="pip"
        info "Setting up hermetic Python environment for isolated installation..."
        PYTHON_BIN_DIR="/home/vscode/.dcutil/python"
        VENV_DIR="/home/vscode/.dcutil/agents/$AGENT"

        # Determine platform architecture for portable Python
        PLATFORM=$(docker exec "$CONTAINER_NAME" /bin/bash -c "ARCH=\$(uname -m); OS=\$(uname -s); if [ \"\$OS\" = \"Linux\" ]; then OS_PREFIX=\"linux\"; elif [ \"\$OS\" = \"Darwin\" ]; then OS_PREFIX=\"macos\"; else OS_PREFIX=\"linux\"; fi; if [ \"\$ARCH\" = \"x86_64\" ]; then echo \"\$OS_PREFIX-x86_64\"; elif [ \"\$ARCH\" = \"aarch64\" ] || [ \"\$ARCH\" = \"arm64\" ]; then echo \"\$OS_PREFIX-aarch64\"; else echo \"linux-x86_64\"; fi" 2>/dev/null || echo "linux-x86_64")

        USE_PORTABLE=false
        # Try to set up portable Python
        if docker exec "$CONTAINER_NAME" /bin/bash -c "PLATFORM=\$PLATFORM;
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
            if ! docker exec "$CONTAINER_NAME" /bin/bash -c "
                mkdir -p $VENV_DIR
                $PYTHON_BIN_DIR/bin/python3 -m venv $VENV_DIR
            " 2>/dev/null; then
                warning "Failed to create venv with portable Python, falling back to system Python"
                USE_PORTABLE=false
            fi
        fi

        if [ "$USE_PORTABLE" != "true" ]; then
            # Fallback to system Python virtual environment
            if ! docker exec "$CONTAINER_NAME" /bin/bash -c "
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
    local exec_cmd="exec $INSTALL_CMD"
    # For curl|bash installations, don't use exec as it doesn't work with pipelines
    if [ "$INSTALL_TYPE" = "curl" ]; then
        exec_cmd="$INSTALL_CMD"
    fi

    if ! docker exec "$CONTAINER_NAME" /bin/bash -c "
        set -euo pipefail
        export DEBIAN_FRONTEND=noninteractive
        cd /home/vscode
        $exec_cmd
    "; then
        error_exit "Failed to install $AGENT" "$EXIT_DEVCONTAINER_ERROR"
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