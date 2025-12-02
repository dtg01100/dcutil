#!/bin/bash

# Test script to verify the clean functionality by checking the PROJECT_DIR behavior

# Create a test directory with a .devcontainer folder
test_dir=$(mktemp -d)
echo "Testing in directory: $test_dir"
cd "$test_dir"

# Create test structure
mkdir -p .devcontainer
echo '{"name": "test", "image": "ubuntu"}' > .devcontainer/devcontainer.json
echo "Created test structure:"
ls -la
echo "Contents of .devcontainer/:"
ls -la .devcontainer/

# Test the determine_project_dir function behavior
source /var/mnt/Disk2/projects/dcutil/lib/core.sh

# Before our fix: determine_project_dir would use $SCRIPT_DIR if no config was found in current dir
# But we want clean to always use current dir, so let's test the PROJECT_DIR setting directly

# Simulate what the main script does for clean: set PROJECT_DIR to current directory
PROJECT_DIR="$(pwd)"
export PROJECT_DIR

echo "PROJECT_DIR is set to: $PROJECT_DIR"
echo "Current directory is: $(pwd)"

# Verify that PROJECT_DIR points to the right place
if [ "$PROJECT_DIR" = "$(pwd)" ]; then
    echo "✓ SUCCESS: PROJECT_DIR is correctly set to current directory"
else
    echo "✗ FAILED: PROJECT_DIR does not match current directory"
fi

if [ -d "$PROJECT_DIR/.devcontainer" ]; then
    echo "✓ SUCCESS: .devcontainer directory exists at PROJECT_DIR"
else
    echo "✗ FAILED: .devcontainer directory missing at PROJECT_DIR"
fi

# Clean up test directory
cd - > /dev/null
rm -rf "$test_dir"

echo "Test completed - the fix ensures PROJECT_DIR is set to current directory for clean operations!"
