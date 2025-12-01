#!/usr/bin/env bash
#
# dcutil - Development Container Utility
# https://github.com/dtg01100/dcutil
#
# UX enhancements for beginner-friendly command-line experience

# Calculate Levenshtein distance between two strings (for command suggestions)
levenshtein_distance() {
    local s1="$1"
    local s2="$2"
    local len1=${#s1}
    local len2=${#s2}
    
    # Simple distance calculation for small strings
    if [ "$s1" = "$s2" ]; then
        echo 0
        return
    fi
    
        if [ "$len1" -eq 0 ]; then
        echo "$len2"
        return
    fi
    
        if [ "$len2" -eq 0 ]; then
        echo "$len1"
        return
    fi
    
    # For very short strings, use a simple approach
    local distance=0
    local i=0
        while [ "$i" -lt "$len1" ] && [ "$i" -lt "$len2" ]; do
        local c1="${s1:$i:1}"
        local c2="${s2:$i:1}"
        if [ "$c1" != "$c2" ]; then
            distance=$((distance + 1))
        fi
        i=$((i + 1))
    done
    
    # Add remaining characters
    distance=$((distance + len1 - i + len2 - i))
    echo $distance
}

# Suggest similar commands when user enters an invalid command
suggest_command() {
    local invalid_cmd="$1"
    # Prefer arrays for command lists to avoid word-splitting/globbing issues
    local -a valid_commands=(
        up down restart enter build clean status stats logs list run init check
        volumes features ssh compose advanced integration
        hostrequirements rebuild schema version completion help
    )
    
    local best_match=""
    local best_distance=999
    local threshold=3  # Maximum distance to suggest
    
    for cmd in "${valid_commands[@]}"; do
        local dist
        dist=$(levenshtein_distance "$invalid_cmd" "$cmd")
        if [ "$dist" -lt "$best_distance" ] && [ "$dist" -le "$threshold" ]; then
            best_distance=$dist
            best_match="$cmd"
        fi
    done
    
    if [ -n "$best_match" ]; then
        echo ""
        echo "💡 Did you mean: dcutil $best_match"
        echo ""
        echo "Run 'dcutil help' to see all available commands"
        return 0
    else
        return 1
    fi
}

# Show interactive menu for command discovery
show_interactive_menu() {
    echo ""
    echo "🚀 What would you like to do?"
    echo ""
    echo "  1) Start my development environment"
    echo "  2) Open a shell in my environment"
    echo "  3) Stop my environment"
    echo "  4) Check if my environment is running"
    echo "  5) Monitor resource usage (CPU, memory)"
    echo "  6) Set up a new project"
    echo "  7) View logs"
    echo "  8) Manage shared storage"
    echo "  9) Manage devcontainer features"
    echo "  10) See all commands"
    echo "  0) Exit"
    echo ""
    read -r -p "Enter your choice (1-10, 0): " choice

    case "$choice" in
        1)
            echo ""
            info "Starting your development environment..."
            return 1  # Signal to run 'up' command
            ;;
        2)
            echo ""
            info "Opening a shell in your environment..."
            return 2  # Signal to run 'enter' command
            ;;
        3)
            echo ""
            info "Stopping your environment..."
            return 3  # Signal to run 'down' command
            ;;
        4)
            echo ""
            info "Checking environment status..."
            return 4  # Signal to run 'status' command
            ;;
        5)
            echo ""
            info "Showing resource usage..."
            return 5  # Signal to run 'stats' command
            ;;
        6)
            echo ""
            info "Setting up a new project..."
            return 6  # Signal to run 'init' command
            ;;
        7)
            echo ""
            info "Viewing logs..."
            return 7  # Signal to run 'logs' command
            ;;
        8)
            echo ""
            info "Managing shared storage..."
            return 8  # Signal to run 'volumes list' command
            ;;
        9)
            # Check if currently in a configured project directory
            if [ -f ".devcontainer/devcontainer.json" ] || [ -f "devcontainer.json" ]; then
                echo ""
                info "Managing devcontainer features..."
                if command -v show_interactive_feature_management >/dev/null 2>&1; then
                    show_interactive_feature_management
                    return 0  # Show menu again after feature management
                else
                    warning "Feature management interface not available"
                    return 0  # Show menu again
                fi
            else
                warning "No devcontainer configuration found in current directory"
                info "Please change to a directory with a devcontainer configuration"
                return 0  # Show menu again
            fi
            ;;
        10)
            return 9  # Signal to show help (reuse the return code)
            ;;
        0)
            echo ""
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo ""
            warning "Invalid choice. Please enter a number between 0 and 10."
            return 0  # Signal to show menu again
            ;;
    esac
}

# Execute command based on menu choice
execute_menu_choice() {
    local choice=$1
    shift  # Remove choice from arguments

    case $choice in
        1) return 1 ;;  # up
        2) return 2 ;;  # enter
        3) return 3 ;;  # down
        4) return 4 ;;  # status
        5) return 5 ;;  # stats
        6) return 6 ;;  # init
        7) return 7 ;;  # logs
        8) return 8 ;;  # volumes list
        9) return 9 ;;  # help (originally for menu option 10, reused here)
        *) return 0 ;;  # show menu again
    esac
}

# Show contextual tips based on environment state
show_contextual_tips() {
    local context="$1"  # "no-config", "not-running", "running", etc.
    
    case "$context" in
        "no-config")
            echo ""
            echo "💡 Tip: No development environment found yet."
            echo "   Run 'dcutil init' to set one up (takes about 30 seconds)"
            echo ""
            ;;
        "not-running")
            echo ""
            echo "💡 Tip: Your environment is configured but not running."
            echo "   Run 'dcutil up' to start it"
            echo ""
            ;;
        "running")
            echo ""
            echo "✅ Your environment is running!"
            echo "   • Run 'dcutil enter' to open a shell"
            echo "   • Run 'dcutil stats' to check resource usage"
            echo ""
            ;;
        "first-time")
            echo ""
            echo "👋 Welcome to dcutil!"
            echo ""
            echo "Quick start guide:"
            echo "  1. Run 'dcutil init' to set up your development environment"
            echo "  2. Run 'dcutil up' to start it"
            echo "  3. Run 'dcutil enter' to jump into a shell"
            echo ""
            echo "Need help? Run 'dcutil help' or 'dcutil' for an interactive menu"
            echo ""
            ;;
    esac
}

# Show progress indicator for long operations
show_progress() {
    local message="$1"
    shift
    # Capture the full command string to execute (join args safely)
    local cmd_str="$*"
    
    local spinners=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    
    # Execute command in background and capture its PID
    eval "$cmd_str" &
    local pid=$!
    
    # Hide cursor
    tput civis 2>/dev/null || true
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r%s %s" "${spinners[$i]}" "$message"
        i=$(( (i + 1) % 10 ))
        sleep 0.1
    done
    
    # Wait for command to complete and get exit code
    wait $pid
    local exit_code=$?
    
    # Show cursor
    tput cnorm 2>/dev/null || true
    printf "\r"
    
    return $exit_code
}

# Check if this is first run
is_first_run() {
    local marker_file="${HOME}/.dcutil_first_run"
    
    if [ ! -f "$marker_file" ]; then
        # Create marker file
        mkdir -p "$(dirname "$marker_file")"
        touch "$marker_file" 2>/dev/null || true
        return 0  # Is first run
    else
        return 1  # Not first run
    fi
}

# Show quick start guide for first-time users
show_first_time_welcome() {
    # Only show the interactive welcome and prompt on real interactive terminals
    # (both stdin and stdout must be TTYs). When running in CI or piped contexts
    # we must avoid prompting and blocking.
    if ! [ -t 0 ] || ! [ -t 1 ]; then
        return 0
    fi

    if is_first_run; then
        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║                    👋 Welcome to dcutil!                      ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "dcutil helps you manage development environments with ease."
        echo "No Docker knowledge required!"
        echo ""
        echo "🚀 Quick Start:"
        echo ""
        echo "  1️⃣  dcutil init    → Set up a new environment (auto-detects your project)"
        echo "  2️⃣  dcutil up      → Start your environment"
        echo "  3️⃣  dcutil enter   → Jump into a shell"
        echo ""
        echo "💡 Helpful Commands:"
        echo ""
        echo "  • dcutil stats     → See resource usage (CPU, memory)"
        echo "  • dcutil logs      → View what's happening"
        echo "  • dcutil help      → See all commands"
        echo "  • dcutil           → Interactive menu (just run without arguments)"
        echo ""
        echo "────────────────────────────────────────────────────────────────"
        echo ""
        
        read -r -p "Press Enter to continue or type 'menu' for interactive mode: " response
        if [[ "$response" =~ ^[Mm][Ee][Nn][Uu]$ ]]; then
            return 1  # Signal to show menu
        fi
        return 0
    fi
    return 0
}

# Show smart suggestions based on current command
show_smart_suggestions() {
    local command="$1"
    local context="$2"
    
    case "$command" in
        "up")
            if [ "$context" = "already-running" ]; then
                echo ""
                echo "💡 Your environment is already running!"
                echo "   Try: dcutil enter    → Open a shell"
                echo "   Try: dcutil stats    → Check resource usage"
                echo ""
            fi
            ;;
        "enter")
            if [ "$context" = "not-running" ]; then
                echo ""
                echo "💡 Your environment isn't running yet."
                echo "   Tip: Use 'dcutil up' first, or just press 'y' when prompted"
                echo ""
            fi
            ;;
        "init")
            if [ "$context" = "already-configured" ]; then
                echo ""
                echo "💡 This project already has an environment configured!"
                echo "   Try: dcutil up       → Start it"
                echo "   Try: dcutil check    → Verify the configuration"
                echo ""
            fi
            ;;
    esac
}

# Enhanced error messages with next steps
show_error_with_help() {
    local error_type="$1"
    shift
    # Join any remaining args into a single string for display
    local error_details="$*"
    
    echo ""
    case "$error_type" in
        "no-docker")
            error "⚠️  Docker is not running or not installed"
            echo ""
            echo "Next steps:"
            echo "  1. Install Docker: https://docs.docker.com/get-docker/"
            echo "  2. Start Docker Desktop (if on Mac/Windows)"
            echo "  3. Or run: brew install --cask docker  (on macOS)"
            ;;
        "no-config")
            error "⚠️  No development environment configuration found"
            echo ""
            echo "Next steps:"
            echo "  1. Run: dcutil init"
            echo "  2. This will set up a new environment (takes ~30 seconds)"
            echo "  3. It auto-detects your project type (Python, Node.js, etc.)"
            ;;
        "permission-denied")
            error "⚠️  Permission denied: $error_details"
            echo ""
            echo "Next steps:"
            echo "  1. Check file permissions in your project"
            echo "  2. Make sure you have write access to the project directory"
            echo "  3. Try running with appropriate permissions"
            ;;
        *)
            error "⚠️  $error_details"
            ;;
    esac
    echo ""
}

# Show completion hints for partial commands
show_completion_hints() {
    local partial="$1"
    local commands="up down restart enter build clean status stats logs list run init check volumes features"
    
    echo ""
    echo "Available commands starting with '$partial':"
    echo ""
    for cmd in $commands; do
        if [[ "$cmd" == "$partial"* ]]; then
            printf "  • %-12s " "$cmd"
            case "$cmd" in
                "up") echo "- Start your environment" ;;
                "down") echo "- Stop your environment" ;;
                "restart") echo "- Restart your environment" ;;
                "enter") echo "- Open a shell" ;;
                "build") echo "- Build/rebuild" ;;
                "clean") echo "- Remove all data" ;;
                "status") echo "- Check if running" ;;
                "stats") echo "- Monitor resources" ;;
                "logs") echo "- View logs" ;;
                "list") echo "- List all environments" ;;
                "run") echo "- Run a command" ;;
                "init") echo "- Set up new environment" ;;
                "check") echo "- Verify configuration" ;;
                "volumes") echo "- Manage storage" ;;
                "features") echo "- Add tools/languages" ;;
                *) echo "" ;;
            esac
        fi
    done
    echo ""
}

# Interactive feature management for already configured devcontainer
show_interactive_feature_management() {
    # Ensure we're in the project directory with a devcontainer config
    if [ ! -f ".devcontainer/devcontainer.json" ] && [ ! -f "devcontainer.json" ]; then
        error "No devcontainer configuration found in current directory"
        info "Please change to a directory with a devcontainer configuration first"
        return 1
    fi

    # Initialize the devcontainer configuration variables
    if command -v parse_devcontainer_config >/dev/null 2>&1; then
        parse_devcontainer_config
    else
        error "parse_devcontainer_config function not available"
        return 1
    fi

    echo ""
    echo "🔧 Interactive Feature Management"
    echo "=================================="
    echo ""

    # Load available features from registry
    info "Loading available features..."
    local features_json
    if command -v fetch_available_features_official >/dev/null 2>&1; then
        features_json=$(fetch_available_features_official 2>/dev/null || echo "[]")
    else
        # Fallback to a basic feature list
        features_json='[
          {"id": "node", "name": "Node.js", "description": "Node.js runtime and package manager"},
          {"id": "python", "name": "Python", "description": "Python runtime and pip"},
          {"id": "go", "name": "Go", "description": "Go programming language"},
          {"id": "rust", "name": "Rust", "description": "Rust programming language"},
          {"id": "git", "name": "Git", "description": "Git version control"},
          {"id": "common-utils", "name": "Common Utilities", "description": "curl, wget, git, and other common tools"}
        ]'
    fi

    # Parse current features using the same function as other features code
    if ! command -v parse_features_config >/dev/null 2>&1; then
        # If parse_features_config is not available, manually parse features
        if command -v jq >/dev/null 2>&1; then
            local current_features_json
            if [ -n "${DEVCONTAINER_CONFIG_FILE:-}" ]; then
                current_features_json=$(jq -r '.features // {}' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "{}")
            else
                error "No devcontainer configuration file set"
                return 1
            fi
        else
            error "jq is required to parse features"
            return 1
        fi
    else
        # Use the existing features parsing functionality
        if ! parse_features_config; then
            # If no features configured, set to empty object
            local current_features_json="{}"
        else
            # Extract current features from the global variable
            local current_features_json="{}"
            if command -v jq >/dev/null 2>&1 && [ -n "${DEVCONTAINER_CONFIG_FILE:-}" ]; then
                current_features_json=$(jq -r '.features // {}' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "{}")
            fi
        fi
    fi

    local choice
    while true; do
        echo ""
        echo "📋 Current features in your configuration:"
        if [ "$current_features_json" = "{}" ] || [ "$(echo "$current_features_json" | jq length 2>/dev/null)" -eq 0 ]; then
            echo "  (No features configured)"
        else
            echo "$current_features_json" | jq -r 'to_entries[] | "  - \(.key): \(.value // {} | tojson)"' 2>/dev/null || echo "  (Could not parse features)"
        fi
        echo ""
        echo "What would you like to do?"
        echo "  1) Add a feature"
        echo "  2) Remove a feature"
        echo "  3) View available features"
        echo "  4) Save changes and exit"
        echo "  5) Exit without saving"
        echo ""
        read -r -p "Enter your choice (1-5): " choice

        case "$choice" in
            1)
                # Add a feature
                echo ""
                echo "Available features:"
                echo "$features_json" | jq -r '.[] | "  \(.id): \(.name) - \(.description)"' 2>/dev/null || {
                    echo "  node: Node.js runtime"
                    echo "  python: Python runtime"
                    echo "  go: Go programming language"
                    echo "  rust: Rust programming language"
                    echo "  git: Git version control"
                    echo "  common-utils: Common utilities"
                }
                echo ""

                read -r -p "Enter feature ID to add: " feature_id
                if [ -n "$feature_id" ]; then
                    # Check if feature already exists
                    if command -v jq >/dev/null 2>&1 && [ "$current_features_json" != "{}" ]; then
                        local exists
                        exists=$(echo "$current_features_json" | jq -r "has(\"$feature_id\")" 2>/dev/null)
                        if [ "$exists" = "true" ]; then
                            warning "Feature '$feature_id' is already configured"
                            continue
                        fi
                    fi

                    echo "Adding feature: $feature_id"
                    # Use the function from features.sh
                    if command -v add_feature_to_config >/dev/null 2>&1; then
                        add_feature_to_config "$feature_id" "{}"
                        # Refresh current features
                        current_features_json=$(jq -r '.features // {}' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "{}")
                    else
                        error "add_feature_to_config function not available"
                    fi
                fi
                ;;
            2)
                # Remove a feature
                if [ "$current_features_json" = "{}" ] || [ "$(echo "$current_features_json" | jq length 2>/dev/null)" -eq 0 ]; then
                    warning "No features configured to remove"
                    continue
                fi

                echo ""
                echo "Currently configured features:"
                local current_feature_keys
                current_feature_keys=$(echo "$current_features_json" | jq -r 'keys[]' 2>/dev/null)
                local i=1
                local feature_array=()
                while IFS= read -r key; do
                    if [ -n "$key" ]; then
                        feature_array+=("$key")
                        echo "  $i) $key"
                    fi
                    ((i++))
                done <<< "$current_feature_keys"

                echo ""
                read -r -p "Enter the number of the feature to remove: " remove_choice
                if [[ "$remove_choice" =~ ^[0-9]+$ ]] && [ "$remove_choice" -ge 1 ] && [ "$remove_choice" -le "${#feature_array[@]}" ]; then
                    local feature_to_remove="${feature_array[$((remove_choice-1))]}"
                    echo "Removing feature: $feature_to_remove"
                    # Use the function from features.sh
                    if command -v remove_feature_from_config >/dev/null 2>&1; then
                        remove_feature_from_config "$feature_to_remove"
                        # Refresh current features
                        current_features_json=$(jq -r '.features // {}' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "{}")
                    else
                        error "remove_feature_from_config function not available"
                    fi
                else
                    warning "Invalid choice"
                fi
                ;;
            3)
                # View available features
                echo ""
                echo "Available features:"
                echo "$features_json" | jq -r '.[] | "  \(.id): \(.name) - \(.description)"' 2>/dev/null || {
                    echo "  node: Node.js runtime"
                    echo "  python: Python runtime"
                    echo "  go: Go programming language"
                    echo "  rust: Rust programming language"
                    echo "  git: Git version control"
                    echo "  common-utils: Common utilities"
                }
                echo ""
                ;;
            4)
                # Save changes and exit
                info "Changes have been saved to your devcontainer configuration"
                info "To apply the changes, run: dcutil rebuild"
                return 0
                ;;
            5)
                # Exit without saving
                info "Exiting without saving changes"
                return 0
                ;;
            *)
                warning "Invalid choice. Please enter a number between 1 and 5."
                ;;
        esac
    done
}
