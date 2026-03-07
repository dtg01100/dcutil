#!/usr/bin/env bash

# Test script to verify the dcutil enter fix

set -e

DCUTIL="$(pwd)/dcutil-files/dcutil"
TEST_DIR="./test-enter-fix"

echo "🧪 Testing dcutil enter functionality"
echo "======================================="
echo ""

# Clean up any existing test directory
if [ -d "$TEST_DIR" ]; then
    echo "🧹 Cleaning up existing test directory..."
    rm -rf "$TEST_DIR"
fi

# Create test directory
echo "📁 Creating test directory: $TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Create a minimal devcontainer.json
echo "📝 Creating devcontainer.json..."
mkdir -p .devcontainer
cat > .devcontainer/devcontainer.json <<'EOF'
{
  "name": "Enter Test Container",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "customizations": {
    "vscode": {
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash"
      }
    }
  }
}
EOF

echo ""
echo "🚀 Starting devcontainer..."
if ! $DCUTIL up; then
    echo "❌ Failed to start devcontainer"
    exit 1
fi

echo ""
echo "✅ Devcontainer started successfully"
echo ""

# Test 1: Try to enter with a simple command that exits immediately
echo "🧪 Test 1: Execute simple command in container"
if echo 'echo "Hello from container"' | $DCUTIL enter 2>&1 | grep -q "Hello from container"; then
    echo "✅ Command execution works"
else
    echo "❌ Command execution failed"
    exit 1
fi

echo ""
echo "🧪 Test 2: Verify container is still running"
if $DCUTIL status | grep -q "running\|Running"; then
    echo "✅ Container is running"
else
    echo "❌ Container is not running"
    exit 1
fi

echo ""
echo "🧪 Test 3: Execute multiple commands"
if echo -e 'pwd\nwhoami\nexit' | $DCUTIL enter 2>&1 | grep -q "workspace"; then
    echo "✅ Multiple commands work"
else
    echo "❌ Multiple commands failed"
    exit 1
fi

echo ""
echo "🧹 Cleaning up..."
$DCUTIL down || true
cd ..
rm -rf "$TEST_DIR"

echo ""
echo "============================================"
echo "✅ ALL TESTS PASSED - dcutil enter is fixed"
echo "============================================"
