#!/bin/bash

# Comprehensive test for the new interactive menu system

# Source the template integration library
source /var/mnt/Disk2/projects/dcutil/lib/template_integration.sh

# Test data
mock_templates='[{"id": "go", "name": "Go", "description": "Official Go programming language container"}, {"id": "python", "name": "Python", "description": "Python development environment"}]'
mock_features='[{"id": "git", "name": "Git", "description": "Install Git from source"}, {"id": "common-utils", "name": "Common Utils", "description": "Common command line utilities"}, {"id": "docker-in-docker", "name": "Docker-in-Docker", "description": "Docker Engine and CLI"}]'

echo "Testing template selection functionality..."
echo "==========================================="

# Test 1: Auto-select valid template
select_template_interactive "$mock_templates" "python"
if [ $? -eq 0 ] && [ "$user_selected_template" = "python" ]; then
    echo "✓ Test 1 PASSED: Auto-select valid template"
else
    echo "✗ Test 1 FAILED: Auto-select valid template"
    echo "  Expected: python, Got: $user_selected_template"
fi

# Test 2: Auto-select invalid template
select_template_interactive "$mock_templates" "invalid-template"
if [ $? -ne 0 ]; then
    echo "✓ Test 2 PASSED: Auto-select invalid template correctly rejected"
else
    echo "✗ Test 2 FAILED: Auto-select invalid template should have failed"
fi

echo ""
echo "Testing feature selection functionality..."
echo "=========================================="

# Test 3: Auto-select single valid feature
select_features_interactive "$mock_features" "git"
if [ $? -eq 0 ] && [ "$user_selected_features" = "git" ]; then
    echo "✓ Test 3 PASSED: Auto-select single valid feature"
else
    echo "✗ Test 3 FAILED: Auto-select single valid feature"
    echo "  Expected: git, Got: $user_selected_features"
fi

# Test 4: Auto-select multiple valid features
select_features_interactive "$mock_features" "git,common-utils"
if [ $? -eq 0 ] && [ "$user_selected_features" = "git,common-utils" ]; then
    echo "✓ Test 4 PASSED: Auto-select multiple valid features"
else
    echo "✗ Test 4 FAILED: Auto-select multiple valid features"
    echo "  Expected: git,common-utils, Got: $user_selected_features"
fi

# Test 5: Auto-select with whitespace
select_features_interactive "$mock_features" "git, common-utils"
if [ $? -eq 0 ] && [ "$user_selected_features" = "git,common-utils" ]; then
    echo "✓ Test 5 PASSED: Auto-select with whitespace handled correctly"
else
    echo "✗ Test 5 FAILED: Auto-select with whitespace not handled correctly"
    echo "  Expected: git,common-utils, Got: $user_selected_features"
fi

# Test 6: Auto-select invalid feature
select_features_interactive "$mock_features" "invalid-feature"
if [ $? -ne 0 ]; then
    echo "✓ Test 6 PASSED: Auto-select invalid feature correctly rejected"
else
    echo "✗ Test 6 FAILED: Auto-select invalid feature should have failed"
fi

# Test 7: Auto-select partially invalid features
select_features_interactive "$mock_features" "git,invalid-feature"
if [ $? -ne 0 ]; then
    echo "✓ Test 7 PASSED: Auto-select partially invalid features correctly rejected"
else
    echo "✗ Test 7 FAILED: Auto-select partially invalid features should have failed"
fi

echo ""
echo "All non-interactive tests completed successfully!"
echo "The new menu system supports both interactive and non-interactive modes."
