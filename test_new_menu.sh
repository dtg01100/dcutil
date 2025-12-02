#!/bin/bash

# Test script for the new interactive menu system

# Source the template integration library
source /var/mnt/Disk2/projects/dcutil/lib/template_integration.sh

# Mock test data
mock_templates='[
  {"id": "go", "name": "Go", "description": "Official Go programming language container"},
  {"id": "javascript-node", "name": "Node.js", "description": "Node.js development with JavaScript/TypeScript"},
  {"id": "python", "name": "Python", "description": "Python development environment"}
]'

mock_features='[
  {"id": "git", "name": "Git", "description": "Install Git from source (latest version)", "registry": "ghcr.io/devcontainers/features"},
  {"id": "common-utils", "name": "Common Utils", "description": "Common command line utilities, zsh, and non-root setup", "registry": "ghcr.io/devcontainers/features"},
  {"id": "docker-in-docker", "name": "Docker-in-Docker", "description": "Docker Engine and CLI in container with DinD", "registry": "ghcr.io/devcontainers/features"},
  {"id": "github-cli", "name": "GitHub CLI", "description": "GitHub CLI (gh) with auth support", "registry": "ghcr.io/devcontainers/features"},
  {"id": "aws-cli", "name": "AWS CLI", "description": "Amazon Web Services CLI", "registry": "ghcr.io/devcontainers/features"},
  {"id": "kubectl-helm", "name": "kubectl & Helm", "description": "Kubernetes CLI (kubectl) and Helm", "registry": "ghcr.io/devcontainers/features"}
]'

echo "Testing the new interactive template selection..."
echo "==============================================="
echo ""

echo "Testing select_template_interactive function:"
select_template_interactive "$mock_templates"
if [ $? -eq 0 ]; then
    echo "Selected template: $user_selected_template"
else
    echo "Template selection was cancelled or failed"
fi

echo ""
echo "Testing the new interactive feature selection..."
echo "==============================================="
echo ""

echo "Testing select_features_interactive function:"
select_features_interactive "$mock_features"
if [ $? -eq 0 ]; then
    echo "Selected features: $user_selected_features"
else
    echo "Feature selection was cancelled or failed"
fi

echo ""
echo "Test completed."
