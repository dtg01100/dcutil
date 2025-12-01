#!/usr/bin/env bash
#
# dcutil - Development Container Utility
# https://github.com/dtg01100/dcutil
#
# Container resource monitoring for dcutil
# Provides CPU, memory, network, and disk I/O statistics

# Source core functionality
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Format bytes to human-readable size
format_bytes() {
    local bytes="$1"
    
    if [ -z "$bytes" ] || [ "$bytes" = "0" ]; then
        echo "0 B"
        return
    fi
    
    # Remove any non-numeric characters
    bytes="${bytes//[^0-9]/}"
    
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes} B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$((bytes / 1024)) KB"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$((bytes / 1048576)) MB"
    else
        echo "$((bytes / 1073741824)) GB"
    fi
}

# Parse memory limit and usage from docker/podman stats
parse_memory_stats() {
    local mem_usage="$1"
    local mem_limit="$2"
    
    if [ -z "$mem_usage" ] || [ -z "$mem_limit" ]; then
        echo "N/A"
        return
    fi
    
    # Calculate percentage
    local usage_bytes limit_bytes
    usage_bytes="${mem_usage//[^0-9.]/}"
    limit_bytes="${mem_limit//[^0-9.]/}"
    
    if [ -n "$usage_bytes" ] && [ -n "$limit_bytes" ] && [ "$limit_bytes" != "0" ]; then
        local percent
        percent=$(python3 -c "print(f'{($usage_bytes / $limit_bytes * 100):.1f}')")
        echo "$mem_usage / $mem_limit (${percent}%)"
    else
        echo "$mem_usage / $mem_limit"
    fi
}

# Show basic container statistics (one-time snapshot)
show_container_stats() {
    local container_name="$1"
    local follow="${2:-false}"
    
    if [ -z "$container_name" ]; then
        error_exit "Container name required" "$EXIT_INVALID_ARGS"
    fi
    
    # Check if container is running
    if command -v execute_container_command >/dev/null 2>&1; then
        if ! execute_container_command container inspect "$container_name" &>/dev/null; then
            echo ""
            echo "⚠️  Your development container is not currently running."
            echo ""
            echo "To start your container, use:"
            echo "  dcutil up"
            echo ""
            exit "$EXIT_DOCKER_ERROR"
        fi
        
        if ! execute_container_command container inspect "$container_name" | grep -q '"Running": true'; then
            echo ""
            echo "⚠️  Your development container exists but is stopped."
            echo ""
            echo "To start it, use:"
            echo "  dcutil up"
            echo ""
            exit "$EXIT_DOCKER_ERROR"
        fi
    else
        if ! docker container inspect "$container_name" &>/dev/null; then
            echo ""
            echo "⚠️  Your development container is not currently running."
            echo ""
            echo "To start your container, use:"
            echo "  dcutil up"
            echo ""
            exit "$EXIT_DOCKER_ERROR"
        fi
        
        if ! docker container inspect "$container_name" | grep -q '"Running": true'; then
            echo ""
            echo "⚠️  Your development container exists but is stopped."
            echo ""
            echo "To start it, use:"
            echo "  dcutil up"
            echo ""
            exit "$EXIT_DOCKER_ERROR"
        fi
    fi
    
    echo ""
    echo "📊 Resource Usage for Your Development Container"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Use docker/podman stats command
    if [ "$follow" = "true" ]; then
        echo "Live monitoring active (press Ctrl+C to stop)..."
        echo ""
        # Live streaming mode
        if command -v execute_container_command >/dev/null 2>&1; then
            execute_container_command stats "$container_name"
        else
            docker stats "$container_name"
        fi
    else
        # One-time snapshot with formatted output
        local stats_output
        if command -v execute_container_command >/dev/null 2>&1; then
            stats_output=$(execute_container_command stats --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}" "$container_name" 2>/dev/null)
        else
            stats_output=$(docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}" "$container_name" 2>/dev/null)
        fi
        
        if [ -n "$stats_output" ]; then
            echo "$stats_output"
            echo ""
            echo "💡 What does this mean?"
            echo ""
            echo "  • CPU %      - How much processing power is being used (higher = busier)"
            echo "  • MEM USAGE  - How much memory (RAM) your code is using"
            echo "  • MEM %      - Percentage of available memory being used"
            echo "  • NET I/O    - Data sent/received over the network"
            echo "  • BLOCK I/O  - Data read from or written to disk"
            echo "  • PIDS       - Number of running programs/processes"
            echo ""
            echo "📌 Tips:"
            echo "  • High CPU (>80%)?  Your code might be processing-intensive"
            echo "  • High Memory (>80%)? Consider optimizing or increasing limits"
            echo "  • Use 'dcutil stats watch' to see live updates"
            echo "  • Use 'dcutil stats detailed' to see configured limits"
            echo ""
        else
            warning "Could not retrieve container statistics"
        fi
    fi
}

# Show detailed container resource information
show_detailed_stats() {
    local container_name="$1"
    
    if [ -z "$container_name" ]; then
        error_exit "Container name required" "$EXIT_INVALID_ARGS"
    fi
    
    echo ""
    echo "🔍 Detailed Resource Information"
    echo ""
    
    # Get container inspect data
    local inspect_data
    if command -v execute_container_command >/dev/null 2>&1; then
        inspect_data=$(execute_container_command inspect "$container_name" 2>/dev/null)
    else
        inspect_data=$(docker inspect "$container_name" 2>/dev/null)
    fi
    
    if [ -z "$inspect_data" ]; then
        echo "⚠️  Could not retrieve detailed information. Your container may not be running."
        echo ""
        echo "Try 'dcutil up' to start your container first."
        echo ""
        exit "$EXIT_DOCKER_ERROR"
    fi
    
    # Extract resource limits and configuration
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Resource Limits (What's Allowed)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # CPU limits
    local cpu_shares cpu_quota cpu_period
    cpu_shares=$(echo "$inspect_data" | jq -r '.[0].HostConfig.CpuShares // "default"' 2>/dev/null || echo "N/A")
    cpu_quota=$(echo "$inspect_data" | jq -r '.[0].HostConfig.CpuQuota // "unlimited"' 2>/dev/null || echo "N/A")
    cpu_period=$(echo "$inspect_data" | jq -r '.[0].HostConfig.CpuPeriod // "default"' 2>/dev/null || echo "N/A")
    
    echo "CPU Limit:"
    if [ "$cpu_quota" != "unlimited" ] && [ "$cpu_quota" != "0" ] && [ "$cpu_quota" != "N/A" ]; then
        echo "  Limited to $cpu_quota μs per $cpu_period μs period"
        echo "  💡 This means your code can use a specific amount of processing time"
    else
        echo "  No limit - can use all available CPU"
        echo "  💡 Your code can use as much processing power as needed"
    fi
    
    # Print CPU shares if available
    if [ -n "$cpu_shares" ] && [ "$cpu_shares" != "N/A" ]; then
        echo "  Shares: $cpu_shares"
    fi
    echo ""
    # Memory limits
    local mem_limit mem_reservation mem_swap
    mem_limit=$(echo "$inspect_data" | jq -r '.[0].HostConfig.Memory // 0' 2>/dev/null || echo "0")
    mem_reservation=$(echo "$inspect_data" | jq -r '.[0].HostConfig.MemoryReservation // 0' 2>/dev/null || echo "0")
    mem_swap=$(echo "$inspect_data" | jq -r '.[0].HostConfig.MemorySwap // 0' 2>/dev/null || echo "0")
    
    echo "Memory Limit:"
    if [ "$mem_limit" = "0" ]; then
        echo "  No limit - can use all available memory"
        echo "  💡 Your code can use as much RAM as the system has"
    else
        echo "  Limited to $(format_bytes "$mem_limit")"
        echo "  Swap: $mem_swap"
        echo "  💡 Your code can use up to this much RAM before hitting the limit"
    fi
    
    if [ "$mem_reservation" != "0" ]; then
        echo ""
        echo "Memory Reserved:   $(format_bytes "$mem_reservation")"
        echo "  💡 This amount is guaranteed to be available"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Current Usage (Right Now)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Get real-time stats
    local stats_line
    if command -v execute_container_command >/dev/null 2>&1; then
        stats_line=$(execute_container_command stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.NetIO}}|{{.BlockIO}}|{{.PIDs}}" "$container_name" 2>/dev/null)
    else
        stats_line=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.NetIO}}|{{.BlockIO}}|{{.PIDs}}" "$container_name" 2>/dev/null)
    fi
    
    if [ -n "$stats_line" ]; then
        IFS='|' read -r cpu_perc mem_usage mem_perc net_io block_io pids <<< "$stats_line"
        
        echo "CPU Usage:         $cpu_perc"
        echo "  💡 How busy your code is right now"
        echo ""
        echo "Memory Usage:      $mem_usage ($mem_perc)"
        echo "  💡 How much RAM your code is currently using"
        echo ""
        echo "Network I/O:       $net_io"
        echo "  💡 Data transferred in/out (useful for web apps)"
        echo ""
        echo "Disk I/O:          $block_io"
        echo "  💡 Files read/written"
        echo ""
        echo "Active Processes:  $pids"
        echo "  💡 Number of programs running in your container"
    else
        warning "Could not retrieve real-time statistics"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "ℹ️  Container Info"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Show additional useful information
    local container_state restart_count
    container_state=$(echo "$inspect_data" | jq -r '.[0].State.Status // "unknown"' 2>/dev/null || echo "unknown")
    local started_at
    started_at=$(echo "$inspect_data" | jq -r '.[0].State.StartedAt // "unknown"' 2>/dev/null || echo "unknown")
    restart_count=$(echo "$inspect_data" | jq -r '.[0].RestartCount // 0' 2>/dev/null || echo "0")
    
    echo "State:             $container_state"
    echo "Started:           $started_at"
    echo "Restart Count:     $restart_count"
    
    # Show container IP
    local container_ip
    container_ip=$(echo "$inspect_data" | jq -r '.[0].NetworkSettings.Networks | to_entries | .[0].value.IPAddress // "N/A"' 2>/dev/null || echo "N/A")
    echo "IP Address:        $container_ip"
    
    echo ""
}

# Show top processes in container
show_container_top() {
    local container_name="$1"
    
    if [ -z "$container_name" ]; then
        error_exit "Container name required" "$EXIT_INVALID_ARGS"
    fi
    
    echo ""
    echo "🔄 Running Processes in Your Container"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "💡 This shows what programs are currently running inside your development environment."
    echo ""
    echo ""
    
    if command -v execute_container_command >/dev/null 2>&1; then
        execute_container_command top "$container_name" || error_exit "Failed to get process list" "$EXIT_DOCKER_ERROR"
    else
        docker top "$container_name" || error_exit "Failed to get process list" "$EXIT_DOCKER_ERROR"
    fi
}

# Main stats command handler
handle_stats_command() {
    local project_dir="${1:-$(pwd)}"
    local subcommand="${2:-show}"
    
    # Determine container name
    local container_name
    if [ -n "${CONTAINER_NAME:-}" ]; then
        container_name="$CONTAINER_NAME"
    else
        container_name=$(get_container_name_for_project "$project_dir")
    fi
    
    case "$subcommand" in
        "show"|"")
            show_container_stats "$container_name" false
            ;;
        "watch"|"live"|"follow"|"-f")
            show_container_stats "$container_name" true
            ;;
        "detailed"|"detail"|"full")
            show_detailed_stats "$container_name"
            ;;
        "top"|"ps"|"processes")
            show_container_top "$container_name"
            ;;
        "help"|"-h"|"--help")
            cat << 'EOF'
Usage: dcutil stats [command]

Check how much CPU, memory, and other resources your development container is using.

Commands:
  show       Quick snapshot - see resource usage right now (default)
  watch      Watch live - continuously monitor while you work
  detailed   Full details - see limits and detailed configuration
  top        Running programs - what's actively running inside

Shortcuts you can use:
  live, follow, -f   Same as 'watch'
  detail, full       Same as 'detailed'
  ps, processes      Same as 'top'

Common scenarios:
  dcutil stats              # "Is my code using a lot of resources?"
  dcutil stats watch        # "Monitor while my tests/build run"
  dcutil stats detailed     # "Am I hitting my memory limit?"
  dcutil stats top          # "What programs are actually running?"

Why use this?
  ✓ See if your code is using too much memory
  ✓ Check if CPU-intensive tasks are slowing things down
  ✓ Understand if you need to adjust resource limits
  ✓ Identify performance bottlenecks while developing
  ✓ No Docker/Podman knowledge required!

Tips:
  • High CPU (>80%)? Your code might be doing heavy processing
  • High Memory (>80%)? You might need more RAM or to optimize
  • Press Ctrl+C to exit the 'watch' view anytime
EOF
            ;;
        *)
            handle_unknown_subcommand "stats" "$subcommand"
            ;;
    esac
}

# Export functions
export -f show_container_stats
export -f show_detailed_stats
export -f show_container_top
export -f handle_stats_command
export -f format_bytes
export -f parse_memory_stats
