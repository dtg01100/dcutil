#!/bin/bash
tmpproj=$(mktemp -d)
mkdir -p "$tmpproj/.devcontainer"
cat > "$tmpproj/.devcontainer/devcontainer.json" << 'JD'
{
  "name": "tmpl",
  "features": {
    "1": {},
    "ghcr.io/devcontainers/features/2": {}
  }
}
JD
source "/var/mnt/Disk2/projects/dcutil/lib/core.sh"
source "/var/mnt/Disk2/projects/dcutil/lib/template_integration.sh"
fetch_available_features_official() { echo '[{"id":"git","registry":"ghcr.io/devcontainers/features"},{"id":"docker-in-docker","registry":"ghcr.io/devcontainers/features"}]'; }
cd "$tmpproj"
PROJECT_DIR="$tmpproj"
export PROJECT_DIR
sanitize_features_json
grep -q "ghcr.io/devcontainers/features/git" .devcontainer/devcontainer.json && echo "SUCCESS: git feature found after sanitization" || echo "FAIL: git feature not found"
