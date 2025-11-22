#!/bin/bash

# hostRequirements validation for dcutil
# Implements validation of system requirements per devcontainer specification

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for host requirements
HOST_REQUIREMENTS_CHECKED=false
HOST_REQUIREMENTS_ERRORS=()
HOST_REQUIREMENTS_WARNINGS=()

# Check if hostRequirements are configured
has_host_requirements() {
    if command -v jq &> /dev/null; then
        if jq -e '.hostRequirements' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Parse hostRequirements configuration
parse_host_requirements() {
    if ! has_host_requirements; then
        return 1
    fi
    
    info "Parsing hostRequirements configuration..."
    
    if command -v jq &> /dev/null; then
        # Extract host requirements
        local cpu_req gpu_req storage_req memory_req
        cpu_req=$(jq -r '.hostRequirements.cpu // empty' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        gpu_req=$(jq -r '.hostRequirements.gpu // empty' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        storage_req=$(jq -r '.hostRequirements.storage // empty' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        memory_req=$(jq -r '.hostRequirements.memory // empty' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        
        echo "$cpu_req|$gpu_req|$storage_req|$memory_req"
        return 0
    fi
    
    return 1
}

# Check CPU requirements
check_cpu_requirements() {
    local cpu_req="$1"
    
    if [ -z "$cpu_req" ]; then
        return 0
    fi
    
    info "Checking CPU requirements: $cpu_req"
    
    # Get number of CPU cores
    local cpu_count=1
    if [ -f /proc/cpuinfo ]; then
        cpu_count=$(nproc 2>/dev/null || grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "1")
    elif command -v sysctl >/dev/null 2>&1; then
        cpu_count=$(sysctl -n hw.ncpu 2>/dev/null || echo "1")
    fi
    
    # Parse CPU requirement (support formats like "2", ">=2", "2 cores")
    local required_cores
    if echo "$cpu_req" | grep -qE '^[0-9]+'; then
        required_cores=$(echo "$cpu_req" | sed -n 's/^\([0-9]*\).*/\1/p')
    elif echo "$cpu_req" | grep -qE '^>=.*'; then
        required_cores=$(echo "$cpu_req" | sed -n 's/^>=\([0-9]*\).*/\1/p')
    else
        warning "Unable to parse CPU requirement: $cpu_req"
        return 0
    fi
    
    if [ "$cpu_count" -lt "$required_cores" ]; then
        HOST_REQUIREMENTS_ERRORS+=("Insufficient CPU cores: found $cpu_count, required $required_cores")
        return 1
    else
        info "CPU requirements met: $cpu_count cores available, $required_cores required"
        return 0
    fi
}

# Check memory requirements
check_memory_requirements() {
    local memory_req="$1"
    
    if [ -z "$memory_req" ]; then
        return 0
    fi
    
    info "Checking memory requirements: $memory_req"
    
    # Get available memory in MB
    local memory_mb=1024
    if [ -f /proc/meminfo ]; then
        memory_mb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}' 2>/dev/null || echo "1024")
    elif command -v sysctl >/dev/null 2>&1; then
        memory_mb=$(sysctl -n hw.memsize_max 2>/dev/null || sysctl -n hw.physmem 2>/dev/null || echo "1073741824")
        memory_mb=$((memory_mb / 1024 / 1024))
    fi
    
    # Parse memory requirement (support formats like "2GB", "4 GB", ">=2GB")
    local required_mb
    if echo "$memory_req" | grep -qE '^[0-9]+.*GB?'; then
        required_mb=$(echo "$memory_req" | sed -n 's/^\([0-9]*\).*/\1/p')
        required_mb=$((required_mb * 1024))
    elif echo "$memory_req" | grep -qE '^[0-9]+.*MB?'; then
        required_mb=$(echo "$memory_req" | sed -n 's/^\([0-9]*\).*/\1/p')
    elif echo "$memory_req" | grep -qE '^>=.*GB?'; then
        required_mb=$(echo "$memory_req" | sed -n 's/^>=\([0-9]*\).*/\1/p')
        required_mb=$((required_mb * 1024))
    elif echo "$memory_req" | grep -qE '^>=.*MB?'; then
        required_mb=$(echo "$memory_req" | sed -n 's/^>=\([0-9]*\).*/\1/p')
    else
        warning "Unable to parse memory requirement: $memory_req"
        return 0
    fi
    
    if [ "$memory_mb" -lt "$required_mb" ]; then
        HOST_REQUIREMENTS_ERRORS+=("Insufficient memory: found ${memory_mb}MB, required ${required_mb}MB")
        return 1
    else
        info "Memory requirements met: ${memory_mb}MB available, ${required_mb}MB required"
        return 0
    fi
}

# Check storage requirements
check_storage_requirements() {
    local storage_req="$1"
    
    if [ -z "$storage_req" ]; then
        return 0
    fi
    
    info "Checking storage requirements: $storage_req"
    
    # Get available storage in GB (check current directory filesystem)
    local storage_gb=10
    if command -v df >/dev/null 2>&1; then
        storage_gb=$(df -BG . | tail -1 | awk '{print int(substr($4, 1, length($4)-1))}' 2>/dev/null || echo "10")
    fi
    
    # Parse storage requirement (support formats like "10GB", ">=10GB")
    local required_gb
    if echo "$storage_req" | grep -qE '^[0-9]+.*GB?'; then
        required_gb=$(echo "$storage_req" | sed -n 's/^\([0-9]*\).*/\1/p')
    elif echo "$storage_req" | grep -qE '^>=.*GB?'; then
        required_gb=$(echo "$storage_req" | sed -n 's/^>=\([0-9]*\).*/\1/p')
    else
        warning "Unable to parse storage requirement: $storage_req"
        return 0
    fi
    
    if [ "$storage_gb" -lt "$required_gb" ]; then
        HOST_REQUIREMENTS_ERRORS+=("Insufficient storage: found ${storage_gb}GB, required ${required_gb}GB")
        return 1
    else
        info "Storage requirements met: ${storage_gb}GB available, ${required_gb}GB required"
        return 0
    fi
}

# Check GPU requirements
check_gpu_requirements() {
    local gpu_req="$1"

    if [ -z "$gpu_req" ]; then
        return 0
    fi

    info "Checking GPU requirements: $gpu_req"

    # Check for GPU presence and details
    local gpu_present=false
    local gpu_info=""

    # Check NVIDIA GPUs
    if command -v nvidia-smi >/dev/null 2>&1; then
        if nvidia-smi --list-gpus >/dev/null 2>&1; then
            gpu_present=true
            gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
            if [ -n "$gpu_info" ]; then
                info "NVIDIA GPU detected: $gpu_info"
            fi
        fi
    fi

    # Check AMD GPUs
    if command -v rocm-smi >/dev/null 2>&1; then
        if rocm-smi --showid >/dev/null 2>&1; then
            gpu_present=true
            gpu_info=$(rocm-smi --showproductname 2>/dev/null | head -1)
            if [ -n "$gpu_info" ]; then
                info "AMD GPU detected: $gpu_info"
            fi
        fi
    fi

    # Check Intel GPUs
    if command -v intel-gpu-top >/dev/null 2>&1; then
        gpu_present=true
        info "Intel GPU detected"
    fi

    # Fallback check for any GPU
    if [ "$gpu_present" = false ] && command -v lspci >/dev/null 2>&1; then
        if lspci | grep -i "vga\|3d\|display" | grep -v "virtual\|vmware\|qemu\|cirrus" >/dev/null 2>&1; then
            gpu_present=true
            gpu_info=$(lspci | grep -i "vga\|3d\|display" | head -1 | cut -d: -f3-)
            info "GPU detected via PCI: $gpu_info"
        fi
    fi

    # Parse GPU requirement
    case "$gpu_req" in
        "true"|"required"|"yes")
            if [ "$gpu_present" = true ]; then
                success "GPU requirement met"
                return 0
            else
                HOST_REQUIREMENTS_ERRORS+=("GPU required but no GPU detected")
                return 1
            fi
            ;;
        "false"|"none"|"no")
            if [ "$gpu_present" = false ]; then
                success "No GPU requirement - none detected"
                return 0
            else
                HOST_REQUIREMENTS_WARNINGS+=("GPU detected but not required by configuration")
                return 0
            fi
            ;;
        "optional"|"prefer")
            if [ "$gpu_present" = true ]; then
                success "GPU available (optional requirement met)"
                return 0
            else
                HOST_REQUIREMENTS_WARNINGS+=("GPU optional but not detected - may reduce performance")
                return 0
            fi
            ;;
        *)
            # Parse specific GPU requirements (e.g., "nvidia", ">=2GB", etc.)
            if [[ "$gpu_req" =~ ^nvidia ]]; then
                if command -v nvidia-smi >/dev/null 2>&1; then
                    success "NVIDIA GPU requirement met"
                    return 0
                else
                    HOST_REQUIREMENTS_ERRORS+=("NVIDIA GPU required but not found")
                    return 1
                fi
            elif [[ "$gpu_req" =~ ^amd ]]; then
                if command -v rocm-smi >/dev/null 2>&1; then
                    success "AMD GPU requirement met"
                    return 0
                else
                    HOST_REQUIREMENTS_ERRORS+=("AMD GPU required but not found")
                    return 1
                fi
            else
                HOST_REQUIREMENTS_WARNINGS+=("Unknown GPU requirement format: '$gpu_req' - basic validation performed")
                return 0
            fi
            ;;
    esac
}

# Validate host requirements
validate_host_requirements() {
    if ! has_host_requirements; then
        info "No hostRequirements configuration found"
        return 0
    fi
    
    info "Validating host requirements..."
    
    # Reset validation state
    HOST_REQUIREMENTS_CHECKED=true
    HOST_REQUIREMENTS_ERRORS=()
    HOST_REQUIREMENTS_WARNINGS=()
    
    # Parse requirements
    local requirements
    requirements=$(parse_host_requirements)
    if [ $? -ne 0 ]; then
        error "Failed to parse host requirements"
        return 1
    fi
    
    # Split requirements
    IFS='|' read -r cpu_req gpu_req storage_req memory_req <<< "$requirements"
    
    local validation_failed=false
    
    # Check each requirement
    if ! check_cpu_requirements "$cpu_req"; then
        validation_failed=true
    fi
    
    if ! check_memory_requirements "$memory_req"; then
        validation_failed=true
    fi
    
    if ! check_storage_requirements "$storage_req"; then
        validation_failed=true
    fi
    
    check_gpu_requirements "$gpu_req"
    
    # Report results
    if [ "$validation_failed" = true ]; then
        error "Host requirements validation failed:"
        for error_msg in "${HOST_REQUIREMENTS_ERRORS[@]}"; do
            echo "  - $error_msg"
        done
        return 1
    else
        success "Host requirements validation passed"
        
        if [ ${#HOST_REQUIREMENTS_WARNINGS[@]} -gt 0 ]; then
            echo "Warnings:"
            for warning_msg in "${HOST_REQUIREMENTS_WARNINGS[@]}"; do
                echo "  - $warning_msg"
            done
        fi
        
        return 0
    fi
}

# Show host requirements status
show_host_requirements_status() {
    if ! has_host_requirements; then
        echo "No hostRequirements configuration found."
        return 0
    fi
    
    echo "Host Requirements Status:"
    echo "========================="
    
    if [ "$HOST_REQUIREMENTS_CHECKED" = false ]; then
        echo "Requirements not yet validated. Run 'dcutil hostrequirements validate' to check."
        return 0
    fi
    
    # Parse and show requirements
    local requirements
    requirements=$(parse_host_requirements)
    IFS='|' read -r cpu_req gpu_req storage_req memory_req <<< "$requirements"
    
    echo "Configured Requirements:"
    [ -n "$cpu_req" ] && echo "  CPU: $cpu_req"
    [ -n "$memory_req" ] && echo "  Memory: $memory_req"
    [ -n "$storage_req" ] && echo "  Storage: $storage_req"
    [ -n "$gpu_req" ] && echo "  GPU: $gpu_req"
    
    if [ ${#HOST_REQUIREMENTS_ERRORS[@]} -gt 0 ]; then
        echo ""
        echo "Validation Errors:"
        for error_msg in "${HOST_REQUIREMENTS_ERRORS[@]}"; do
            echo "  - $error_msg"
        done
    fi
    
    if [ ${#HOST_REQUIREMENTS_WARNINGS[@]} -gt 0 ]; then
        echo ""
        echo "Warnings:"
        for warning_msg in "${HOST_REQUIREMENTS_WARNINGS[@]}"; do
            echo "  - $warning_msg"
        done
    fi
    
    if [ ${#HOST_REQUIREMENTS_ERRORS[@]} -eq 0 ] && [ ${#HOST_REQUIREMENTS_WARNINGS[@]} -eq 0 ]; then
        echo ""
        echo "✅ All requirements met"
    fi
}

# Cleanup host requirements state
cleanup_host_requirements() {
    HOST_REQUIREMENTS_CHECKED=false
    HOST_REQUIREMENTS_ERRORS=()
    HOST_REQUIREMENTS_WARNINGS=()
    info "Host requirements state cleaned up"
}