#!/usr/bin/env bash

# Core functionality for dcutil
# Handles basic operations and command routing

# Exit codes
EXIT_SUCCESS=0
EXIT_INVALID_ARGS=1
EXIT_DEP_NOT_FOUND=2
EXIT_DOCKER_ERROR=3
EXIT_DEVCONTAINER_ERROR=4
EXIT_PERMISSION_ERROR=5
EXIT_CONFIG_ERROR=6

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
PROJECT_DIR=""

# Error handling functions
error_exit() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    exit "${2:-$EXIT_INVALID_ARGS}"
}

warning() {
    echo -e "${YELLOW}⚠️  Warning: $1${NC}" >&2
}

error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
}

success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}" >&2
}

confirm_prompt() {
    local prompt_text="${1:-}"
    local default="${2:-N}"

    if [ -n "${DCUTIL_ASSUME_YES:-}" ]; then
        return 0
    fi

    if [ -n "${CI:-}" ] || [ ! -t 0 ]; then
        return 1
    fi

    local ans
    read -r -p "$prompt_text " ans
    ans="${ans:-$default}"
    if [[ "$ans" =~ ^[Yy] ]]; then
        return 0
    fi
    return 1
}

# Input validation functions
validate_command() {
    local cmd="${1:-}"
    local valid_commands="up down restart enter build clean status logs list run init install-agent check ssh volumes compose rebuild features lifecycle environment advanced integration merging userprobe hostrequirements shutdown schema podman version help completion test"

    if [[ ! " $valid_commands " =~ $cmd ]]; then
        error_exit "Invalid command '$cmd'. Use 'dcutil help' for available commands." "$EXIT_INVALID_ARGS"
    fi
}

validate_project_path() {
    local path="${1:-}"

    if [ -n "$path" ]; then
        if [ ! -d "$path" ]; then
            error_exit "Project path '$path' does not exist or is not a directory." "$EXIT_INVALID_ARGS"
        fi

        if [ ! -r "$path" ]; then
            error_exit "Cannot read project path '$path'. Permission denied." "$EXIT_PERMISSION_ERROR"
        fi

        # Convert to absolute path
        if ! cd "$path" 2>/dev/null; then
            error_exit "Cannot access project path '$path'." "$EXIT_PERMISSION_ERROR"
        fi
        PROJECT_DIR="$(pwd)"
        cd - >/dev/null || exit
    fi
}

validate_run_command() {
    if [ $# -eq 0 ]; then
        error_exit "run command requires a command to execute. Usage: dcutil run [project_path] <command>" "$EXIT_INVALID_ARGS"
    fi
}

validate_init_mode() {
    local mode="${1:-}"
    local valid_modes="fast wizard --fast --wizard --help -h"

    if [ -n "$mode" ] && [[ ! " $valid_modes " =~ $mode ]]; then
        error_exit "Unknown init mode: '$mode'. Use 'dcutil init --help' for usage information." "$EXIT_INVALID_ARGS"
    fi
}

# Enhanced path validation
validate_safe_path() {
    local path="$1"
    if [[ "$path" == *"'"'"'* ]] || [[ "$path" == *'$'* ]] || [[ "$path" == *"\""* ]]; then
        error_exit "Path contains unsafe characters: $path" "$EXIT_INVALID_ARGS"
    fi
}

safe_path() {
    local path="$1"
    case "$path" in
        "~/"*) echo "${HOME}/${path#"~/"}" ;;
        "~"*) echo "$HOME" ;;
        *) echo "$path" ;;
    esac | while IFS= read -r line; do
        realpath -m "$line" 2>/dev/null || echo "$line"
    done
}

# Validate a workspace folder path provided for devcontainer configuration
validate_workspace_folder() {
    local wf="$1"

    # Empty is invalid here (caller may provide a default)
    if [ -z "${wf}" ]; then
        return 1
    fi

    # Must be an absolute path
    if [[ "${wf}" != /* ]]; then
        return 2
    fi

    # Disallow root which would be dangerous
    if [ "${wf}" = "/" ]; then
        return 3
    fi

    # Disallow paths with whitespace at ends
    if [[ "${wf}" =~ ^[[:space:]] || "${wf}" =~ [[:space:]]$ ]]; then
        return 4
    fi

    # Basic.. path looks fine
    return 0
}

# Validate JSON file with jq or python if available
validate_json_if_available() {
    local fp="$1"
    if [ -z "$fp" ] || [ ! -f "$fp" ]; then
        error_exit "JSON file not found for validation: $fp" "$EXIT_CONFIG_ERROR"
    fi

    if command -v jq >/dev/null 2>&1; then
        if ! jq -e . "$fp" >/dev/null 2>&1; then
            error_exit "Generated JSON at $fp is invalid" "$EXIT_CONFIG_ERROR"
        fi
    elif command -v python >/dev/null 2>&1; then
        if ! python -m json.tool "$fp" >/dev/null 2>&1; then
            error_exit "Generated JSON at $fp is invalid" "$EXIT_CONFIG_ERROR"
        fi
    else
        warning "No JSON validator available (jq/python); could not validate $fp"
    fi
}

# Best-effort: check whether a given user exists in a docker image (requires docker)
check_user_in_image() {
    local image="$1"
    local user="$2"

    if ! command -v docker >/dev/null 2>&1; then
        return 2
    fi

    # Try to run `id <user>` inside the image. This will pull the image if necessary.
    if docker run --rm --entrypoint id "$image" "$user" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Determine project directory:
# 1. Use first argument if provided and is a directory
# 2. Use current working directory if it contains .devcontainer
# 3. Use script's directory as fallback
determine_project_dir() {
    local potential_path="${1:-}"
    
    if [ -n "$potential_path" ]; then
        validate_project_path "$potential_path"
    elif [ -f ".devcontainer/devcontainer.json" ] || [ -f ".devcontainer.json" ]; then
        PROJECT_DIR="$(pwd)"
    else
        PROJECT_DIR="$SCRIPT_DIR"
    fi

    # Final validation
    if [ ! -d "$PROJECT_DIR" ]; then
        error_exit "Determined project directory '$PROJECT_DIR' is not valid." "$EXIT_CONFIG_ERROR"
    fi
    
    # Initialize DEVCONTAINER_CONFIG_FILE for all modules
    initialize_devcontainer_config
}

# Initialize devcontainer configuration file path
initialize_devcontainer_config() {
    local cfg=""
    if [ -f "$PROJECT_DIR/.devcontainer/devcontainer.json" ]; then
        cfg="$PROJECT_DIR/.devcontainer/devcontainer.json"
    elif [ -f "$PROJECT_DIR/.devcontainer.json" ]; then
        cfg="$PROJECT_DIR/.devcontainer.json"
    elif [ -f "$PROJECT_DIR/devcontainer.json" ]; then
        cfg="$PROJECT_DIR/devcontainer.json"
    elif [ -f "$PROJECT_DIR/.devcontainer/devcontainer/devcontainer.json" ]; then
        cfg="$PROJECT_DIR/.devcontainer/devcontainer/devcontainer.json"
    fi

    if [ -n "$cfg" ]; then
        DEVCONTAINER_CONFIG_FILE=$(realpath -m "$cfg" 2>/dev/null || echo "$cfg")
        export DEVCONTAINER_CONFIG_FILE
    else
        export DEVCONTAINER_CONFIG_FILE=""
    fi
}

# Helper functions
print_up_usage() {
    echo "Usage: dcutil up [options] [project_path]"
    echo ""
    echo "Options:"
    echo "  --project-home    Set container home folder to project directory"
    echo "  --help, -h        Show this help"
    echo ""
    echo "Examples:"
    echo "  dcutil up                           # Start devcontainer normally"
    echo "  dcutil up --project-home            # Start with home folder in project directory"
    echo "  dcutil up --project-home /path/to/project  # Start with project-home in specific project"
    echo ""
    echo "When --project-home is used, the container's home directory will be mapped to the"
    echo "project directory, allowing the container to use the project as the home folder."
}

print_volumes_usage() {
    echo "Usage: dcutil volumes <subcommand>"
    echo ""
    echo "Volume subcommands:"
    echo "  list         List configured volumes for this project"
    echo "  add <name> <host_path> <container_path> [type]  Add a new volume"
    echo "  remove <name>  Remove a volume configuration"
    echo "  mount <name>   Show mount configuration for volume"
    echo "  unmount <name>  Unmount a volume from running container"
    echo "  status        Show volume configuration and mount status"
    echo "  backup <name> [path]  Create backup of volume"
    echo "  restore <name> <backup> Restore volume from backup"
    echo "  help          Show this help"
    echo ""
    echo "Volume types:"
    echo "  bind         Bind mount (default) - maps host directory to container"
    echo "  volume       Docker volume - managed by Docker"
    echo "  tmpfs        Temporary filesystem - stored in memory"
    echo ""
    echo "Examples:"
    echo "  dcutil volumes list"
    echo "  dcutil volumes add workspace ~/projects/myapp /workspaces/myapp"
    echo "  dcutil volumes add database-data ./data /var/lib/postgresql/data"
    echo "  dcutil volumes add temp /tmp /tmp tmpfs"
    echo "  dcutil volumes mount workspace"
    echo "  dcutil volumes backup workspace ./workspace_backup.tar.gz"
    echo "  dcutil volumes restore workspace ./workspace_backup.tar.gz"
    echo "  dcutil volumes status"
    echo ""
    echo "Volume Management:"
    echo "  - Volumes are configured per-project in .devcontainer/volumes.json"
    echo "  - Bind mounts require existing host directories (created automatically)"
    echo "  - Volume mounts require container recreation"
    echo "  - tmpfs mounts are ephemeral and lost when container stops"
    echo "  - Use 'dcutil volumes status' to see current mount information"
}

print_usage() {
    echo "Usage: dcutil <command> [project_path] [options]"
    echo ""
    echo "Commands:"
    echo "  up [options]  Start the devcontainer (with optional --project-home)"
    echo "  down        Stop the devcontainer"
    echo "  restart     Restart the devcontainer"
    echo "  enter       Enter the container shell"
    echo "  build       Build the devcontainer image"
    echo "  clean       Remove the devcontainer and clean up"
    echo "  status      Show container status"
    echo "  logs        Show container logs"
    echo "  list        List running devcontainers"
    echo "  run <cmd>   Run a command in the container"
    echo "  init        Initialize a devcontainer (fast or wizard)"
    echo "  install-agent <agent> Install AI agent inside the devcontainer"
    echo "  volumes <cmd> Volume management (list, add, mount, backup, etc.)"
    echo "  compose <cmd> Docker Compose support (up, down, status, etc.)"
    echo "  build <cmd> Custom Dockerfile build support (info, validate, clean)"
    echo "  rebuild [options]  Rebuild devcontainer with preservation options"
    echo "  features <cmd> Devcontainer Features management"
    echo "  advanced <cmd> Advanced devcontainer features"
    echo "  integration <cmd> Tool integration features"
    echo "  merging <cmd> Image metadata merging"
    echo "  userprobe <cmd> User environment probing"
    echo "  hostrequirements <cmd> Host system requirements validation"
    echo "  shutdown <cmd> Container shutdown actions"
    echo "  schema <cmd> Devcontainer configuration schema validation"
    echo "  podman <cmd> Podman backend configuration and status"
    echo "  completion  Generate completion script for bash/zsh"
    echo "  test        Test dcutil improvements and functionality"
    echo "  help        Show this help message"
    echo ""
    echo "Project path detection:"
    echo "  - If provided as second argument, uses that directory"
    echo "  - If current directory has .devcontainer/, uses current directory"
    echo "  - Otherwise uses script's directory"
    echo ""
    echo "Special options:"
    echo "  up command supports --project-home to set container home directory to project directory"
    echo "  Usage: dcutil up --project-home [project_path]"
}