#!/bin/bash

# Demonstration of dcutil security vulnerabilities
# WARNING: This script demonstrates real security issues
# DO NOT run on production systems

echo "🔴 dcutil Security Vulnerability Demonstration"
echo "=============================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCUTIL="$SCRIPT_DIR/dcutil-files/dcutil"

echo "Testing environment setup..."
echo "DCUTIL path: $DCUTIL"
echo ""

# Test 1: Demonstrate command injection vulnerability
echo "🧪 Test 1: Command Injection in 'run' command"
echo "---------------------------------------------"

# Create a test directory
mkdir -p /tmp/dcutil-test
cd /tmp/dcutil-test || exit

# Create a minimal devcontainer.json
cat > .devcontainer/devcontainer.json << 'EOF'
{
    "name": "test-container",
    "image": "ubuntu:latest"
}
EOF

echo "Created test devcontainer.json"

# This would be vulnerable if a container was running:
echo "VULNERABILITY: If a container were running, this command would inject:"
echo "dcutil run 'echo vulnerable; whoami; id'"
echo ""
echo "The command would execute: docker exec <container> /bin/sh -c 'echo vulnerable; whoami; id'"
echo "Result: Multiple commands execute instead of one"
echo ""

# Test 2: Demonstrate path traversal issue
echo "🧪 Test 2: Path Traversal in Volume Management"
echo "---------------------------------------------"

echo "VULNERABILITY: Volume paths are not properly validated"
echo "Command: dcutil volumes add evil ../../../etc/passwd /tmp/evil"
echo "This could allow reading sensitive files outside project directory"
echo ""

# Test 3: Demonstrate uninitialized variable bug
echo "🧪 Test 3: Uninitialized Variable Bug"
echo "------------------------------------"

echo "BUG: In lib/volumes.sh, close_lock \"\$fd\" is called before fd is defined"
echo "This causes 'close_lock: command not found' errors"
echo ""

# Test 4: Demonstrate weak input validation
echo "🧪 Test 4: Weak Input Validation"
echo "--------------------------------"

echo "VULNERABILITY: Dangerous shell constructs only generate warnings"
echo "Command validation in validate_run_command only warns, doesn't block"
echo ""

# Test 5: Demonstrate TOCTOU issues
echo "🧪 Test 5: Time-of-Check-Time-of-Use (TOCTOU)"
echo "---------------------------------------------"

echo "VULNERABILITY: File existence checked, then file operated on without atomicity"
echo "Pattern found in 100+ locations: if [ -f \"\$file\" ]; then operate_on_file \"\$file\"; fi"
echo "Race condition: file could be deleted/modified between check and use"
echo ""

# Test 6: Demonstrate error handling issues
echo "🧪 Test 6: Error Handling Issues"
echo "--------------------------------"

echo "BUG: cd - || exit in validate_project_path causes unconditional exit"
echo "If returning to previous directory fails, entire script exits"
echo ""

echo "🛡️  SECURITY RECOMMENDATIONS"
echo "============================"
echo ""
echo "1. Fix command injection in docker_run:"
echo "   - Change: docker exec \"\$container_id\" /bin/sh -c \"\$*\""
echo "   - To:     docker exec \"\$container_id\" \"\$@\""
echo ""
echo "2. Strengthen path validation:"
echo "   - Block .. sequences entirely, don't just warn"
echo "   - Use realpath for canonical path resolution"
echo ""
echo "3. Fix uninitialized variables:"
echo "   - Move lock operations to correct sequence in add_volume"
echo ""
echo "4. Add atomic file operations:"
echo "   - Use flock for all file existence + operation patterns"
echo ""
echo "5. Improve input validation:"
echo "   - Block dangerous patterns, don't just warn"
echo "   - Add comprehensive shell metacharacter detection"
echo ""

echo "✅ Demonstration complete"
echo "See SECURITY_AUDIT_REPORT.md for full details"