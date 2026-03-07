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
    local platform="${3:-$(get_container_platform)}"

    if ensure_python_venv "$python_bin_dir" "$venv_dir"; then
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









# Function to automatically install prerequisites for agents using devcontainer features
# This attempts to add the necessary features to the devcontainer.json file
attempt_auto_install_prerequisites() {
    local agent="$1"
    local need_restart=false
    
    info "Checking for optimal installation method for $agent using Python feature manager..."
    
    # Use the Python-based feature manager for more reliable feature handling
    if command -v python3 >/dev/null 2>&1; then
        # Check for Python script to manage features
        local feature_mgr_script
        feature_mgr_script="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/feature_manager.py"
        
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

# Function to copy agent configuration files to the devcontainer
copy_agent_config_files() {
    local agent="$1"
    local container_name="$2"
    
    info "Copying configuration files for $agent to $container_name..."
    # Implementation placeholder
    return 0
}

# Function to copy a single file to the devcontainer
copy_single_file() {
    local src="$1"
    local dest="$2"
    local container_name="$3"
    
    # Implementation placeholder
    return 0
}

# Function to copy directory content to the devcontainer
copy_dir_content() {
    local src_dir="$1"
    local dest_dir="$2"
    local container_name="$3"
    
    # Implementation placeholder
    return 0
}

