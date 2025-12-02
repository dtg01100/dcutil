#!/usr/bin/env bash

# Test script to validate the resolve_numeric_feature_key functionality

echo "Testing the resolve_numeric_feature_key logic separately..."

# Mock available features JSON
available_features_json='[
  {"id": "git", "name": "Git", "description": "Git support", "registry": "ghcr.io/devcontainers/features"},
  {"id": "docker-in-docker", "name": "Docker-in-Docker", "description": "Docker support", "registry": "ghcr.io/devcontainers/features"},
  {"id": "common-utils", "name": "Common Utilities", "description": "Common utilities", "registry": "ghcr.io/devcontainers/features"}
]'

# Test function that emulates resolve_numeric_feature_key behavior
resolve_numeric_feature_key() {
    local key="${1:-}"
    if [[ -z "$key" ]]; then
        echo ""
        return 1
    fi

    # Only proceed if we have the downloaded features list available
    if [ "$available_features_json" = "[]" ] || [ -z "$available_features_json" ]; then
        # If no available features list, return the key as-is
        echo "$key"
        return 0
    fi

    # If key is purely numeric
    if [[ "$key" =~ ^[0-9]+$ ]]; then
        local idx=$((key - 1))
        local mapped_id
        mapped_id=$(echo "$available_features_json" | jq -r ".[$idx].id // empty" 2>/dev/null | head -n 1)
        local mapped_registry
        mapped_registry=$(echo "$available_features_json" | jq -r ".[$idx].registry // empty" 2>/dev/null | head -n 1)

        if [ -n "$mapped_id" ] && [ "$mapped_id" != "null" ]; then
            if [[ "$mapped_id" == ghcr.io/* ]]; then
                echo "$mapped_id"
                return 0
            elif [ -n "$mapped_registry" ]; then
                echo "$mapped_registry/$mapped_id"
                return 0
            else
                echo "ghcr.io/devcontainers/features/$mapped_id"
                return 0
            fi
        fi
    fi

    # If key contains container registry and numeric like ghcr.io/devcontainers/features/2
    if [[ "$key" =~ ^ghcr.io/devcontainers/features/[0-9]+(:.*)?$ ]]; then
        # Extract the numeric part
        local id_match
        if [[ "$key" =~ : ]]; then
            # Has version suffix, extract just the numeric before the colon
            id_match=$(echo "$key" | sed -n 's/^ghcr.io\/devcontainers\/features\/\([0-9]\+\):.*$/\1/p')
        else
            # No version suffix
            id_match=$(echo "$key" | sed -n 's/^ghcr.io\/devcontainers\/features\/\([0-9]\+\)$/\1/p')
        fi

        if [[ "$id_match" =~ ^[0-9]+$ ]]; then
            local idx=$((id_match - 1))
            local mapped_id
            mapped_id=$(echo "$available_features_json" | jq -r ".[$idx].id // empty" 2>/dev/null | head -n 1)
            local mapped_registry
            mapped_registry=$(echo "$available_features_json" | jq -r ".[$idx].registry // empty" 2>/dev/null | head -n 1)

            if [ -n "$mapped_id" ] && [ "$mapped_id" != "null" ]; then
                local result
                if [[ "$mapped_id" == ghcr.io/* ]]; then
                    result="$mapped_id"
                elif [ -n "$mapped_registry" ]; then
                    result="$mapped_registry/$mapped_id"
                else
                    result="ghcr.io/devcontainers/features/$mapped_id"
                fi

                # If the original key had a version, preserve it
                if [[ "$key" =~ : ]]; then
                    local version_suffix
                    version_suffix=$(echo "$key" | sed -n 's/.*:\(.*\)$/\1/p')
                    result="$result:$version_suffix"
                fi

                echo "$result"
                return 0
            fi
        fi
    fi

    # If we couldn't resolve it, return the original key
    echo "$key"
    return 0
}

# Test cases
echo "Testing resolve_numeric_feature_key function:"
echo ""

test_case() {
    local input="$1"
    local expected="$2"
    local result
    result=$(resolve_numeric_feature_key "$input")
    if [ "$result" = "$expected" ]; then
        echo "✓ PASS: resolve_numeric_feature_key('$input') = '$result'"
    else
        echo "✗ FAIL: resolve_numeric_feature_key('$input') = '$result', expected '$expected'"
    fi
}

# Test numeric keys (should map to features in our JSON array)
test_case "1" "ghcr.io/devcontainers/features/git"
test_case "2" "ghcr.io/devcontainers/features/docker-in-docker"
test_case "3" "ghcr.io/devcontainers/features/common-utils"

# Test registry+numeric format
test_case "ghcr.io/devcontainers/features/1" "ghcr.io/devcontainers/features/git"
test_case "ghcr.io/devcontainers/features/2:latest" "ghcr.io/devcontainers/features/docker-in-docker:latest"

# Test non-numeric keys (should return as-is)
test_case "git" "git"
test_case "ghcr.io/devcontainers/features/git" "ghcr.io/devcontainers/features/git"

# Test out-of-range numeric (should return as-is)
test_case "5" "5"

echo ""
echo "Testing feature_exists_in_downloaded_list function (from features.sh)..."
# This function will be tested by importing it from our updated file

# Source our fixed functions from features.sh
source /var/mnt/Disk2/projects/dcutil/lib/features.sh

# Test with a simple JSON
test_json='[{"id": "ghcr.io/devcontainers/features/git"}, {"id": "ghcr.io/devcontainers/features/docker-in-docker"}]'

if feature_exists_in_downloaded_list "git" "$test_json"; then
    echo "✓ PASS: feature_exists_in_downloaded_list found 'git'"
else
    echo "✗ FAIL: feature_exists_in_downloaded_list did not find 'git'"
fi

if feature_exists_in_downloaded_list "nonexistent" "$test_json"; then
    echo "✗ FAIL: feature_exists_in_downloaded_list incorrectly found 'nonexistent'"
else
    echo "✓ PASS: feature_exists_in_downloaded_list correctly did not find 'nonexistent'"
fi

echo ""
echo "All tests completed."
