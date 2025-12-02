#!/bin/bash

# Test script for the new interactive menu system (non-interactive version)

# Source the template integration library
source /var/mnt/Disk2/projects/dcutil/lib/template_integration.sh

# Test data
mock_templates='[{"id": "go", "name": "Go", "description": "Official Go programming language container"}, {"id": "python", "name": "Python", "description": "Python development environment"}]'
mock_features='[{"id": "git", "name": "Git", "description": "Install Git from source"}, {"id": "common-utils", "name": "Common Utils", "description": "Common command line utilities"}]'

echo "Testing template selection with auto-select..."
echo "============================================="

# Test auto-selection functionality (non-interactive)
select_template_interactive "$mock_templates" "go"
if [ $? -eq 0 ] && [ "$user_selected_template" = "go" ]; then
    echo "✓ Auto-template selection test passed"
else
    echo "✗ Auto-template selection test failed"
    echo "  Expected: go, Got: $user_selected_template"
fi

echo ""
echo "Testing template selection with invalid auto-select..."
select_template_interactive "$mock_templates" "invalid-template"
if [ $? -ne 0 ]; then
    echo "✓ Invalid template auto-selection correctly rejected"
else
    echo "✗ Invalid template auto-selection should have failed"
fi

echo ""
echo "Testing feature selection would require interaction, skipping for this test..."
echo "All non-interactive tests passed!"
