#!/usr/bin/env bash

set -euo pipefail

# Basic unit tests for features management
# Requires jq

# Compute repo root
REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cd "$TEST_DIR"

# Create a fake devcontainer.json
cat > devcontainer.json <<EOF
{
  "features": {}
}
EOF

# Mock template_integration functions before sourcing features.sh
fetch_available_features_official() {
    cat <<'JSON'
[
  {"id":"git","name":"Git","description":"git"},
  {"id":"docker","name":"Docker","description":"docker"},
  {"id":"node","name":"Node","description":"node"}
]
JSON
}

# Set LIB_DIR to a location without template_integration.sh so features.sh doesn't source it
LIB_DIR="$TEST_DIR/lib"
mkdir -p "$LIB_DIR"

# Source the library
. "$REPO_ROOT/lib/features.sh"

# Test: add multiple features at once (space separated)
features_add git docker
if ! jq -e '.features["ghcr.io/devcontainers/features/git"] and .features["ghcr.io/devcontainers/features/docker"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_add should add multiple features"
    exit 1
fi

# Test: add single feature
features_add node
if ! jq -e '.features["ghcr.io/devcontainers/features/node"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_add should add single feature node"
    exit 1
fi

# Test: remove a single feature
features_remove git
if jq -e '.features["ghcr.io/devcontainers/features/git"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_remove should remove git"
    exit 1
fi
if ! jq -e '.features["ghcr.io/devcontainers/features/node"]' devcontainer.json >/dev/null; then
    echo "FAILED: node should remain after removing git"
    exit 1
fi

# Test: remove multiple features at once (comma separated)
features_remove docker,node
if jq -e '.features["ghcr.io/devcontainers/features/docker"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_remove should remove docker"
    exit 1
fi
if jq -e '.features["ghcr.io/devcontainers/features/node"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_remove should remove node"
    exit 1
fi

# Test: add multiple features at once (comma separated)
features_add git,docker,node
if ! jq -e '.features["ghcr.io/devcontainers/features/git"] and .features["ghcr.io/devcontainers/features/docker"] and .features["ghcr.io/devcontainers/features/node"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_add should add multiple features from comma-separated input"
    exit 1
fi

# Test: remove multiple features at once (multiple args)
features_remove git docker
if jq -e '.features["ghcr.io/devcontainers/features/git"]' devcontainer.json >/dev/null || jq -e '.features["ghcr.io/devcontainers/features/docker"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_remove should remove both git and docker"
    exit 1
fi

# Test: wizard fallback (non-fzf)
# Create a fresh devcontainer.json with no features to avoid toggling pre-existing ones
cat > devcontainer.json <<EOF
{
  "features": {}
}
EOF
# Monkeypatch features_parse_available_to_lines to return a known list
features_parse_available_to_lines() {
    echo -e "git	Git	git\ndocker	Docker	docker\nnode	Node	node"
}

# Simulate user input: select 1 and 3 (git and node), apply with 'Enter'
selected=$(printf '1 3\n\n' | features_wizard_nonfzf | grep -E '^(git|docker|node)$' | sort)
if [ "$selected" != $'git\nnode' ]; then
    echo "FAILED: features_wizard_nonfzf selection mismatch, got: $selected"
    exit 1
fi

echo "OK: features tests passed"
