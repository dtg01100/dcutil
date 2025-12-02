#!/bin/bash

# Helper script for expect testing
source /var/mnt/Disk2/projects/dcutil/lib/core.sh
source /var/mnt/Disk2/projects/dcutil/lib/template_integration.sh

if [ "$1" = "template" ]; then
    # Template test
    mock_templates='[{"id": "go", "name": "Go", "description": "Official Go programming language container"}, {"id": "python", "name": "Python", "description": "Python development environment"}]'
    select_template_interactive "$mock_templates"
    echo "RESULT:$?"
    echo "SELECTED:$user_selected_template"
elif [ "$1" = "feature" ]; then
    # Feature test
    mock_features='[{"id": "git", "name": "Git", "description": "Install Git from source"}, {"id": "common-utils", "name": "Common Utils", "description": "Common command line utilities"}, {"id": "docker-in-docker", "name": "Docker-in-Docker", "description": "Docker Engine and CLI"}]'
    select_features_interactive "$mock_features"
    echo "RESULT:$?"
    echo "SELECTED:$user_selected_features"
fi
