#!/usr/bin/env bash

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
    
    if [ $len1 -eq 0 ]; then
        echo $len2
        return
    fi
    
    if [ $len2 -eq 0 ]; then
        echo $len1
        return
    fi
    
    # For very short strings, use a simple approach
    local distance=0
    local i=0
    while [ $i -lt $len1 ] && [ $i -lt $len2 ]; do
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
    local valid_commands="up down restart enter build clean status stats logs list run init check volumes features install-agent ssh compose advanced integration hostrequirements rebuild schema version completion help"
    
    local best_match=""
    local best_distance=999
    local threshold=3  # Maximum distance to suggest
    
    for cmd in $valid_commands; do
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
    echo "  9) See all commands"
    echo "  0) Exit"
    echo ""
    read -r -p "Enter your choice (1-9, 0): " choice
    
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
            return 9  # Signal to show help
            ;;
        0)
            echo ""
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo ""
            warning "Invalid choice. Please enter a number between 0 and 9."
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
        9) return 9 ;;  # help
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
    local command="$@"
    
    local spinners=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    
    # Execute command in background and capture its PID
    eval "$command" &
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
    local error_details="$@"
    
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
