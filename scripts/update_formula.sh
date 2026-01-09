#!/usr/bin/env bash

# Script to update the Homebrew formula with latest version and checksums
# Usage: ./update_formula.sh [version]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMULA_FILE="$SCRIPT_DIR/dcutil.rb"

# Get version from command line or use current version
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    # Try to get version from dcutil script
    if [ -f "$SCRIPT_DIR/dcutil" ]; then
        VERSION=$(grep '^VERSION=' "$SCRIPT_DIR/dcutil" | cut -d'"' -f2 | sed 's/^v//')
    fi
fi

if [ -z "$VERSION" ]; then
    echo "Error: Could not determine version. Please specify: $0 <version>"
    exit 1
fi

echo "Updating Homebrew formula for dcutil v$VERSION..."

# Create tarball URL
TARBALL_URL="https://github.com/dtg01100/dcutil/archive/refs/tags/v${VERSION}.tar.gz"
echo "Tarball URL: $TARBALL_URL"

# Note: SHA256 will be automatically updated by the Homebrew tap's CI/CD pipeline
# when the release is published. This script is for local testing and preparation.

echo "Formula template updated for version $VERSION"
echo "The SHA256 checksum will be automatically calculated by the Homebrew tap when the release is published."

# Update the formula template
sed -i.bak "s|v1\.0\.8|v$VERSION|g" "$FORMULA_FILE"

# Clean up backup
rm -f "${FORMULA_FILE}.bak"

echo "Formula updated successfully!"
echo "Don't forget to:"
echo "1. Test the formula locally: brew install --build-from-source dcutil.rb"
echo "2. Commit and push the updated formula to the Homebrew tap"
echo "3. The GitHub Actions workflow will automatically update the checksum when the release is published"
echo "4. Update bottle checksums if creating bottles"