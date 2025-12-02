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
fetch_available_features_official() {
  echo '[{"id":"git","registry":"ghcr.io/devcontainers/features"},{"id":"docker-in-docker","registry":"ghcr.io/devcontainers/features"}]'
}

cd "$tmpproj"
PROJECT_DIR="$tmpproj"
export PROJECT_DIR

sanitize_features_json

if grep -q "ghcr.io/devcontainers/features/git" .devcontainer/devcontainer.json; then
  echo "Test passed: found git feature"
else
  echo "Test failed: git feature not found"
  exit 1
fi

if grep -q "docker-in-docker" .devcontainer/devcontainer.json; then
  echo "Test passed: found docker-in-docker feature"
else
  echo "Test failed: docker-in-docker feature not found"
  exit 1
fi

echo "All tests passed!"
