#!/bin/bash

# Test script to verify the new dcutil init clean functionality

# Create a temporary directory for testing
test_dir=$(mktemp -d)
echo "Testing in directory: $test_dir"
cd "$test_dir"

# Create mock devcontainer configuration
mkdir -p .devcontainer
echo '{"name": "test", "image": "ubuntu"}' > .devcontainer/devcontainer.json

echo "Created test devcontainer configuration:"
ls -la .devcontainer/

# Source the required files to test the function directly
source /var/mnt/Disk2/projects/dcutil/lib/core.sh
source /var/mnt/Disk2/projects/dcutil/lib/docker.sh

# Simulate the clean function by defining a minimal version
devcontainer_clean() {
    echo "Simulating devcontainer_clean function..."
    if [ -d ".devcontainer" ]; then
        rm -rf ".devcontainer"
        echo "Removed .devcontainer directory"
    fi
    if [ -f "devcontainer.json" ]; then
        rm -f "devcontainer.json"
        echo "Removed devcontainer.json file"
    fi
    if [ -f ".devcontainer.json" ]; then
        rm -f ".devcontainer.json"
        echo "Removed .devcontainer.json file"
    fi
    echo "Configuration cleaned up"
}

# Source the init functionality
source /var/mnt/Disk2/projects/dcutil/lib/init.sh

echo ""
echo "Testing init_mode function with 'clean' argument..."

# Test that validation allows the clean option
validate_init_mode "clean"
if [ $? -eq 0 ]; then
    echo "✓ Validation passed for 'clean' option"
else
    echo "✗ Validation failed for 'clean' option"
fi

validate_init_mode "--clean"
if [ $? -eq 0 ]; then
    echo "✓ Validation passed for '--clean' option"
else
    echo "✗ Validation failed for '--clean' option"
fi

# Temporarily override the PROJECT_DIR
original_project_dir="${PROJECT_DIR:-}"
export PROJECT_DIR="$test_dir"

# Run the clean mode
init_mode "clean"

# Check if the configuration was removed
if [ ! -d ".devcontainer" ]; then
    echo "✓ .devcontainer directory was removed"
else
    echo "✗ .devcontainer directory still exists"
fi

# Restore original PROJECT_DIR
if [ -n "$original_project_dir" ]; then
    export PROJECT_DIR="$original_project_dir"
else
    unset PROJECT_DIR
fi

# Clean up
cd - > /dev/null
rm -rf "$test_dir"

echo "Test completed!"
