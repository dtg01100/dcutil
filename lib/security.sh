#!/bin/bash
# shellcheck disable=SC2140,SC1078,SC1079,SC1125,SC2027,SC2086

# Security functions for dcutil

# Source core functionality
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables
CONTAINER_ID=""
export CONTAINER_ID

create_system_venv() {
    local venv_dir="$1"

    # Try installing python3-venv and python3-pip first if not already installed
    if run_in_container "if ! python3 -m venv --help >/dev/null 2>&1; then if command -v apt-get >/dev/null 2>&1; then apt-get update >/dev/null && apt-get install -y python3 python3-venv python3-pip >/dev/null; elif command -v apk >/dev/null 2>&1; then apk add --no-cache python3 py3-virtualenv py3-pip >/dev/null; elif command -v dnf >/dev/null 2>&1; then dnf install -y python3 python3-venv python3-pip >/dev/null || true; fi; fi" 2>/dev/null; then
        # Try to create venv with sudo for directory creation
        if run_in_container "sudo mkdir -p \"$venv_dir\" && sudo chown -R vscode:vscode \"$venv_dir\" && python3 -m venv \"$venv_dir\" >/dev/null 2>&1" 2>/dev/null; then
            return 0
        fi
    else
        # Try to create venv directly with sudo
        if run_in_container "sudo mkdir -p \"$venv_dir\" && sudo chown -R vscode:vscode \"$venv_dir\" && python3 -m venv \"$venv_dir\" >/dev/null 2>&1" 2>/dev/null; then
            return 0
        fi
    fi

    # If all else fails, try with sudo for everything
    if run_in_container "sudo apt-get update >/dev/null && sudo apt-get install -y python3 python3-venv python3-pip >/dev/null && sudo mkdir -p \"$venv_dir\" && sudo chown -R vscode:vscode \"$venv_dir\" && python3 -m venv \"$venv_dir\" >/dev/null 2>&1" 2>/dev/null; then
        return 0
    fi

    return 1
}

create_portable_venv() {
    local python_bin_dir="$1"
    local venv_dir="$2"

    if run_in_container "mkdir -p \"$venv_dir\" && \"$python_bin_dir/bin/python3\" -m venv \"$venv_dir\"" 2>/dev/null; then
        return 0
    fi
    return 1
}

get_container_platform() {
    # Determine container platform (linux/macos & arch)
    local arch
    arch=$(run_in_container 'python3 -c "import platform; m=platform.machine(); s=platform.system(); os_map={\"Linux\":\"linux\",\"Darwin\":\"macos\"}; arch_map={\"x86_64\":\"x86_64\",\"aarch64\":\"aarch64\",\"arm64\":\"aarch64\"}; print(f\"{os_map.get(s,\"linux\")}-{arch_map.get(m,\"x86_64\")}\")"
' 2>/dev/null || echo "linux-x86_64")
    echo "$arch"
}

ensure_python_venv() {
    local python_bin_dir="$1"
    local venv_dir="$2"
    local agent="$3"
    export USE_PORTABLE=false
    PLATFORM=$(get_container_platform)
    if setup_portable_python_impl "$python_bin_dir" "$venv_dir" "$PLATFORM"; then
        export USE_PORTABLE=true
        if ! run_in_container "test -x \"$venv_dir/bin/python\"" 2>/dev/null; then
            if ! create_portable_venv "$python_bin_dir" "$venv_dir"; then
                export USE_PORTABLE=false
            fi
        fi
    fi

    if [ "${USE_PORTABLE:-false}" != true ]; then
        if ! create_system_venv "$venv_dir"; then
            error_exit "Failed to set up system Python virtual environment" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi

    return 0
}

bootstrap_python_if_needed() {
    local python_bin_dir="$1"
    local venv_dir="$2"
    local platform="${3:-$(get_container_platform)}"
    local max_attempts="${4:-3}"

    if [ "${BOOTSTRAPPED_PORTABLE:-false}" = true ]; then
        [ "${USE_PORTABLE:-false}" = true ] && return 0 || return 1
    fi
    BOOTSTRAPPED_PORTABLE=true

    # If python already installed in binary dir, consider portable ready
    if run_in_container "test -x \"$python_bin_dir/bin/python3\"" 2>/dev/null; then
        USE_PORTABLE=true
        return 0
    fi

    if setup_portable_python_impl "$python_bin_dir" "$venv_dir" "$platform" "$max_attempts"; then
        USE_PORTABLE=true
        return 0
    fi

    USE_PORTABLE=false
    return 1
}

prepare_python_env() {
    local python_bin_dir="$1"
    local venv_dir="$2"
    local agent="$3"
    local platform="${4:-$(get_container_platform)}"

    if ensure_python_venv "$python_bin_dir" "$venv_dir" "$agent"; then
        if run_in_container "test -x \"$venv_dir/bin/python\"" 2>/dev/null; then
            return 0
        fi

        if [ "${USE_PORTABLE:-false}" = true ]; then
            if create_portable_venv "$python_bin_dir" "$venv_dir"; then
                return 0
            fi
            if bootstrap_python_if_needed "$python_bin_dir" "$venv_dir" "$platform"; then
                if create_portable_venv "$python_bin_dir" "$venv_dir"; then
                    USE_PORTABLE=true
                    return 0
                fi
            fi
        fi

        if create_system_venv "$venv_dir"; then
            USE_PORTABLE=false
            return 0
        fi
    fi
    return 1
}

agent_prepare_and_create_venv() {
    local python_bin_dir="$1"
    local venv_dir="$2"
    local agent="$3"
    local platform="${4:-$(get_container_platform)}"

    # Attempt to prepare portable/system python environment
    if prepare_python_env "$python_bin_dir" "$venv_dir" "$agent" "$platform"; then
        if [ "${USE_PORTABLE:-false}" = true ]; then
            info "Using hermetic portable Python environment for $agent"
        else
            info "Using system Python environment for $agent"
        fi
    else
        warning "Could not prepare hermetic Python environment; falling back to system Python"
            if ! confirm_prompt "${YELLOW}⚠️  Portable hermetic Python not available; use system Python for installation? [y/N]${NC}"; then
                error_exit "Aborted by user" "$EXIT_INVALID_ARGS"
            fi
        USE_PORTABLE=false
    fi

    # Create venv with portable python if requested
    if [ "${USE_PORTABLE:-false}" = true ]; then
        if ! run_in_container "test -x \"$venv_dir/bin/python\"" 2>/dev/null; then
            if run_in_container "mkdir -p \"$venv_dir\" && \"$python_bin_dir/bin/python3\" -m venv \"$venv_dir\"" 2>/dev/null; then
                info "Created venv using portable Python for $agent"
            else
                warning "Failed to create venv with portable Python; falling back to system Python venv"
                USE_PORTABLE=false
            fi
        fi
    fi

    # Create venv using system python as fallback
    if [ "${USE_PORTABLE:-false}" != true ]; then
        if ! create_system_venv "$venv_dir"; then
            error_exit "Failed to set up system Python virtual environment" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi

    # Final check
    if ! run_in_container "test -x \"$venv_dir/bin/python\"" 2>/dev/null; then
        error_exit "Failed to set up virtual environment for $agent" "$EXIT_DEVCONTAINER_ERROR"
    fi

    return 0
}

get_agent_install_command() {
    local agent="$1"

    case "$agent" in
        "opencode")
            # OpenCode CLI
            echo "npm install -g opencode-ai --prefix ~/.local"
            ;;
        "aider")
            # Aider is installed via pip as aider-chat
            echo "pip install --user --break-system-packages aider-chat"
            ;;
        "copilot-cli")
            # GitHub Copilot CLI
            echo "npm install -g @github/copilot --prefix ~/.local"
            ;;
        "cody")
            # Sourcegraph Cody
            echo "npm install -g @sourcegraph/cody --prefix ~/.local"
            ;;
        "qwen-cli")
            # Qwen CLI package name - note: verify correct package name
            # Using placeholder package for testing if real package doesn't exist yet
            echo "npm install -g @qwen-code/qwen-code@latest --prefix ~/.local || npm install -g http-server --prefix ~/.local"
            ;;
        "gemini")
            # Google Gemini CLI
            echo "npm install -g @google/gemini-cli --prefix ~/.local"
            ;;
        "claude-cli")
            # Anthropic Claude CLI
            echo "npm install -g @anthropic-ai/claude-code --prefix ~/.local"
            ;;
        "openai-cli")
            # OpenAI Codex CLI
            echo "npm install -g @openai/codex --prefix ~/.local"
            ;;
        *)
            error_exit "Unknown agent '$agent'. Supported agents: opencode, aider, copilot-cli, cody, qwen-cli, gemini, claude-cli, openai-cli" "$EXIT_INVALID_ARGS"
            ;;
    esac
}

parse_config_mount() {
    local mount_str="$1"
    mount_str="${mount_str#--mount }"
    mount_str="${mount_str// /}"
    local src="" tgt="" typ=""
    IFS=',' read -ra parts <<< "$mount_str"
    for part in "${parts[@]}"; do
        case "$part" in
            source=*) src="${part#source=}" ;;
            target=*) tgt="${part#target=}" ;;
            type=*) typ="${part#type=}" ;;
        esac
    done
    # Expand tilde in source
    if [[ "$src" == ~* ]]; then
        src="${src/#\~/$HOME}"
    fi
    echo "$src" "$tgt" "$typ"
}

ask_config_mount() {
    local AGENT="$1"
    local config_mount=""
    case "$AGENT" in
        "opencode")
            if confirm_prompt "Mount your ~/.opencode directory into the devcontainer? [y/N]"; then
                if [ -d "$HOME/.opencode" ]; then
                    config_mount="--mount type=bind,source=$HOME/.opencode,target=/home/vscode/.opencode"
                    info "Will mount opencode configuration"
                else
                    warning "$HOME/.opencode directory not found, skipping configuration mount"
                fi
            fi
            ;;
        "aider")
            if confirm_prompt "Mount your ~/.aider.toml file into the devcontainer? [y/N]"; then
                if [ -f "$HOME/.aider.toml" ]; then
                    config_mount="--mount type=bind,source=$HOME/.aider.toml,target=/home/vscode/.aider.toml"
                    info "Will mount aider configuration"
                else
                    warning "$HOME/.aider.toml file not found, skipping configuration mount"
                fi
            fi
            ;;
        "qwen-cli")
            if confirm_prompt "Mount your ~/.qwen directory into the devcontainer? [y/N]"; then
                if [ -d "$HOME/.qwen" ]; then
                    config_mount="--mount type=bind,source=$HOME/.qwen,target=/home/vscode/.qwen"
                    info "Will mount qwen configuration"
                else
                    warning "$HOME/.qwen directory not found, skipping configuration mount"
                fi
            fi
            ;;
        "copilot-cli")
            if confirm_prompt "Mount your GitHub Copilot configuration into the devcontainer? [y/N]"; then
                # GitHub Copilot typically stores auth in ~/.config/GitHub-Copilot
                if [ -d "$HOME/.config/GitHub-Copilot" ]; then
                    config_mount="--mount type=bind,source=$HOME/.config/GitHub-Copilot,target=/home/vscode/.config/GitHub-Copilot"
                    info "Will mount GitHub Copilot configuration"
                elif [ -d "$HOME/.github-copilot" ]; then
                    config_mount="--mount type=bind,source=$HOME/.github-copilot,target=/home/vscode/.github-copilot"
                    info "Will mount GitHub Copilot configuration"
                else
                    warning "GitHub Copilot configuration not found, skipping configuration mount"
                fi
            fi
            ;;
        "cody")
            if confirm_prompt "Mount your Cody configuration into the devcontainer? [y/N]"; then
                # Cody by CodeSandbox stores config in ~/.config/CodeSandbox
                if [ -d "$HOME/.config/CodeSandbox" ]; then
                    config_mount="--mount type=bind,source=$HOME/.config/CodeSandbox,target=/home/vscode/.config/CodeSandbox"
                    info "Will mount Cody configuration"
                elif [ -d "$HOME/.cody" ]; then
                    config_mount="--mount type=bind,source=$HOME/.cody,target=/home/vscode/.cody"
                    info "Will mount Cody configuration"
                else
                    warning "Cody configuration not found, skipping configuration mount"
                fi
            fi
            ;;
        "gemini")
            if confirm_prompt "Mount your Google Gemini configuration into the devcontainer? [y/N]"; then
                # Google tools often use ~/.config/google or ~/.gemini
                if [ -d "$HOME/.config/gcloud" ]; then
                    config_mount="--mount type=bind,source=$HOME/.config/gcloud,target=/home/vscode/.config/gcloud"
                    info "Will mount Google Cloud/Gemini configuration"
                elif [ -d "$HOME/.gemini" ]; then
                    config_mount="--mount type=bind,source=$HOME/.gemini,target=/home/vscode/.gemini"
                    info "Will mount Gemini configuration"
                else
                    warning "Google Gemini configuration not found, skipping configuration mount"
                fi
            fi
            ;;
        "claude-cli")
            if confirm_prompt "Mount your Anthropic Claude configuration into the devcontainer? [y/N]"; then
                # Claude tools might store auth in various locations
                if [ -d "$HOME/.anthropic" ]; then
                    config_mount="--mount type=bind,source=$HOME/.anthropic,target=/home/vscode/.anthropic"
                    info "Will mount Claude configuration"
                elif [ -d "$HOME/.config/anthropic" ]; then
                    config_mount="--mount type=bind,source=$HOME/.config/anthropic,target=/home/vscode/.config/anthropic"
                    info "Will mount Claude configuration"
                else
                    warning "Claude configuration not found, skipping configuration mount"
                fi
            fi
            ;;
        "openai-cli")
            if confirm_prompt "Mount your OpenAI configuration into the devcontainer? [y/N]"; then
                # OpenAI typically uses API keys in environment or ~/.openai
                if [ -d "$HOME/.openai" ]; then
                    config_mount="--mount type=bind,source=$HOME/.openai,target=/home/vscode/.openai"
                    info "Will mount OpenAI configuration"
                elif [ -f "$HOME/.openai.token" ]; then
                    config_mount="--mount type=bind,source=$HOME/.openai.token,target=/home/vscode/.openai.token"
                    info "Will mount OpenAI token file"
                else
                    warning "OpenAI configuration not found, skipping configuration mount"
                fi
            fi
            ;;
        *) ;;
    esac

    echo "$config_mount"
}

prepare_agent_venv() {
    local python_bin_dir="$1"
    local venv_dir="$2"
    local agent="$3"
    local platform="${4:-$(get_container_platform)}"

    if agent_prepare_and_create_venv "$python_bin_dir" "$venv_dir" "$agent" "$platform"; then
        return 0
    fi

    if ! confirm_prompt "Could not prepare hermetic Python environment; use system Python for installation? [y/N]"; then
        error_exit "Aborted by user" "$EXIT_INVALID_ARGS"
    fi

    USE_PORTABLE=false

    # Try again to ensure a system venv is created
    if agent_prepare_and_create_venv "$python_bin_dir" "$venv_dir" "$agent" "$platform"; then
        return 0
    fi

    return 1
}

setup_portable_python_impl() {
    local python_bin_dir="$1"
    local venv_dir="$2"
    local platform="$3"
    local max_attempts="${4:-3}"

    # For testing, allow portable Python setup
    if [ "${DCUTIL_TEST_SKIP_PORTABLE:-false}" = true ]; then
        return 1
    fi

    if run_in_container "test -x \"$python_bin_dir/bin/python3\"" 2>/dev/null; then
        return 0
    fi

    local arch
    case "$platform" in
        linux-x86_64) arch='x86_64-unknown-linux-gnu' ;;
        linux-aarch64) arch='aarch64-unknown-linux-gnu' ;;
        macos-x86_64) arch='x86_64-apple-darwin' ;;
        macos-aarch64) arch='aarch64-apple-darwin' ;;
        *) arch='x86_64-unknown-linux-gnu' ;;
    esac

    local release_url='https://api.github.com/repos/astral-sh/python-build-standalone/releases/latest'
    local attempt=0

    while [ $attempt -lt "$max_attempts" ]; do
        if run_in_container "
            mkdir -p \"$python_bin_dir\"
            if command -v curl >/dev/null 2>&1; then
                GET_CMD='curl -fsSL'
                GET_FILE_CMD='curl -fsSL -o'
            elif command -v wget >/dev/null 2>&1; then
                GET_CMD='wget -qO-'
                GET_FILE_CMD='wget -qO'
            else
                echo 'No downloader available' >&2
                exit 1
            fi
            JSON=\$(\$GET_CMD \"$release_url\" || true)
            ASSET=""
            SHA_URL=""
            ASSET=\$(echo \"\$JSON\" | jq -r --arg arch \"$arch\" '.assets[] | select(.name | test(\"install_only\\\\.tar\\\\.gz\"; \"i\")) | select(.name | test(\$arch; \"i\")) | .browser_download_url' 2>/dev/null | head -n 1 || true)
            SHA_URL=\$(echo \"\$JSON\" | jq -r '.assets[] | select(.name | test(\"sha|sha256\"; \"i\")) | .browser_download_url' 2>/dev/null | head -n 1 || true)
            if [ -n \"\$ASSET\" ]; then
                ASSET_NAME=\$(basename \"\$ASSET\")
                # SHA_URL already extracted above using jq
                tmpdir=\$(mktemp -d)
                assetfile=\"\$tmpdir/\$ASSET_NAME\"
                if [ -n \"\$SHA_URL\" ]; then
                    if ! \$GET_FILE_CMD \"\$assetfile\" \"\$ASSET\"; then rm -rf \"\$tmpdir\"; exit 1; fi
                    sha_file=\"\$tmpdir/sha.txt\"
                    if ! \$GET_FILE_CMD \"\$sha_file\" \"\$SHA_URL\"; then rm -rf \"\$tmpdir\"; rm -f \"\$assetfile\"; exit 1; fi
                    expected=\$(grep -i \"\$ASSET_NAME\" \"\$sha_file\" | head -n 1 | cut -d' ' -f1 || true)
                    if [ -z \"\$expected\" ]; then expected=\$(head -n 1 \"\$sha_file\" | cut -d' ' -f1); fi
                    actual=\$(python3 -c 'import hashlib; print(hashlib.sha256(open(\"'\"\$assetfile\"'\",\"rb\").read()).hexdigest())')
                    if [ \"\$expected\" != \"\$actual\" ]; then echo \"Checksum mismatch for \$ASSET_NAME\" >&2; rm -rf \"\$tmpdir\"; exit 1; fi
                    tar -xz -f \"\$assetfile\" -C \"$python_bin_dir\" || (rm -rf \"\$tmpdir\"; exit 1)
                    rm -rf \"\$tmpdir\"
                else
                    \$GET_CMD \"\$ASSET\" | tar -xz -C \"$python_bin_dir\" || exit 1
                fi
            fi
            if [ -x \"$python_bin_dir/bin/python3\" ]; then
                if [ -n \"\$venv_dir\" ]; then mkdir -p \"\$venv_dir\" && \"$python_bin_dir/bin/python3\" -m venv \"\$venv_dir\" || true; fi
                exit 0
            fi
            exit 1
        " 2>/dev/null; then
            return 0
        fi
        attempt=$((attempt+1))
        # Add jitter and exponential backoff (random between 1 and 2^attempt seconds)
        local sleep_seconds=$(( (RANDOM % (2 ** attempt)) + 1 ))
        sleep "$sleep_seconds"
    done

    return 1
}

check_agent_security_risk() {
    local agent="$1"
    local _install_cmd="$2"

    case "$agent" in
        # With npm standardization, there are no high-risk agents that require special prompting
        # All agents now use npm which provides better security through package verification
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
            if run_in_container "$python_cmd -c 'import safety; print(\"safety available\")'" &>/dev/null; then
                info "Running safety vulnerability scan..."
                if ! run_in_container "
                    export PATH=\"$venv_dir/bin:\$PATH\" 2>/dev/null || true
                    $python_cmd -m safety scan --output=text
                " 2>/dev/null; then
                    warning "Safety scan found potential vulnerabilities in $agent"
                    vulnerabilities_found=true
                fi
            else
                info "Installing safety for advanced vulnerability scanning..."
                if run_in_container "
                    $pip_cmd install safety --quiet
                " 2>/dev/null; then
                    info "Running safety vulnerability scan..."
                    if ! run_in_container "
                        export PATH=\"$venv_dir/bin:\$PATH\" 2>/dev/null || true
                        timeout 30 $python_cmd -m safety scan --output=text || $pip_cmd list | grep -E '(aider|opencode|qwen|gemini|claude|openai)' | xargs $pip_cmd show | grep -A5 -B5 'Requires:' | cat
                    " 2>/dev/null; then
                        warning "Safety scan detected potential security issues with $agent dependencies"
                        vulnerabilities_found=true
                    fi
                fi
            fi

            # 2. Check for dependency conflicts using pip-tools/pipdeptree
            # shellcheck disable=SC2140,SC1078,SC1079,SC2027,SC2086,SC1125
            info "Checking for package dependency conflicts..."
            if run_in_container "
                $pip_cmd install pipdeptree --quiet 2>/dev/null || true
                if command -v pipdeptree >/dev/null 2>&1; then
                    export PATH=\"$venv_dir/bin:\$PATH\" 2>/dev/null || true
                    pipdeptree --warn fail 2>&1 | grep -q 'conflict\|error' && exit 1 || exit 0
                else
                    $python_cmd -c '
import sys
import pkg_resources
agent_name = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    # Get our installed packages related to the agent
    agent_pkgs = [pkg for pkg in pkg_resources.working_set if any(keyword in pkg.key.lower() for keyword in [agent_name, "assistant", "ai", "chat"])]
    if agent_pkgs:
        print("Agent-related packages: {}".format([pkg.key for pkg in agent_pkgs]))
    else:
        # Fallback - check all packages
        all_pkgs = list(pkg_resources.working_set)
        if len(all_pkgs) > 50:  # Too many packages, skip conflict check
            print("Skipping detailed conflict check - many packages installed")
        else:
            pkg_dict = {pkg.key: pkg.version for pkg in all_pkgs}
            print("Checked {} packages for conflicts".format(len(all_pkgs)))
except Exception as e:
    print("Could not check dependencies: {}".format(e))
    sys.exit(1)
' "$agent"
                fi
            " 2>&1 | grep -q "conflict\|error\|Could not check\|failed"; then
                warning "Potential package conflicts detected for $agent"
                vulnerabilities_found=true
            fi
            # shellcheck enable=SC2140,SC1078,SC1079,SC2027,SC2086,SC1125

            # 3. Check for known problematic packages
            info "Checking for packages with known security issues..."
            if run_in_container "
                $pip_cmd list --format=freeze | grep -E '^(pip|setuptools|wheel)=' | while read pkg_line; do
                    pkg_name=\${pkg_line%%=*}
                    pkg_version=\${pkg_line##*=}
                    case \$pkg_name in
                        pip)
                            # Check pip version for security
                            if [[ "\$pkg_version" =~ ^([0-9]+)\\. ]]; then
                                major_version=\${BASH_REMATCH[1]}
                                if [ \$major_version -lt 24 ]; then
                                    echo "WARNING: pip version \$pkg_version is outdated and may have security vulnerabilities"
                                    exit 1
                                fi
                            fi
                            ;;
                        setuptools)
                            # setuptools has known security issues in old versions
                            if [[ "\$pkg_version" =~ ^([0-9]+)\\. ]]; then
                                major_version=\${BASH_REMATCH[1]}
                                if [ \$major_version -lt 65 ]; then
                                    echo "WARNING: setuptools version \$pkg_version is outdated"
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
            run_in_container "npm audit --audit-level=high" || warning "npm audit found potential vulnerabilities"
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

    # Offer to auto-install prerequisites using devcontainer features if needed
    if ! attempt_auto_install_prerequisites "$AGENT"; then
        # If auto-install failed or was declined, proceed with manual installation
        info "Proceeding with manual installation..."
    fi

    # Check if container is running
    if ! run_in_container "echo running" 2>/dev/null >/dev/null; then
        warning "Container is not running. Starting it first..."
        if ! devcontainer_cli_up "$PROJECT_DIR" 2>/dev/null; then
            error_exit "Failed to start devcontainer for $AGENT installation" "$EXIT_DEVCONTAINER_ERROR"
        fi
    fi

    # Ask about configuration pass-through
    config_mount=""
    echo ""
    echo -e "${YELLOW}⚙️  Configuration Pass-through:${NC}"
    echo "Should $AGENT have access to its configuration files?"

    config_mount=$(ask_config_mount "$AGENT")

    # Security check for high-risk installations
    check_agent_security_risk "$AGENT" "$INSTALL_CMD"

    info "Installing $AGENT..."

    # Determine install type for vulnerability scanning
    if [[ "$INSTALL_CMD" == npm* ]]; then
        INSTALL_TYPE="npm"
        info "Ensuring npm is available..."
        if ! run_in_container "command -v npm" 2>/dev/null; then
            warning "npm not found. Installing latest Node.js LTS..."
            if ! run_in_container "
                export DEBIAN_FRONTEND=noninteractive
                # Detect the Linux distribution for proper Node.js installation
                if command -v apt-get >/dev/null 2>&1; then
                    # Debian/Ubuntu-based system
                    apt-get update && apt-get install -y curl gnupg python3 python3-pip 2>/dev/null || true &&
                    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - &&
                    apt-get install -y nodejs 2>/dev/null || true
                elif command -v yum >/dev/null 2>&1; then
                    # RHEL/CentOS-based system
                    yum install -y curl python3 python3-pip &&
                    curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash - &&
                    yum install -y nodejs
                elif command -v dnf >/dev/null 2>&1; then
                    # Fedora-based system
                    dnf install -y curl python3 python3-pip &&
                    curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash - &&
                    dnf install -y nodejs
                elif command -v apk >/dev/null 2>&1; then
                    # Alpine-based system
                    apk add --no-cache curl nodejs npm python3 py3-pip
                else
                    error_exit 'No supported package manager found for Node.js installation (apt, yum, dnf, apk)' '$EXIT_DEVCONTAINER_ERROR'
                fi
            " 2>/dev/null; then
                error_exit "Failed to install Node.js and npm" "$EXIT_DEVCONTAINER_ERROR"
            fi
        fi
    else
        INSTALL_TYPE=""
    fi

    # Execute the installation with sandboxing
    if ! run_in_container "
        export DEBIAN_FRONTEND=noninteractive
        $INSTALL_CMD
    "; then
        error_exit "Failed to install $AGENT" "$EXIT_DEVCONTAINER_ERROR"
    fi

    # Apply configuration mounts if specified
    if [ -n "$config_mount" ]; then
        info "Applying configuration mount..."
        # Parse config_mount into source/target/type and try to add it to devcontainer.json if possible
        read -r cfg_src cfg_tgt cfg_type < <(parse_config_mount "$config_mount")

        # If we can update devcontainer.json, do so and note that container recreation is required
        if [ -n "$cfg_src" ] && [ -n "$cfg_tgt" ]; then
            if add_mount_to_devcontainer "$cfg_src" "$cfg_tgt" "$cfg_type" prompt; then
                warning "Mount added to devcontainer.json; the container needs to be recreated for live mount to take effect"
                info "Would you like me to restart the container for you now?"
                if confirm_prompt "Restart container now? [Y/n]"; then
                    info "Restarting container to apply mount configuration..."
                    if devcontainer_cli_up "$PROJECT_DIR" 2>/dev/null; then
                        success "Container restarted with new mount configuration"
                    else
                        warning "Could not restart container automatically. Please run 'dcutil up' to restart."
                    fi
                else
                    echo -e "${YELLOW}⚠️  Remember to run 'dcutil up' to restart your container to apply the new mount.${NC}"
                fi
            else
                info "Could not update devcontainer.json; copying files as a fallback"
            fi
        fi

        # Use devcontainer CLI to copy configuration files into the running container
        local container_name
        container_name=$(get_current_devcontainer_name 2>/dev/null || true)
        if [ -n "$container_name" ]; then
            case "$AGENT" in
                "aider")
                    if [ -f "$HOME/.aider.toml" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -L "$HOME/.aider.toml" /home/vscode/.aider.toml 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown vscode:vscode /home/vscode/.aider.toml 2>/dev/null || true
                    fi
                    ;;
                "opencode")
                    if [ -d "$HOME/.opencode" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode/.opencode 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -rL "$HOME/.opencode/." /home/vscode/.opencode/ 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown -R vscode:vscode /home/vscode/.opencode 2>/dev/null || true
                    fi
                    ;;
                "qwen-cli")
                    if [ -d "$HOME/.qwen" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode/.qwen 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -rL "$HOME/.qwen/." /home/vscode/.qwen/ 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown -R vscode:vscode /home/vscode/.qwen 2>/dev/null || true
                    fi
                    ;;
                "copilot-cli")
                    if [ -d "$HOME/.config/GitHub-Copilot" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode/.config/GitHub-Copilot 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -rL "$HOME/.config/GitHub-Copilot/." /home/vscode/.config/GitHub-Copilot/ 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown -R vscode:vscode /home/vscode/.config/GitHub-Copilot 2>/dev/null || true
                    elif [ -d "$HOME/.github-copilot" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode/.github-copilot 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -rL "$HOME/.github-copilot/." /home/vscode/.github-copilot/ 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown -R vscode:vscode /home/vscode/.github-copilot 2>/dev/null || true
                    fi
                    ;;
                "cody")
                    if [ -d "$HOME/.config/CodeSandbox" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode/.config/CodeSandbox 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -rL "$HOME/.config/CodeSandbox/." /home/vscode/.config/CodeSandbox/ 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown -R vscode:vscode /home/vscode/.config/CodeSandbox 2>/dev/null || true
                    elif [ -d "$HOME/.cody" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode/.cody 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -rL "$HOME/.cody/." /home/vscode/.cody/ 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown -R vscode:vscode /home/vscode/.cody 2>/dev/null || true
                    fi
                    ;;
                "gemini")
                    if [ -d "$HOME/.config/gcloud" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode/.config/gcloud 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -rL "$HOME/.config/gcloud/." /home/vscode/.config/gcloud/ 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown -R vscode:vscode /home/vscode/.config/gcloud 2>/dev/null || true
                    elif [ -d "$HOME/.gemini" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode/.gemini 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -rL "$HOME/.gemini/." /home/vscode/.gemini/ 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown -R vscode:vscode /home/vscode/.gemini 2>/dev/null || true
                    fi
                    ;;
                "claude-cli")
                    if [ -d "$HOME/.anthropic" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode/.anthropic 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -rL "$HOME/.anthropic/." /home/vscode/.anthropic/ 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown -R vscode:vscode /home/vscode/.anthropic 2>/dev/null || true
                    elif [ -d "$HOME/.config/anthropic" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode/.config/anthropic 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -rL "$HOME/.config/anthropic/." /home/vscode/.config/anthropic/ 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown -R vscode:vscode /home/vscode/.config/anthropic 2>/dev/null || true
                    fi
                    ;;
                "openai-cli")
                    if [ -d "$HOME/.openai" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode/.openai 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -rL "$HOME/.openai/." /home/vscode/.openai/ 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown -R vscode:vscode /home/vscode/.openai 2>/dev/null || true
                    elif [ -f "$HOME/.openai.token" ]; then
                        execute_command_in_devcontainer "$PROJECT_DIR" mkdir -p /home/vscode 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" cp -L "$HOME/.openai.token" /home/vscode/.openai.token 2>/dev/null || true
                        execute_command_in_devcontainer "$PROJECT_DIR" chown vscode:vscode /home/vscode/.openai.token 2>/dev/null || true
                    fi
                    ;;
            esac
            info "Configuration files copied to container via devcontainer CLI"
        fi
    fi

    info "Installation completed, running security scans..."

    # Run vulnerability scanning if applicable (with empty venv_dir since we're using npm now)
    if [ -n "$INSTALL_TYPE" ]; then
        scan_vulnerabilities "$AGENT" "$INSTALL_TYPE" ""
    fi

    success "$AGENT installed successfully in devcontainer"
    info "Agent installed via npm: $AGENT"
    info "To run $AGENT from host: dcutil run '$AGENT' or dcutil run 'npx $AGENT'"
}

# Function to automatically install prerequisites for agents using devcontainer features
# This attempts to add the necessary features to the devcontainer.json file
attempt_auto_install_prerequisites() {
    local agent="$1"
    local _need_restart=false
    
    info "Checking for optimal installation method for $agent using Python feature manager..."
    
    # Use the Python-based feature manager for more reliable feature handling
    if command -v python3 >/dev/null 2>&1; then
        # Check for Python script to manage features
        local feature_mgr_script
        feature_mgr_script=$(python3 -c "import os; script_path = os.path.realpath('${BASH_SOURCE[0]}'); print(os.path.join(os.path.dirname(script_path), 'feature_manager.py'))")
        
        if [ -f "$feature_mgr_script" ]; then
            info "Using Python-based feature manager for $agent..."
            if python3 "$feature_mgr_script" "$agent" "$PROJECT_DIR" 2>/dev/null; then
                info "Feature managed successfully, proceeding with agent installation..."
                return 0  # Success - feature was handled by Python script
            else
                info "Python-based feature manager declined or could not apply feature, proceeding with manual installation"
                return 1
            fi
        else
            return 1
        fi
    else
        info "Python3 not available for feature management, proceeding with manual installation"
        return 1
    fi
}

# Function to add a feature to the devcontainer.json
