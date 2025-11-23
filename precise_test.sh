#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCUTIL="$SCRIPT_DIR/dcutil"

# Minimal test that mirrors the failing script
echo "Testing: $DCUTIL help"
if "$DCUTIL" help >/dev/null 2>&1; then
    echo "Test 1 passed"
else
    echo "Test 1 failed"
fi

echo "Testing: $DCUTIL userprobe help"
if "$DCUTIL" userprobe help >/dev/null 2>&1; then
    echo "Test 2 passed"
else
    echo "Test 2 failed"
fi

echo "All basic tests completed"