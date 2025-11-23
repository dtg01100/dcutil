#!/usr/bin/env bash

# Enhanced build configuration support for dcutil
# Handles advanced Dockerfile build options per devcontainer specification

# Source core functionality
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Global variables for build configuration
BUILD_CONTEXT=""
BUILD_DOCKERFILE=""
BUILD_ARGS=()
BUILD_TARGET=""
BUILD_CACHE_FROM=()
BUILD_NO_CACHE=false
BUILD_SQUASH=false

# Check if build configuration is specified
is_custom_build() {
    if command -v jq &> /dev/null; then
        if jq -e '.build' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Parse build configuration from devcontainer.json
parse_build_config() {
    if ! is_custom_build; then
        return 1
    fi
    
    info "Parsing build configuration..."
    
    if command -v jq &> /dev/null; then
        # Parse build.context first
        BUILD_CONTEXT=$(jq -r '.build.context // "."' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        if [ -n "$BUILD_CONTEXT" ] && [ "$BUILD_CONTEXT" != "null" ]; then
            # Expand variables in context path
            BUILD_CONTEXT=$(echo "$BUILD_CONTEXT" | sed "s|\${workspaceFolder}|$PROJECT_DIR|g" | sed "s|\${localWorkspaceFolder}|$PROJECT_DIR|g")
            info "Using build context: $BUILD_CONTEXT"
        fi

        # Parse build.dockerfile
        BUILD_DOCKERFILE=$(jq -r '.build.dockerfile // "Dockerfile"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        if [ -n "$BUILD_DOCKERFILE" ] && [ "$BUILD_DOCKERFILE" != "null" ]; then
            # Expand variables in dockerfile path
            BUILD_DOCKERFILE=$(echo "$BUILD_DOCKERFILE" | sed "s|\${workspaceFolder}|$PROJECT_DIR|g" | sed "s|\${localWorkspaceFolder}|$PROJECT_DIR|g")

            # If dockerfile path is relative and devcontainer.json is in a subdirectory,
            # make it relative to the build context
            if [[ "$BUILD_DOCKERFILE" != /* ]]; then
                local devcontainer_dir
                devcontainer_dir=$(dirname "$DEVCONTAINER_CONFIG_FILE")
                local context_dir
                if [[ "$BUILD_CONTEXT" == "." ]]; then
                    context_dir="$PROJECT_DIR"
                else
                    context_dir=$(realpath -m "$BUILD_CONTEXT" 2>/dev/null || echo "$BUILD_CONTEXT")
                fi
                devcontainer_dir=$(realpath -m "$devcontainer_dir" 2>/dev/null || echo "$devcontainer_dir")

                if [ "$devcontainer_dir" != "$context_dir" ]; then
                    # Calculate relative path from context to devcontainer directory
                    local rel_path
                    rel_path=$(realpath -m --relative-to="$context_dir" "$devcontainer_dir" 2>/dev/null || echo "")
                    if [ -n "$rel_path" ] && [ "$rel_path" != "." ]; then
                        BUILD_DOCKERFILE="$rel_path/$BUILD_DOCKERFILE"
                    fi
                fi
            fi

            info "Using Dockerfile: $BUILD_DOCKERFILE"
        fi
        
        # Parse build.target
        BUILD_TARGET=$(jq -r '.build.target // empty' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        if [ -n "$BUILD_TARGET" ] && [ "$BUILD_TARGET" != "null" ]; then
            info "Using build target: $BUILD_TARGET"
        fi
        
        # Parse build.args
        if jq -e '.build.args' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS= read -r arg; do
                if [ -n "$arg" ] && [ "$arg" != "null" ]; then
                    # Expand variables in build args
                    local expanded_arg
                    expanded_arg=$(echo "$arg" | sed "s|\${workspaceFolder}|$PROJECT_DIR|g" | sed "s|\${localWorkspaceFolder}|$PROJECT_DIR|g")
                    BUILD_ARGS+=("$expanded_arg")
                fi
            done < <(jq -r '.build.args | to_entries[] | "\(.key)=\(.value|tostring)"' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
            
            if [ ${#BUILD_ARGS[@]} -gt 0 ]; then
                info "Using build args: ${BUILD_ARGS[*]}"
            fi
        fi
        
        # Parse build.cacheFrom
        if jq -e '.build.cacheFrom' "$DEVCONTAINER_CONFIG_FILE" >/dev/null 2>&1; then
            while IFS= read -r cache_image; do
                if [ -n "$cache_image" ] && [ "$cache_image" != "null" ]; then
                    BUILD_CACHE_FROM+=("$cache_image")
                fi
            done < <(jq -r '.build.cacheFrom[]' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null || echo "")
            
            if [ ${#BUILD_CACHE_FROM[@]} -gt 0 ]; then
                info "Using cache from: ${BUILD_CACHE_FROM[*]}"
            fi
        fi
        
        # Parse build.noCache
        BUILD_NO_CACHE=$(jq -r '.build.noCache // false' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        if [ "$BUILD_NO_CACHE" = "true" ]; then
            info "Build cache disabled"
        fi
        
        # Parse build.squash (if supported)
        BUILD_SQUASH=$(jq -r '.build.squash // false' "$DEVCONTAINER_CONFIG_FILE" 2>/dev/null)
        if [ "$BUILD_SQUASH" = "true" ]; then
            info "Build squash enabled"
        fi
        
        return 0
    fi
    
    return 1
}

# Build Docker image with enhanced options
docker_build_enhanced() {
    if ! is_custom_build; then
        error_exit "No build configuration found. Use 'dcutil build' for standard builds." "$EXIT_CONFIG_ERROR"
    fi

    info "Building Docker image with enhanced configuration..."
    check_docker_daemon
    
    # Validate build files exist
    if [ -n "$BUILD_DOCKERFILE" ] && [ "$BUILD_DOCKERFILE" != "Dockerfile" ]; then
        if [ ! -f "$BUILD_DOCKERFILE" ]; then
            error_exit "Dockerfile not found: $BUILD_DOCKERFILE" "$EXIT_CONFIG_ERROR"
        fi
    fi
    
    if [ ! -d "$BUILD_CONTEXT" ]; then
        error_exit "Build context directory not found: $BUILD_CONTEXT" "$EXIT_CONFIG_ERROR"
    fi
    
    # Build docker build command
    local build_cmd="docker build"
    
    # Add build args
    for arg in "${BUILD_ARGS[@]}"; do
        build_cmd="$build_cmd --build-arg $arg"
    done
    
    # Add cache-from
    for cache_image in "${BUILD_CACHE_FROM[@]}"; do
        build_cmd="$build_cmd --cache-from $cache_image"
    done
    
    # Add target
    if [ -n "$BUILD_TARGET" ]; then
        build_cmd="$build_cmd --target $BUILD_TARGET"
    fi
    
    # Add no-cache option
    if [ "$BUILD_NO_CACHE" = "true" ]; then
        build_cmd="$build_cmd --no-cache"
    fi
    
    # Add squash option (if supported)
    if [ "$BUILD_SQUASH" = "true" ]; then
        build_cmd="$build_cmd --squash"
    fi
    
    # Add dockerfile path
    if [ -n "$BUILD_DOCKERFILE" ] && [ "$BUILD_DOCKERFILE" != "Dockerfile" ]; then
        build_cmd="$build_cmd -f $BUILD_DOCKERFILE"
    fi
    
    # Add image name
    if [ -n "${IMAGE_NAME:-}" ]; then
        build_cmd="$build_cmd -t $IMAGE_NAME"
    fi

    # Add context
    build_cmd="$build_cmd $BUILD_CONTEXT"
    
    info "Executing: $build_cmd"
    
    # Execute build command
    if eval $build_cmd; then
        success "Docker image built successfully: $IMAGE_NAME"
    else
        error_exit "Failed to build Docker image" "$EXIT_DEVCONTAINER_ERROR"
    fi
}

# Show build configuration info
show_build_info() {
    # Parse devcontainer config first to set DEVCONTAINER_CONFIG_FILE
    if command -v parse_devcontainer_config >/dev/null 2>&1; then
        parse_devcontainer_config
    else
        error_exit "Failed to parse devcontainer configuration" "$EXIT_CONFIG_ERROR"
    fi
    
    if [ -z "${DEVCONTAINER_CONFIG_FILE:-}" ]; then
        error_exit "No devcontainer configuration file found. Run from a project directory with .devcontainer/devcontainer.json" "$EXIT_CONFIG_ERROR"
    fi
    
    if ! is_custom_build; then
        echo "No custom build configuration found."
        return 1
    fi
    
    # Parse build config first
    parse_build_config
    
    echo "Build Configuration:"
    echo "  Dockerfile: ${BUILD_DOCKERFILE:-Dockerfile}"
    echo "  Context: ${BUILD_CONTEXT:-.}"
    if [ -n "$BUILD_TARGET" ]; then
        echo "  Target: $BUILD_TARGET"
    fi
    if [ ${#BUILD_ARGS[@]} -gt 0 ]; then
        echo "  Build Args:"
        for arg in "${BUILD_ARGS[@]}"; do
            echo "    $arg"
        done
    fi
    if [ ${#BUILD_CACHE_FROM[@]} -gt 0 ]; then
        echo "  Cache From:"
        for cache in "${BUILD_CACHE_FROM[@]}"; do
            echo "    $cache"
        done
    fi
    echo "  No Cache: ${BUILD_NO_CACHE}"
    echo "  Squash: ${BUILD_SQUASH}"
}

# Validate build configuration
validate_build_config() {
    if ! is_custom_build; then
        return 0
    fi
    
    local errors=()
    
    # Check if dockerfile exists
    if [ -n "$BUILD_DOCKERFILE" ] && [ "$BUILD_DOCKERFILE" != "Dockerfile" ]; then
        if [ ! -f "$BUILD_DOCKERFILE" ]; then
            errors+=("Dockerfile not found: $BUILD_DOCKERFILE")
        fi
    fi
    
    # Check if context exists
    if [ ! -d "$BUILD_CONTEXT" ]; then
        errors+=("Build context directory not found: $BUILD_CONTEXT")
    fi
    
    # Check if docker build supports squash
    if [ "$BUILD_SQUASH" = "true" ]; then
        if ! docker build --help | grep -q -- "--squash"; then
            errors+=("Docker build squash is not supported by this Docker version")
        fi
    fi
    
    if [ ${#errors[@]} -gt 0 ]; then
        echo "Build configuration validation errors:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
    
    return 0
}

# Clean build artifacts
clean_build_artifacts() {
    info "Cleaning build artifacts..."
    
    # Remove intermediate images if any
    docker image prune -f
    
    # Remove dangling images
    docker image prune -f --filter "dangling=true"
    
    success "Build artifacts cleaned"
}