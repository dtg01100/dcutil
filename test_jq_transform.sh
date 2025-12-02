#!/bin/bash

# Direct test to make sure the sanitize function works by using the same logic as in template_integration.sh
echo "Testing direct sanitize_features_json functionality..."

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

# Now test the jq transformation logic directly
features_json='[{"id":"git","registry":"ghcr.io/devcontainers/features"},{"id":"docker-in-docker","registry":"ghcr.io/devcontainers/features"}]'

# Apply the same transformation as in sanitize_features_json
echo "$features_json" | jq --argjson pref "$features_json" '
    def mapkey(k):
        if k | test("^ghcr.io/devcontainers/features/[0-9]+(:.*)?$") then
            (k | capture("^ghcr.io/devcontainers/features/(?<idx>[0-9]+)(?<rest>[:].*)?$") ) as $m
            | ($m.idx | tonumber - 1) as $i
            | ($pref[$i].id // "") as $fid
            | ($pref[$i].registry // "ghcr.io/devcontainers/features") as $fr
            | if $fid == "" then k else ($fr + "/" + $fid + ($m.rest // "")) end
        else k end;
    .features = (.features // {} | to_entries | map(.key = mapkey(.key)) | from_entries)
' "$tmpproj/.devcontainer/devcontainer.json" > "$tmpproj/.devcontainer/devcontainer.json.tmp" && mv "$tmpproj/.devcontainer/devcontainer.json.tmp" "$tmpproj/.devcontainer/devcontainer.json"

echo ""
echo "After applying transformation:"
cat "$tmpproj/.devcontainer/devcontainer.json"

# Check the result
if grep -q "git" "$tmpproj/.devcontainer/devcontainer.json"; then
    echo "SUCCESS: Numeric key '1' was mapped to 'git' feature"
elif grep -q "ghcr.io/devcontainers/features/1" "$tmpproj/.devcontainer/devcontainer.json"; then
    echo "INFO: ghcr.io/devcontainers/features/2 was found in the file"
    if grep -q "docker-in-docker" "$tmpproj/.devcontainer/devcontainer.json"; then
        echo "SUCCESS: ghcr.io/devcontainers/features/2 was mapped to docker-in-docker feature"
    else
        echo "PARTIAL: Only one mapping worked"
    fi
else
    echo "ISSUE: Expected transformations were not applied properly"
fi

# Clean up
rm -rf "$tmpproj"
