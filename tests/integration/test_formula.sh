#!/usr/bin/env bash

# Test the Homebrew formula locally
# Usage: ./test_formula.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMULA_FILE="$SCRIPT_DIR/dcutil.rb"

echo "Testing Homebrew formula locally..."

# Check if Homebrew is available
if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Homebrew not found. Please install Homebrew first."
    echo "   Visit: https://brew.sh/"
    exit 1
fi

# Check if formula file exists
if [ ! -f "$FORMULA_FILE" ]; then
    echo "❌ Formula file not found: $FORMULA_FILE"
    exit 1
fi

echo "✅ Found formula file: $FORMULA_FILE"

# Validate formula syntax
echo "🔍 Validating formula syntax..."
if brew style "$FORMULA_FILE" 2>/dev/null; then
    echo "✅ Formula syntax is valid"
else
    echo "❌ Formula syntax errors found"
    exit 1
fi

# Test formula installation (dry run)
echo "🔍 Testing formula installation (dry run)..."
if brew install --dry-run "$FORMULA_FILE" 2>/dev/null; then
    echo "✅ Formula installation test passed"
else
    echo "❌ Formula installation test failed"
    exit 1
fi

# Check dependencies
echo "🔍 Checking dependencies..."
echo "Required dependencies:"
echo "  - jq: $(brew list jq >/dev/null 2>&1 && echo '✅ installed' || echo '❌ not installed')"
echo "  - devcontainer: $(command -v devcontainer >/dev/null 2>&1 && echo '✅ available' || echo '❌ not available')"
echo "  - curl: $(command -v curl >/dev/null 2>&1 && echo '✅ available' || echo '❌ not available')"

echo ""
echo "Optional dependencies:"
echo "  - docker: $(command -v docker >/dev/null 2>&1 && echo '✅ available' || echo '❌ not available')"
echo "  - podman: $(command -v podman >/dev/null 2>&1 && echo '✅ available' || echo '❌ not available')"
echo "  - git: $(command -v git >/dev/null 2>&1 && echo '✅ available' || echo '❌ not available')"
echo "  - node: $(command -v node >/dev/null 2>&1 && echo '✅ available' || echo '❌ not available')"

echo ""
echo "📋 Next steps:"
echo "1. Test the formula locally: brew install --build-from-source dcutil.rb"
echo "2. Create a GitHub release with tag v$VERSION"
echo "3. The Homebrew tap will automatically update the SHA256 checksum"
echo "4. If creating bottles, update bottle checksums"
echo "5. Commit and push any formula changes to the Homebrew tap repository"
echo ""
echo "Note: This formula is currently Linux-only since macOS testing is not available."

echo ""
echo "🎉 Formula validation complete!"