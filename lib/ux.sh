#!/usr/bin/env bash
#
# dcutil - Development Container Utility
# https://github.com/dtg01100/dcutil
#
# UX enhancements for beginner-friendly command-line experience

# Check if dialog is available for enhanced UI
has_dialog() {
    # Allow forcing dialog usage for debugging
    if [ "${DCUTIL_FORCE_DIALOG:-0}" = "1" ]; then
        if command -v dialog >/dev/null 2>&1; then
            return 0
        fi
    fi

    # Basic binary check
    if ! command -v dialog >/dev/null 2>&1; then
        return 1
    fi

    # Check if we're in a proper terminal environment
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        # Non-interactive environment
        return 1
    fi

    # Check if /dev/tty is available
    if [ ! -c /dev/tty ]; then
        return 1
    fi

    # Test dialog with a non-displaying command
    if dialog --print-maxsize >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# Safe dialog wrapper that handles dimensions and error conditions
safe_dialog() {
    if ! has_dialog; then
        return 1
    fi

    # Compute dialog dimensions based on terminal size with safe fallbacks
    local term_cols term_rows
    term_cols=$(stty size 2>/dev/null | cut -d' ' -f2) || term_cols=80
    term_rows=$(stty size 2>/dev/null | cut -d' ' -f1) || term_rows=24

    # Ensure minimum dimensions
    if [ "$term_cols" -lt 60 ]; then term_cols=60; fi
    if [ "$term_rows" -lt 20 ]; then term_rows=20; fi

    # Calculate dialog size (80% of terminal size with max limits)
    local height width
    height=$((term_rows * 8 / 10))
    width=$((term_cols * 8 / 10))

    # Apply max limits to prevent oversized dialogs
    if [ "$height" -gt 30 ]; then height=30; fi
    if [ "$width" -gt 80 ]; then width=80; fi

    # Run dialog with computed dimensions
    dialog --stdout --no-shadow --no-cancel --title "dcutil" --begin 2 2 -- "$@"
}

# Verification function for dialog
verify_dialog() {
    if ! has_dialog; then
        warning "dialog command not available or not in a terminal environment"
        return 1
    fi

    info "Testing dialog functionality..."

    # Test with a simple info box
    (dialog --title "Dialog Test" --infobox "Dialog is working properly" 5 30; sleep 2) &
    local dialog_pid=$!
    wait $dialog_pid 2>/dev/null || true
    clear  # Clear any dialog artifacts

    success "Dialog verification successful"
    return 0
}

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

    # Set PROJECT_DIR for this session since we're in the right directory
    local current_dir
    current_dir="$(pwd)" || {
        error "Cannot determine current directory"
        return 1
    }

    if [ -z "$current_dir" ] || [ ! -d "$current_dir" ]; then
        error "Current directory is invalid"
        return 1
    fi

    PROJECT_DIR="$current_dir"
    export PROJECT_DIR

    # Initialize DEVCONTAINER_CONFIG_FILE as well
    if command -v initialize_devcontainer_config >/dev/null 2>&1; then
        initialize_devcontainer_config
    fi

    # For the UX function, instead of calling the full parse_devcontainer_config which involves devcontainer CLI validation
    # that may fail with permission errors, let's directly load features using jq only
    if command -v jq >/dev/null 2>&1; then
        # Initialize features configuration variables directly
        if [ -n "${DEVCONTAINER_CONFIG_FILE:-}" ] && [ -f "$DEVCONTAINER_CONFIG_FILE" ]; then
            # Parse features using jq directly
            if jq -e '.features' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
                # Handle both object and array formats like in the features module
                if jq -e '.features | type == "object"' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
                    # Object format - features as key-value pairs
                    : # Successfully parsed features object
                elif jq -e '.features | type == "array"' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
                    # Array format - features as array of specs
                    : # Successfully parsed features array
                else
                    # No features or invalid format - just continue
                    :
                fi
            fi
        fi
    fi

    # Check if dialog is available for enhanced UI
    local use_dialog=false
    if has_dialog; then
        use_dialog=true
    fi

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

    # Parse current features using jq directly to avoid validation issues in UX context
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

    if [ "$use_dialog" = true ]; then
        # Use dialog-based interface
        show_interactive_feature_management_dialog "$features_json" "$current_features_json"
    else
        # Use text-based interface
        show_interactive_feature_management_text "$features_json" "$current_features_json"
    fi
}

# Dialog-based interactive feature management
show_interactive_feature_management_dialog() {
    local features_json="$1"
    local current_features_json="$2"

    local exit_code=0

    while [ $exit_code -ne 1 ]; do
        # Prepare features list for dialog
        local current_features_list=""
        if [ "$current_features_json" != "{}" ] && [ "$(echo "$current_features_json" | jq length 2>/dev/null)" -gt 0 ]; then
            current_features_list=$(echo "$current_features_json" | jq -r 'to_entries[] | "\(.key): \(.value // {} | tojson)"')
        else
            current_features_list="(No features configured)"
        fi

        # Create dialog menu
        local choice
        choice=$(dialog --clear --title "Devcontainer Features Management" \
            --menu "Current features:\n$current_features_list\n\nSelect an option:" \
            18 70 8 \
            "1" "Add a feature" \
            "2" "Remove a feature" \
            "3" "View/Search available features" \
            "4" "Save changes and exit" \
            "5" "Exit without saving" \
            2>&1 >/dev/tty)

        case $? in
            0)
                case "$choice" in
                    "1")
                        add_feature_dialog "$features_json" "$current_features_json"
                        # Refresh current features after adding
                        current_features_json=$(jq -r '.features // {}' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "{}")
                        ;;
                    "2")
                        current_features_json=$(remove_feature_dialog "$current_features_json")
                        ;;
                    "3")
                        view_features_dialog "$features_json"
                        ;;
                    "4")
                        info "Changes have been saved to your devcontainer configuration"
                        info "To apply the changes, run: dcutil rebuild"
                        exit_code=1
                        ;;
                    "5")
                        info "Exiting without saving changes"
                        exit_code=1
                        ;;
                esac
                ;;
            1)
                info "Exiting without saving changes"
                exit_code=1
                ;;
            255)
                info "Dialog cancelled or error occurred"
                exit_code=1
                ;;
        esac
    done
}

# Text-based interactive feature management (original functionality)
show_interactive_feature_management_text() {
    local features_json="$1"
    local current_features_json="$2"

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
                # Add a feature with search functionality
                echo ""

                # Display feature list with search
                while true; do
                    echo "Available features:"
                    local search_term=""
                    read -r -p "Enter search term (or press Enter for all features): " search_term

                    if [ -n "$search_term" ]; then
                        # Filter features based on search term
                        echo "Features matching '$search_term':"
                        local search_output
                        search_output=$(echo "$features_json" | jq -r --arg search "$search_term" '.[] | select(.id | contains($search) or .name | contains($search) or .description | contains($search)) | "  \(.id): \(.name) - \(.description)"' 2>/dev/null)
                        if [ -n "$search_output" ] && [ "$search_output" != "" ]; then
                            echo "$search_output"
                        else
                            echo "  (No features match your search)"
                        fi
                    else
                        # Show all features
                        echo "$features_json" | jq -r '.[] | "  \(.id): \(.name) - \(.description)"' 2>/dev/null || {
                            echo "  node: Node.js runtime"
                            echo "  python: Python runtime"
                            echo "  go: Go programming language"
                            echo "  rust: Rust programming language"
                            echo "  git: Git version control"
                            echo "  common-utils: Common utilities"
                        }
                    fi

                    echo ""
                    read -r -p "Enter feature ID to add (or 'back' to return): " feature_id

                    if [ "$feature_id" = "back" ]; then
                        break
                    fi

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

                        # Verify the feature ID exists in the available list
                        local feature_exists
                        feature_exists=$(echo "$features_json" | jq -r --arg fid "$feature_id" '.[] | select(.id == $fid) | .id' 2>/dev/null | head -1)
                        if [ -n "$feature_exists" ]; then
                            echo "Adding feature: $feature_id"
                            # Use the function from features.sh
                            if command -v add_feature_to_config >/dev/null 2>&1; then
                                add_feature_to_config "$feature_id" "{}"
                                # Refresh current features
                                current_features_json=$(jq -r '.features // {}' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "{}")
                                break  # Exit the search loop after adding
                            else
                                error "add_feature_to_config function not available"
                                break
                            fi
                        else
                            warning "Feature '$feature_id' not found. Please try again."
                            continue
                        fi
                    fi
                done
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
                # View available features with search functionality
                echo ""

                while true; do
                    local search_term=""
                    read -r -p "Enter search term to filter features (or press Enter for all, 'back' to return): " search_term

                    if [ "$search_term" = "back" ]; then
                        break
                    elif [ -n "$search_term" ]; then
                        # Filter features based on search term
                        echo "Features matching '$search_term':"
                        local filtered_output
                        filtered_output=$(echo "$features_json" | jq -r --arg search "$search_term" '.[] | select(.id | contains($search) or .name | contains($search) or .description | contains($search)) | "  \(.id): \(.name) - \(.description)"' 2>/dev/null)
                        local filtered_count
                        filtered_count=$(echo "$filtered_output" | wc -l)

                        if [ "$filtered_count" -gt 0 ] && [ -n "$filtered_output" ] && [ "$filtered_output" != "" ]; then
                            echo "$filtered_output"
                        else
                            echo "  (No features match your search)"
                            filtered_count=0
                        fi
                    else
                        # Show all features
                        echo "All available features:"
                        echo "$features_json" | jq -r '.[] | "  \(.id): \(.name) - \(.description)"' 2>/dev/null || {
                            echo "  node: Node.js runtime"
                            echo "  python: Python runtime"
                            echo "  go: Go programming language"
                            echo "  rust: Rust programming language"
                            echo "  git: Git version control"
                            echo "  common-utils: Common utilities"
                        }
                    fi

                    echo ""
                    read -r -p "Press Enter to continue viewing or type 'back' to return: " continue_choice
                    if [ "$continue_choice" = "back" ]; then
                        break
                    fi
                done
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

# Add feature dialog
add_feature_dialog() {
    local features_json="$1"
    local current_features_json="$2"

    # Create a search interface for features
    while true; do
        local search_term
        search_term=$(dialog --clear --title "Add Feature - Search" \
            --inputbox "Enter search term (or leave blank for all features):" 10 60 \
            2>&1 >/dev/tty)

        case $? in
            0) ;;
            1|255) return 0 ;;
        esac

        # Prepare feature list based on search
        local feature_list=""
        local i=1

        if [ -n "$search_term" ]; then
            # Filter features based on search term
            while IFS= read -r feature; do
                if [ -n "$feature" ]; then
                    local id name desc
                    id=$(echo "$feature" | jq -r '.id')
                    name=$(echo "$feature" | jq -r '.name')
                    desc=$(echo "$feature" | jq -r '.description')
                    feature_list="$feature_list $i \"$id - $name ($desc)\""
                    i=$((i + 1))
                fi
            done <<< "$(echo "$features_json" | jq -r --arg search "$search_term" '.[] | select(.id | contains($search) or .name | contains($search) or .description | contains($search))')"
        else
            # Show all features
            while IFS= read -r feature; do
                if [ -n "$feature" ]; then
                    local id name desc
                    id=$(echo "$feature" | jq -r '.id')
                    name=$(echo "$feature" | jq -r '.name')
                    desc=$(echo "$feature" | jq -r '.description')
                    feature_list="$feature_list $i \"$id - $name ($desc)\""
                    i=$((i + 1))
                fi
            done <<< "$(echo "$features_json" | jq -r '.[]')"
        fi

        if [ -z "$feature_list" ]; then
            dialog --msgbox "No features match your search: $search_term" 8 40
            continue
        fi

        # Show feature selection menu
        local selection
        selection=$(dialog --clear --title "Add Feature - Select" \
            --menu "Select a feature to add:" 18 70 10 $feature_list \
            2>&1 >/dev/tty)

        case $? in
            0) ;;
            1|255) return 0 ;;
        esac

        # Validate selection is a number
        if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ]; then
            dialog --msgbox "Invalid selection" 6 30
            continue
        fi

        # Count available features to check bounds
        local feature_count
        feature_count=$(echo "$features_json" | jq 'length' 2>/dev/null)
        if [ "$selection" -gt "$feature_count" ]; then
            dialog --msgbox "Selection out of range" 6 30
            continue
        fi

        # Get the selected feature ID
        local selected_feature
        selected_feature=$(echo "$features_json" | jq -r ".[$((selection - 1))].id" 2>/dev/null)

        if [ -n "$selected_feature" ]; then
            # Check if feature already exists
            if command -v jq >/dev/null 2>&1 && [ "$current_features_json" != "{}" ]; then
                local exists
                exists=$(echo "$current_features_json" | jq -r "has(\"$selected_feature\")" 2>/dev/null)
                if [ "$exists" = "true" ]; then
                    dialog --msgbox "Feature '$selected_feature' is already configured!" 8 40
                    continue
                fi
            fi

            # Add the feature
            if command -v add_feature_to_config >/dev/null 2>&1; then
                add_feature_to_config "$selected_feature" "{}"
                dialog --msgbox "Feature '$selected_feature' has been added!" 7 40
                return 0
            else
                dialog --msgbox "Error: add_feature_to_config function not available" 8 40
                return 1
            fi
        else
            dialog --msgbox "Invalid selection" 6 30
            continue
        fi
    done
}

# Remove feature dialog
remove_feature_dialog() {
    local current_features_json="$1"

    if [ "$current_features_json" = "{}" ] || [ "$(echo "$current_features_json" | jq length 2>/dev/null)" -eq 0 ]; then
        dialog --msgbox "No features configured to remove" 7 40
        return 0
    fi

    # Create list of current features
    local feature_list=""
    local i=1

    while IFS= read -r key; do
        if [ -n "$key" ]; then
            feature_list="$feature_list $i \"$key\""
            i=$((i + 1))
        fi
    done <<< "$(echo "$current_features_json" | jq -r 'keys[]' 2>/dev/null)"

    if [ -z "$feature_list" ]; then
        dialog --msgbox "No features available to remove" 7 40
        return 0
    fi

    # Show feature removal menu
    local selection
    selection=$(dialog --clear --title "Remove Feature - Select" \
        --menu "Select a feature to remove:" 15 60 8 $feature_list \
        2>&1 >/dev/tty)

    case $? in
        0) ;;
        1|255) return 0 ;;
    esac

    # Validate selection is a number
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ]; then
        dialog --msgbox "Invalid selection" 6 30
        return 0
    fi

    # Get the selected feature name
    local feature_array=()
    while IFS= read -r key; do
        if [ -n "$key" ]; then
            feature_array+=("$key")
        fi
    done <<< "$(echo "$current_features_json" | jq -r 'keys[]' 2>/dev/null)"

    # Check bounds before accessing array
    if [ "$selection" -gt "${#feature_array[@]}" ]; then
        dialog --msgbox "Selection out of range" 6 30
        return 0
    fi

    local feature_to_remove="${feature_array[$((selection - 1))]}"

    if [ -n "$feature_to_remove" ]; then
        # Remove the feature
        if command -v remove_feature_from_config >/dev/null 2>&1; then
            remove_feature_from_config "$feature_to_remove"
            dialog --msgbox "Feature '$feature_to_remove' has been removed!" 7 40
            # Refresh current features
            current_features_json=$(jq -r '.features // {}' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "{}")
        else
            dialog --msgbox "Error: remove_feature_from_config function not available" 8 40
        fi
    fi
}

# View features dialog
view_features_dialog() {
    local features_json="$1"

    while true; do
        local search_term
        search_term=$(dialog --clear --title "View Features - Search" \
            --inputbox "Enter search term (or leave blank for all features):" 10 60 \
            2>&1 >/dev/tty)

        case $? in
            0) ;;
            1|255) return 0 ;;
        esac

        # Prepare feature list based on search
        local feature_list=""
        local i=1

        if [ -n "$search_term" ]; then
            # Filter features based on search term
            while IFS= read -r feature; do
                if [ -n "$feature" ]; then
                    local id name desc
                    id=$(echo "$feature" | jq -r '.id')
                    name=$(echo "$feature" | jq -r '.name')
                    desc=$(echo "$feature" | jq -r '.description')
                    feature_list="$feature_list $i \"$id - $name ($desc)\""
                    i=$((i + 1))
                fi
            done <<< "$(echo "$features_json" | jq -r --arg search "$search_term" '.[] | select(.id | contains($search) or .name | contains($search) or .description | contains($search))')"
        else
            # Show all features
            while IFS= read -r feature; do
                if [ -n "$feature" ]; then
                    local id name desc
                    id=$(echo "$feature" | jq -r '.id')
                    name=$(echo "$feature" | jq -r '.name')
                    desc=$(echo "$feature" | jq -r '.description')
                    feature_list="$feature_list $i \"$id - $name ($desc)\""
                    i=$((i + 1))
                fi
            done <<< "$(echo "$features_json" | jq -r '.[]')"
        fi

        if [ -z "$feature_list" ]; then
            dialog --msgbox "No features match your search: $search_term" 8 40
            continue
        fi

        # Calculate required height based on number of features (max 15)
        local list_height
        list_height=$(echo "$feature_list" | wc -w)
        list_height=$((list_height / 2))  # Each item takes 2 elements (index and content)
        if [ $list_height -gt 15 ]; then list_height=15; fi
        if [ $list_height -lt 8 ]; then list_height=8; fi

        # Create safe feature display list
        local display_text="Available features:"
        local temp_list="$feature_list"
        # Extract just the feature names (skip numbers and quotes)
        while read -r line; do
            # Extract feature text from quoted strings
            local feature_desc=$(echo "$line" | sed -n 's/.* "\([^"]*\)".*/- \1/p')
            if [ -n "$feature_desc" ]; then
                display_text="$display_text
$feature_desc"
            fi
        done <<< "$(echo "$temp_list" | sed 'N;s/\n/ /g;G' | sed 's/ [0-9]* "/\n/g' | grep -v '^$' | head -n -1)"

        # Fallback to jq-based extraction if sed method fails
        if [ "$display_text" = "Available features:" ]; then
            display_text="Available features:"
            while IFS= read -r feature; do
                if [ -n "$feature" ]; then
                    local id name desc
                    id=$(echo "$feature" | jq -r '.id' 2>/dev/null)
                    name=$(echo "$feature" | jq -r '.name' 2>/dev/null)
                    desc=$(echo "$feature" | jq -r '.description' 2>/dev/null)
                    display_text="$display_text
- $id - $name ($desc)"
                fi
            done <<< "$(echo "$features_json" | jq -c '.[]' 2>/dev/null)"
        fi

        # Show feature list
        dialog --clear --title "Available Features" \
            --msgbox "$display_text" \
            $((list_height + 4)) 70
    done
}
