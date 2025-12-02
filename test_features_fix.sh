#!/usr/bin/env bash

# Test script to validate the features fix for using downloaded list as source of truth

# Source the features library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/features.sh"

# Mock fetch_available_features_official function for testing
fetch_available_features_official() {
    cat << 'EOF'
[
  {"id": "git", "name": "Git", "description": "Git support", "registry": "ghcr.io/devcontainers/features"},
  {"id": "docker-in-docker", "name": "Docker-in-Docker", "description": "Docker support", "registry": "ghcr.io/devcontainers/features"},
  {"id": "common-utils", "name": "Common Utilities", "description": "Common utilities", "registry": "ghcr.io/devcontainers/features"}
]
EOF
}

# Test the resolve_numeric_feature_key function (which is defined inside parse_features_config)
# We'll test the functionality by calling parse_features_config with a mock config

echo "Testing features functionality with downloaded list as source of truth..."

# Create a temporary directory for testing
test_dir=$(mktemp -d)
echo "Created test directory: $test_dir"

# Create a mock devcontainer.json with numeric feature keys
mkdir -p "$test_dir/.devcontainer"
cat > "$test_dir/.devcontainer/devcontainer.json" << 'EOF'
{
  "name": "Test Container",
  "image": "ubuntu:latest",
  "features": {
    "1": {},
    "git": {}
  }
}
EOF

echo "Created test devcontainer.json with numeric feature key '1' and named feature 'git'"

# Save current directory
original_dir=$(pwd)

# Change to test directory
cd "$test_dir"
export PROJECT_DIR="$test_dir"

# Test parsing features configuration
echo "Testing parse_features_config..."
if parse_features_config; then
    echo "✓ parse_features_config succeeded"
    echo "Found ${#FEATURES_IDS[@]} feature(s):"
    for feature_id in "${FEATURES_IDS[@]}"; do
        echo "  - $feature_id"
    done
else
    echo "✗ parse_features_config failed"
fi

# Test the feature_exists_in_downloaded_list function
echo "Testing feature_exists_in_downloaded_list function..."
if feature_exists_in_downloaded_list "git" '[{"id": "ghcr.io/devcontainers/features/git"}]'; then
    echo "✓ feature_exists_in_downloaded_list correctly identified 'git' feature"
else
    echo "✗ feature_exists_in_downloaded_list failed to identify 'git' feature"
fi

if feature_exists_in_downloaded_list "nonexistent" '[{"id": "ghcr.io/devcontainers/features/git"}]'; then
    echo "✗ feature_exists_in_downloaded_list incorrectly identified 'nonexistent' feature"
else
    echo "✓ feature_exists_in_downloaded_list correctly rejected 'nonexistent' feature"
fi

# Return to original directory
cd "$original_dir"

# Clean up
rm -rf "$test_dir"

echo "Test completed."
