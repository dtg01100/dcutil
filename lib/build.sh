#!/bin/bash

# Custom Dockerfile builds support for dcutil
# Implements the build object from devcontainers specification

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for build configuration
BUILD_DOCKERFILE=""
BUILD_CONTEXT=""
BUILD_ARGS=()
BUILD_TARGET=""
BUILD_CACHE_FROM=()

# Parse build configuration from devcontainer.json
parse_build_config() {
    local config_file=""

    # Find devcontainer configuration
    if [ -f ".devcontainer/devcontainer.json" ]; then
        config_file=".devcontainer/devcontainer.json"
    elif [ -f ".devcontainer.json" ]; then
        config_file=".devcontainer.json"
    else
        return 0  # No devcontainer config
    fi

    # Initialize build variables
    BUILD_ARGS=()
    BUILD_CACHE_FROM=()

    # Check if build object is specified
    if command -v jq >/dev/null 2>&1 && jq -e '.build' "$config_file" >/dev/null 2>&1; then
        info "Custom build configuration found"

        # Parse build.dockerfile
        BUILD_DOCKERFILE=$(jq -r '.build.dockerfile // "Dockerfile"' "$config_file")

        # Parse build.context
        BUILD_CONTEXT=$(jq -r '.build.context // "."' "$config_file")

        # Parse build.args
        if jq -e '.build.args' "$config_file" >/dev/null 2>&1; then
            while IFS='=' read -r key value; do
                if [ -n "$key" ] && [ -n "$value" ]; then
                    local arg="--build-arg ${key}=${value}"
                    local duplicate=false
                    for existing in "${BUILD_ARGS[@]}"; do
                        if [ "$existing" = "$arg" ]; then
                            duplicate=true
                            break
                        fi
                    done
                    if [ "$duplicate" = false ]; then
                        BUILD_ARGS+=("$arg")
                    fi
                fi
            done < <(jq -r '.build.args | to_entries[] | "\(.key)=\(.value)"' "$config_file" 2>/dev/null || echo "")
        fi

        # Parse build.target
        BUILD_TARGET=$(jq -r '.build.target // ""' "$config_file")
        if [ -n "$BUILD_TARGET" ]; then
            local target_arg="--target $BUILD_TARGET"
            local duplicate=false
            for existing in "${BUILD_ARGS[@]}"; do
                if [ "$existing" = "$target_arg" ]; then
                    duplicate=true
                    break
                fi
            done
            if [ "$duplicate" = false ]; then
                BUILD_ARGS+=("$target_arg")
            fi
        fi

        # Parse build.cacheFrom
        if jq -e '.build.cacheFrom' "$config_file" >/dev/null 2>&1; then
            while IFS= read -r cache_image; do
                if [ -n "$cache_image" ] && [ "$cache_image" != "null" ]; then
                    local cache_arg="--cache-from $cache_image"
                    local duplicate=false
                    for existing in "${BUILD_CACHE_FROM[@]}"; do
                        if [ "$existing" = "$cache_arg" ]; then
                            duplicate=true
                            break
                        fi
                    done
                    if [ "$duplicate" = false ]; then
                        BUILD_CACHE_FROM+=("$cache_arg")
                    fi
                fi
            done < <(jq -r '.build.cacheFrom[]' "$config_file" 2>/dev/null || echo "")
        fi
        
        info "Build configuration:"
        info "  Dockerfile: $BUILD_DOCKERFILE"
        info "  Context: $BUILD_CONTEXT"
        info "  Target: ${BUILD_TARGET:-default}"
        info "  Args: ${#BUILD_ARGS[@]} build arguments"
        info "  Cache sources: ${#BUILD_CACHE_FROM[@]} cache images"
        info "  BUILD_ARGS: ${BUILD_ARGS[*]}"
        
        # Validate build files exist
        if [ ! -f "$BUILD_DOCKERFILE" ]; then
            error_exit "Dockerfile not found: $BUILD_DOCKERFILE" "$EXIT_CONFIG_ERROR"
        fi
        
        if [ ! -d "$BUILD_CONTEXT" ]; then
            error_exit "Build context not found: $BUILD_CONTEXT" "$EXIT_CONFIG_ERROR"
        fi
        
        return 0
    fi
    
    return 0  # No build configuration
}

# Check if custom build is configured
is_custom_build() {
    [ -n "$BUILD_DOCKERFILE" ]
}

# Build custom container image
build_custom_image() {
    local image_name="$1"
    
    if ! is_custom_build; then
        return 0  # No custom build needed
    fi
    
    info "Building custom container image: $image_name"
    check_docker_daemon
    
    # Change to build context
    local original_dir
    original_dir="$(pwd)"
    cd "$BUILD_CONTEXT" || error_exit "Failed to change to build context: $BUILD_CONTEXT" "$EXIT_PERMISSION_ERROR"
    
    # Build the image
    local build_cmd=("docker" "build")

    # Add cache arguments first
    for cache_arg in "${BUILD_CACHE_FROM[@]}"; do
        build_cmd+=("$cache_arg")
    done
    
    # Add build arguments
    for build_arg in "${BUILD_ARGS[@]}"; do
        build_cmd+=("$build_arg")
    done
    
    # Add tags and context
    build_cmd+=("-t" "$image_name" "-f" "$BUILD_DOCKERFILE" ".")
    
    info "Running: ${build_cmd[*]}"
    if ! "${build_cmd[@]}" 2>/dev/null; then
        cd "$original_dir"
        error_exit "Failed to build custom image: $image_name" "$EXIT_DEVCONTAINER_ERROR"
    fi
    
    cd "$original_dir"
    success "Custom image built successfully: $image_name"
}

# Get build information for display
get_build_info() {
    if ! is_custom_build; then
        echo "No custom build configuration"
        return 0
    fi
    
    echo "Custom Build Configuration:"
    echo "  Dockerfile: $BUILD_DOCKERFILE"
    echo "  Context: $BUILD_CONTEXT"
    echo "  Target: ${BUILD_TARGET:-default}"
    echo "  Build Args: ${#BUILD_ARGS[@]} arguments"
    echo "  Cache Sources: ${#BUILD_CACHE_FROM[@]} images"
    
    if [ ${#BUILD_ARGS[@]} -gt 0 ]; then
        echo "  Build Arguments:"
        for ((i=0; i<${#BUILD_ARGS[@]}; i+=2)); do
            if [ "${BUILD_ARGS[$i]}" = "--build-arg" ]; then
                echo "    ${BUILD_ARGS[$i+1]}"
            fi
        done
    fi
    
    if [ ${#BUILD_CACHE_FROM[@]} -gt 0 ]; then
        echo "  Cache From:"
        for ((i=0; i<${#BUILD_CACHE_FROM[@]}; i+=2)); do
            if [ "${BUILD_CACHE_FROM[$i]}" = "--cache-from" ]; then
                echo "    ${BUILD_CACHE_FROM[$i+1]}"
            fi
        done
    fi
}

# Validate build configuration
validate_build_config() {
    if ! is_custom_build; then
        return 0  # No build config to validate
    fi
    
    local errors=()
    
    # Check Dockerfile exists
    if [ ! -f "$BUILD_DOCKERFILE" ]; then
        errors+=("Dockerfile not found: $BUILD_DOCKERFILE")
    fi
    
    # Check context exists
    if [ ! -d "$BUILD_CONTEXT" ]; then
        errors+=("Build context not found: $BUILD_CONTEXT")
    fi
    
    # Check for basic Dockerfile syntax
    if [ -f "$BUILD_DOCKERFILE" ]; then
        if ! head -1 "$BUILD_DOCKERFILE" | grep -q "^FROM "; then
            errors+=("Dockerfile does not start with FROM instruction")
        fi
    fi
    
    # Report errors
    if [ ${#errors[@]} -gt 0 ]; then
        echo "Build configuration validation failed:"
        for err in "${errors[@]}"; do
            echo "  - $err"
        done
        return 1
    fi
    
    success "Build configuration validation passed"
    return 0
}

# Clean build artifacts
clean_build_artifacts() {
    if ! is_custom_build; then
        return 0
    fi
    
    info "Cleaning build artifacts..."
    
    # Remove dangling build cache
    if docker builder prune -f >/dev/null 2>&1; then
        info "Build cache cleaned"
    fi
    
    # Note: We don't remove the built image here as it might be in use
    # Users can manually remove with: docker rmi <image_name>
    
    success "Build artifacts cleaned"
}

# Build command interface
dcutil_build() {
    local subcommand="$1"
    shift
    
    case "$subcommand" in
        "info")
            parse_build_config
            get_build_info
            ;;
        "validate")
            parse_build_config
            if validate_build_config; then
                success "Build configuration is valid"
            else
                error_exit "Build configuration validation failed" "$EXIT_CONFIG_ERROR"
            fi
            ;;
        "clean")
            parse_build_config
            clean_build_artifacts
            ;;
        "help"|"-h"|"--help")
            print_build_usage
            ;;
        *)
            error_exit "Unknown build subcommand: $subcommand" "$EXIT_INVALID_ARGS"
            ;;
    esac
}

# Print build usage
print_build_usage() {
    echo "Usage: dcutil build <subcommand>"
    echo ""
    echo "Build subcommands:"
    echo "  info       Show build configuration information"
    echo "  validate   Validate build configuration"
    echo "  clean      Clean build artifacts and cache"
    echo "  help       Show this help"
    echo ""
    echo "Configuration is read from devcontainer.json build object:"
    echo '  "build": {'
    echo '    "dockerfile": "Dockerfile",'
    echo '    "context": "..",'
    echo '    "args": {'
    echo '      "NODE_VERSION": "18"'
    echo '    },'
    echo '    "target": "development",'
    echo '    "cacheFrom": ["base:latest"]'
    echo '  }'
}