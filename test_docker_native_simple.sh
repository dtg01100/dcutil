#!/bin/bash

# Simple test for docker_native functionality
set -euo pipefail

# Set up environment FIRST, before sourcing modules
echo "Setting up environment..."
PROJECT_DIR="/var/mnt/Disk2/projects/dcutil/test_docker_native"
export PROJECT_DIR
cd "$PROJECT_DIR"
echo "PROJECT_DIR set to: '$PROJECT_DIR'"

# Source the modules
SCRIPT_DIR="/var/mnt/Disk2/projects/dcutil"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/docker_native.sh"

echo "Testing docker_native functionality..."
echo "PROJECT_DIR: $PROJECT_DIR"

# Test basic functions
echo "Testing check_docker_daemon..."
check_docker_daemon
echo "✅ Docker daemon check passed"

echo "Testing parse_devcontainer_config..."
parse_devcontainer_config
echo "✅ Config parsing passed"
echo "IMAGE_NAME: $IMAGE_NAME"
echo "WORKSPACE_FOLDER: $WORKSPACE_FOLDER"
echo "CONTAINER_USER: $CONTAINER_USER"

echo "Testing container creation..."
local_project_dir="$PROJECT_DIR"
echo "Local variable: local_project_dir='$local_project_dir'"
echo "Calling docker_up with PROJECT_DIR: '$PROJECT_DIR'"
docker_up "$PROJECT_DIR"
echo "✅ Container creation completed"