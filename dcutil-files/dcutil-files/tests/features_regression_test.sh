#!/usr/bin/env bash

set -euo pipefail

# Tests for features edge-cases and regressions
# Requires jq

# Compute repo root and source the library
REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
cd "$TEST_DIR"

# Source features helper (do not pull template_integration)
LIB_DIR="$TEST_DIR/lib"
mkdir -p "$LIB_DIR"
. "$REPO_ROOT/lib/features.sh"

# helper to read keys in file
get_keys() {
    jq -r 'if .features == null then "" elif (.features|type)=="object" then .features | keys[] elif (.features|type)=="array" then .features[] else "" end' "$1" 2>/dev/null || true
}

# Test: features_get_current for object
cat > devcontainer.json <<'EOF'
{
  "features": {
    "ghcr.io/devcontainers/features/git": {},
    "ghcr.io/devcontainers/features/docker": {}
  }
}
EOF
current=$(features_get_current | sort)
if [ "$current" != $'docker\ngit' ]; then
    echo "FAILED: features_get_current for object returned: $current"
    exit 1
fi

# Test: features_get_current for array
cat > devcontainer.json <<'EOF'
{
  "features": [
    "ghcr.io/devcontainers/features/git",
    "ghcr.io/devcontainers/features/docker"
  ]
}
EOF
current=$(features_get_current | sort)
if [ "$current" != $'docker\ngit' ]; then
    echo "FAILED: features_get_current for array returned: $current"
    exit 1
fi

# Test: features_apply_changes converts array to object and adds feature
cat > devcontainer.json <<'EOF'
{
  "features": ["ghcr.io/devcontainers/features/git"]
}
EOF
# Desired selection: git + docker
export DCUTIL_ASSUME_YES=1
printf 'git\ndocker\n\n' | features_apply_changes >/dev/null
if ! jq -e '.features["ghcr.io/devcontainers/features/git"] and .features["ghcr.io/devcontainers/features/docker"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_apply_changes did not add docker to array-based features"
    exit 1
fi

# Test: features_apply_changes removes feature from object
export DCUTIL_ASSUME_YES=1
printf 'docker\n\n' | features_apply_changes >/dev/null
if jq -e '.features["ghcr.io/devcontainers/features/git"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_apply_changes did not remove git"
    exit 1
fi
if ! jq -e '.features["ghcr.io/devcontainers/features/docker"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_apply_changes unexpectedly removed docker"
    exit 1
fi
export DCUTIL_ASSUME_YES=0

# Test: features_add with full key and with csv/mixed input
cat > devcontainer.json <<'EOF'
{
  "features": {}
}
EOF
features_add ghcr.io/devcontainers/features/node
if ! jq -e '.features["ghcr.io/devcontainers/features/node"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_add failed for full key"
    exit 1
fi

features_add git,docker
if ! jq -e '.features["ghcr.io/devcontainers/features/git"] and .features["ghcr.io/devcontainers/features/docker"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_add csv input failed"
    exit 1
fi

# Test: features_remove with full key and multi-args
features_remove ghcr.io/devcontainers/features/node git
if jq -e '.features["ghcr.io/devcontainers/features/node"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_remove failed for full key"
    exit 1
fi
if jq -e '.features["ghcr.io/devcontainers/features/git"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_remove failed for multi-args"
    exit 1
fi

# Test: features_remove with comma separated
features_add git docker node
features_remove git,docker
if jq -e '.features["ghcr.io/devcontainers/features/git"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_remove did not remove git from csv"
    exit 1
fi
if jq -e '.features["ghcr.io/devcontainers/features/docker"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_remove did not remove docker from csv"
    exit 1
fi

# Test: features_show lists current features JSON without crashing
features_list_output=$(features_show || true)
if [ -z "$features_list_output" ]; then
    echo "FAILED: features_show returned empty"
    exit 1
fi

# Test: features_add accepts space-separated multiple args
cat > devcontainer.json <<'EOF'
{
  "features": {}
}
EOF
features_add git docker node
if ! jq -e '.features["ghcr.io/devcontainers/features/git"] and .features["ghcr.io/devcontainers/features/docker"] and .features["ghcr.io/devcontainers/features/node"]' devcontainer.json >/dev/null; then
    echo "FAILED: features_add did not add multiple space-separated args"
    exit 1
fi

# All good
echo "OK: features regression tests passed"