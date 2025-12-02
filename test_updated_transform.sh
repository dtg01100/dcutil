#!/bin/bash

# Test the updated jq transformation logic
echo "Testing updated jq transformation..."

# Create a temporary directory with a sample devcontainer.json
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

echo "Original devcontainer.json:"
cat "$tmpproj/.devcontainer/devcontainer.json"

# Now test the updated transformation logic
features_json='[{"id":"git","registry":"ghcr.io/devcontainers/features"},{"id":"docker-in-docker","registry":"ghcr.io/devcontainers/features"}]'

# Apply the updated transformation
echo "$features_json" | jq --argjson pref "$features_json" '
    def mapkey(k):
        # First, check if k is purely numeric (like "1", "2", etc.)
        if k | test("^[0-9]+$") then
            (k | tonumber - 1) as $i
            | ($pref[$i].id // "") as $fid
            | ($pref[$i].registry // "ghcr.io/devcontainers/features") as $fr
            | if $fid == "" then k else ($fr + "/" + $fid) end
        # Then check if k is in registry+numeric format (like "ghcr.io/devcontainers/features/2")
        elif k | test("^ghcr.io/devcontainers/features/[0-9]+(:.*)?$") then
            (k | capture("^ghcr.io/devcontainers/features/(?<idx>[0-9]+)(?<rest>[:].*)?$") ) as $m
            | ($m.idx | tonumber - 1) as $i
            | ($pref[$i].id // "") as $fid
            | ($pref[$i].registry // "ghcr.io/devcontainers/features") as $fr
            | if $fid == "" then k else ($fr + "/" + $fid + ($m.rest // "")) end
        else k end;
    .features = (.features // {} | to_entries | map(.key = mapkey(.key)) | from_entries)
' "$tmpproj/.devcontainer/devcontainer.json" > "$tmpproj/.devcontainer/devcontainer.json.tmp" && mv "$tmpproj/.devcontainer/devcontainer.json.tmp" "$tmpproj/.devcontainer/devcontainer.json"

echo ""
echo "After applying updated transformation:"
cat "$tmpproj/.devcontainer/devcontainer.json"

# Check the result
if grep -q "git" "$tmpproj/.devcontainer/devcontainer.json" && grep -q "docker-in-docker" "$tmpproj/.devcontainer/devcontainer.json"; then
    echo "SUCCESS: Both transformations worked correctly!"
    echo "  - Numeric key '1' was mapped to 'git' feature"
    echo "  - Registry+numeric 'ghcr.io/devcontainers/features/2' was mapped to 'docker-in-docker' feature"
else
    echo "ISSUE: Expected transformations were not applied properly"
    if grep -q "git" "$tmpproj/.devcontainer/devcontainer.json"; then
        echo "  - Numeric key '1' was mapped to 'git' feature (✓)"
    else
        echo "  - Numeric key '1' was NOT mapped to 'git' feature (✗)"
    fi
    if grep -q "docker-in-docker" "$tmpproj/.devcontainer/devcontainer.json"; then
        echo "  - Registry+numeric key was mapped to 'docker-in-docker' feature (✓)"
    else
        echo "  - Registry+numeric key was NOT mapped to 'docker-in-docker' feature (✗)"
    fi
fi

# Clean up
rm -rf "$tmpproj"
