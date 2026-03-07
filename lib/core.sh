#!/usr/bin/env bash
#
# dcutil - Development Container Utility
# https://github.com/dtg01100/dcutil
#
# Core functionality for dcutil
# Handles basic operations and command routing

# Exit codes
EXIT_SUCCESS=0
export EXIT_SUCCESS
EXIT_INVALID_ARGS=1
# The following exit codes are used by other sourced modules; mark as intentionally exported/externally used
# shellcheck disable=SC2034
EXIT_DEP_NOT_FOUND=2
EXIT_DOCKER_ERROR=3
EXIT_DEVCONTAINER_ERROR=4
EXIT_PERMISSION_ERROR=5
EXIT_CONFIG_ERROR=6

# Ensure these constants are visible to sourced modules and subshells
export EXIT_DEP_NOT_FOUND EXIT_DOCKER_ERROR DETECTED_BACKEND

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Constants
DEFAULT_DISK_SPACE_MB=100  # Minimum disk space requirement in MB

# Global variables
PROJECT_DIR=""
DETECTED_BACKEND=""

# Guardrail functions
check_root_user() {
if [ "$(id -u)" -eq 0 ]; then
        warning "Running as root user - this may cause permission issues with devcontainers"
        if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ "${DCUTIL_ALLOW_ROOT:-}" = "1" ]; then
            return 0
        fi
        if [ -t 0 ]; then
            echo ""
            read -r -p "Continue anyway? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy] ]]; then
                info "Operation cancelled"
                exit "$EXIT_PERMISSION_ERROR"
            fi
        else
            info "Non-interactive mode - cancelling root operation"
            exit "$EXIT_PERMISSION_ERROR"
        fi
    fi
}

# Require devcontainer CLI to be installed for dcutil to function correctly
require_devcontainer_cli() {
    if ! command -v devcontainer >/dev/null 2>&1; then
        error_exit "The official devcontainer CLI is required by dcutil. Please install it: https://github.com/devcontainers/cli" "$EXIT_DEP_NOT_FOUND"
    fi
}

check_root_user

check_disk_space() {
    local required_mb="${1:-$DEFAULT_DISK_SPACE_MB}"
    local available_mb=""

    # Check available disk space in MB
    if command -v df >/dev/null 2>&1; then
        available_mb=$(df -m "$PROJECT_DIR" 2>/dev/null | tail -1 | { read -r _ _ _ avail _; echo "$avail"; })
        if [ -n "$available_mb" ] && [ "$available_mb" -lt "$required_mb" ]; then
            warning "Low disk space: ${available_mb}MB available, ${required_mb}MB recommended"
            if [ -t 0 ] && [ "${DCUTIL_IGNORE_DISK_SPACE:-}" != "1" ]; then
                echo ""
                read -r -p "Continue anyway? (y/N): " confirm
                if [[ ! "$confirm" =~ ^[Yy] ]]; then
                    info "Operation cancelled"
                    exit "$EXIT_PERMISSION_ERROR"
                fi
            fi
        fi
    fi
}

validate_container_state() {
    local container_name="$1"
    local expected_state="$2"  # "running", "stopped", "exists", "not_exists"

    case "$expected_state" in
        "running")
            if ! docker container inspect "$container_name" >/dev/null 2>&1 || \
               ! docker container inspect "$container_name" | grep -q '"Running": true'; then
                error_exit "Container '$container_name' is not running" "$EXIT_DEVCONTAINER_ERROR"
            fi
            ;;
        "stopped")
            if ! docker container inspect "$container_name" >/dev/null 2>&1 || \
               docker container inspect "$container_name" | grep -q '"Running": true'; then
                error_exit "Container '$container_name' is not stopped" "$EXIT_DEVCONTAINER_ERROR"
            fi
            ;;
        "exists")
            if ! docker container inspect "$container_name" >/dev/null 2>&1; then
                error_exit "Container '$container_name' does not exist" "$EXIT_DEVCONTAINER_ERROR"
            fi
            ;;
        "not_exists")
            if docker container inspect "$container_name" >/dev/null 2>&1; then
                error_exit "Container '$container_name' already exists" "$EXIT_DEVCONTAINER_ERROR"
            fi
            ;;
    esac
}

log_dangerous_operation() {
    local operation="$1"
    local details="${2:-}"

    # Log to stderr for visibility, but only if not in quiet mode
    if [ "${DCUTIL_QUIET:-}" != "1" ]; then
        echo "🔒 Operation logged: $operation" >&2
        if [ -n "$details" ]; then
            echo "   Details: $details" >&2
        fi
    fi

    # Could also log to a file if DCUTIL_LOG_FILE is set
    if [ -n "${DCUTIL_LOG_FILE:-}" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') $operation $details" >> "$DCUTIL_LOG_FILE"
    fi
}

# Detect which backend the devcontainer CLI is using for a project
detect_cli_backend() {
    local project_dir="${1:-$PROJECT_DIR}"
    if [ -z "$project_dir" ]; then
        return 1
    fi

    # Check Docker first
    if command -v docker >/dev/null 2>&1; then
        local docker_match
        docker_match=$(docker ps -a --filter "label=devcontainer.local_folder=$project_dir" --format "{{.Names}}" 2>/dev/null | head -1 || true)
        if [ -n "$docker_match" ]; then
            DETECTED_BACKEND="docker"
            return 0
        fi
    fi

    # Check Podman
    if command -v podman >/dev/null 2>&1; then
        local podman_match
        podman_match=$(podman ps -a --filter "label=devcontainer.local_folder=$project_dir" --format "{{.Names}}" 2>/dev/null | head -1 || true)
        if [ -n "$podman_match" ]; then
            DETECTED_BACKEND="podman"
            return 0
        fi
    fi

    # Fallback to dcutil's backend setting
    if [ "${PODMAN_BACKEND_ENABLED:-false}" = true ]; then
        DETECTED_BACKEND="podman"
    else
        DETECTED_BACKEND="docker"
    fi
}

# Error handling functions
error_exit() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    exit "${2:-$EXIT_INVALID_ARGS}"
}

error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
}

success() {
    if [ "${DCUTIL_QUIET:-0}" = "1" ]; then
        return 0
    fi
    echo -e "${GREEN}✅ $1${NC}" >&2
}

info() {
    if [ "${DCUTIL_QUIET:-0}" = "1" ]; then
        return 0
    fi
    echo -e "${BLUE}INFO: $1${NC}" >&2
}

warning() {
    if [ "${DCUTIL_QUIET:-0}" = "1" ]; then
        return 0
    fi
    echo -e "${YELLOW}Warning: $1${NC}" >&2
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

    local ans=""
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
    local valid_commands="up down restart enter build clean status stats logs list run init check ssh volumes compose features advanced integration merging userprobe hostrequirements shutdown schema podman version help completion test verify-dialog edit"

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

    # Basic input validation - block dangerous patterns
    local cmd_string="$*"
    if [[ "$cmd_string" =~ (\$\(|\`|\$\{.*\$\{.*\}) ]]; then
        error_exit "Command contains dangerous shell constructs that are not allowed: $cmd_string" "$EXIT_INVALID_ARGS"
    fi

    # Additional security checks for common injection patterns
    if [[ "$cmd_string" =~ (\;|\||\&|>|<\||<<|>>|\$\(.*\)) ]]; then
        error_exit "Command contains shell metacharacters that are not allowed: $cmd_string" "$EXIT_INVALID_ARGS"
    fi
}

# Validate and sanitize user input
validate_user_input() {
    local input="$1"
    local input_type="${2:-general}"

    # Remove null bytes and other dangerous characters using Python
    input=$(python3 -c "import sys; s=sys.argv[1]; print(''.join(c for c in s if ord(c) >= 32 and ord(c) != 127))" "$input")

    # Length limits based on input type
    case "$input_type" in
        "command")
            if [ ${#input} -gt 10000 ]; then
                error_exit "Command too long (max 10000 characters)" "$EXIT_INVALID_ARGS"
            fi
            ;;
        "path")
            if [ ${#input} -gt 4096 ]; then
                error_exit "Path too long (max 4096 characters)" "$EXIT_INVALID_ARGS"
            fi
            # Basic path validation
            if [[ "$input" =~ \.\. ]]; then
                warning "Path contains '..' which may be unsafe"
            fi
            ;;
        "agent")
            if [[ ! "$input" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                error_exit "Invalid agent name format (only alphanumeric, dash, and underscore allowed)" "$EXIT_INVALID_ARGS"
            fi
            ;;
    esac

    echo "$input"
}

validate_init_mode() {
    local mode="${1:-}"
    local valid_modes="fast wizard clean --fast --wizard --clean --help -h --non-interactive -n"

    if [ -n "$mode" ] && [[ ! " $valid_modes " =~ $mode ]]; then
        error_exit "Unknown init mode: '$mode'. Use 'dcutil init --help' for usage information." "$EXIT_INVALID_ARGS"
    fi
}

# Enhanced path validation
validate_safe_path() {
    local path="$1"

    # Check for dangerous characters
    if [[ "$path" == *"'"'"'* ]] || [[ "$path" == *'$'* ]] || [[ "$path" == *"\""* ]]; then
        error_exit "Path contains unsafe characters: $path" "$EXIT_INVALID_ARGS"
    fi

    # Prevent path traversal attacks
    if [[ "$path" == *".."* ]]; then
        # Allow .. only if it's part of a legitimate relative path structure
        # But block obvious traversal attempts
        if [[ "$path" =~ ^\.\./ || "$path" =~ /\.\./ || "$path" =~ ^\.\.$ ]]; then
            error_exit "Path traversal not allowed: $path" "$EXIT_INVALID_ARGS"
        fi
    fi

    # Additional security checks
    if [[ "$path" == "/"* ]] && [[ "$path" != "/tmp"* ]] && [[ "$path" != "/home"* ]] && [[ "$path" != "/usr/local"* ]]; then
        # Allow some system paths but warn about sensitive ones
        if [[ "$path" == "/etc"* ]] || [[ "$path" == "/var"* ]] || [[ "$path" == "/root"* ]]; then
            warning "Accessing system path: $path"
        fi
    fi
}

## Allow tilde detection without relying on shell expansion; we'll handle it explicitly
# shellcheck disable=SC2088
safe_path() {
    local path="$1"
    if [ "${path:0:2}" = "~/" ]; then
        # handle paths beginning with ~/
        path="$HOME/${path:2}"
    elif [[ "$path" == "~" ]]; then
        path="$HOME"
    fi

    # Explicitly print the path (or absolute version) without reading from stdin
    python3 -c "import os, sys; print(os.path.abspath(sys.argv[1]))" "$path" 2>/dev/null || echo "$path"
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

    if ! jq -e . "$fp" >/dev/null 2>&1; then
        error_exit "Generated JSON at $fp is invalid" "$EXIT_CONFIG_ERROR"
    fi
}

# Validate a devcontainer config file using official devcontainer CLI
validate_devcontainer_config_cli() {
    local cfg="$1"
    if [ -z "$cfg" ] || [ ! -f "$cfg" ]; then
        error_exit "JSON file not found for devcontainer CLI validation: $cfg" "$EXIT_CONFIG_ERROR"
    fi

    if ! command -v devcontainer >/dev/null 2>&1; then
        error_exit "The official devcontainer CLI is required for this operation. Install it: https://github.com/devcontainers/cli" "$EXIT_DEP_NOT_FOUND"
    fi

    if ! devcontainer read-configuration --workspace-folder "$PROJECT_DIR" --config "$cfg" >/dev/null 2>&1; then
        return 1
    fi
    return 0
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
        DEVCONTAINER_CONFIG_FILE=$(python3 -c "import os; print(os.path.abspath('$cfg'))" 2>/dev/null || echo "$cfg")
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

# Generic unknown subcommand handler
handle_unknown_subcommand() {
    local command_name="$1"
    local subcommand="$2"
    error_exit "Unknown '${command_name}' subcommand: ${subcommand}. Use 'dcutil ${command_name} help' for usage." "$EXIT_INVALID_ARGS"
}

# Common argument validation utilities
validate_min_args() {
    local min_args="$1"
    local usage_msg="$2"

    if [ $# -lt 2 ]; then
        error_exit "validate_min_args requires min_args and usage_msg" "$EXIT_INVALID_ARGS"
    fi

    shift 2  # Remove min_args and usage_msg from arguments

    if [ $# -lt "$min_args" ]; then
        error_exit "$usage_msg" "$EXIT_INVALID_ARGS"
    fi
}

validate_has_args() {
    local usage_msg="$1"
    shift

    if [ $# -eq 0 ]; then
        error_exit "$usage_msg" "$EXIT_INVALID_ARGS"
    fi
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
