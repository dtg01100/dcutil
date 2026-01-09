#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.devcontainer"
cat > "$tmpdir/.devcontainer/devcontainer.json" <<'JSON'
{ "name": "test", "features": { "1": {}, "2": {"version":"1"} } }
JSON

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$tmpdir"
source "$script_dir/../../lib/core.sh"
source "$script_dir/../../lib/docker.sh"
source "$script_dir/../../lib/features.sh"
source "$script_dir/../../lib/template_integration.sh"

# Ensure PROJECT_DIR is set to the temporary project so parse_devcontainer_config
# can resolve the .devcontainer/devcontainer.json we created above.
PROJECT_DIR="$tmpdir"
export PROJECT_DIR

fetch_available_features_official() {
    echo '[{"id":"git","registry":"ghcr.io/devcontainers/features"},{"id":"docker-in-docker","registry":"ghcr.io/devcontainers/features"}]'
}

if parse_features_config >/dev/null 2>&1; then
    echo success
    exit 0
else
    echo fail
    exit 1
fi
