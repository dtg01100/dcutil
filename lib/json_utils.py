#!/usr/bin/env python3
"""
JSON utilities for dcutil - centralizing complex JSON operations that are error-prone in bash
"""

import json
import sys
import os
from pathlib import Path


def read_devcontainer_config(config_path):
    """
    Safely read and parse a devcontainer.json file
    
    Args:
        config_path (str): Path to the devcontainer.json file
    
    Returns:
        dict: Parsed configuration or empty dict if error
    """
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error reading config file {config_path}: {e}", file=sys.stderr)
        return {}


def write_devcontainer_config(config_path, config_data):
    """
    Safely write a devcontainer.json file
    
    Args:
        config_path (str): Path to the devcontainer.json file
        config_data (dict): Configuration data to write
    
    Returns:
        bool: True if successful, False otherwise
    """
    try:
        # Create backup
        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                backup_content = f.read()
            with open(config_path + '.backup', 'w') as f:
                f.write(backup_content)
        
        # Write new content
        with open(config_path, 'w') as f:
            json.dump(config_data, f, indent=2)
        
        return True
    except Exception as e:
        print(f"Error writing config file {config_path}: {e}", file=sys.stderr)
        return False


def has_feature(config_path, feature_id):
    """
    Check if a feature is already present in the devcontainer configuration
    
    Args:
        config_path (str): Path to the devcontainer.json file
        feature_id (str): ID of the feature to check
    
    Returns:
        bool: True if feature exists, False otherwise
    """
    config = read_devcontainer_config(config_path)
    features = config.get('features', {})
    return feature_id in features


def add_feature(config_path, feature_id, options=None):
    """
    Add a feature to the devcontainer configuration

    Args:
        config_path (str): Path to the devcontainer.json file
        feature_id (str): ID of the feature to add
        options (dict): Feature options, defaults to {}

    Returns:
        bool: True if successful, False otherwise
    """
    if options is None:
        options = {}

    # Validate inputs before processing
    if not config_path or not feature_id:
        print("Error: config_path and feature_id are required", file=sys.stderr)
        return False

    # Read current configuration
    config = read_devcontainer_config(config_path)
    if not config:
        print(f"Error: Could not read or parse config file: {config_path}", file=sys.stderr)
        return False

    # Ensure features section exists and is a dictionary
    if 'features' not in config or not isinstance(config['features'], dict):
        config['features'] = {}

    # Add the feature
    config['features'][feature_id] = options

    # Validate the config structure before writing
    if not validate_config_structure_basic(config):
        print(f"Error: Configuration would be invalid after adding feature {feature_id}", file=sys.stderr)
        return False

    return write_devcontainer_config(config_path, config)


def has_mount(config_path, source_path):
    """
    Check if a mount with the given source path is already configured
    
    Args:
        config_path (str): Path to the devcontainer.json file
        source_path (str): Source path to check for
    
    Returns:
        bool: True if mount exists, False otherwise
    """
    config = read_devcontainer_config(config_path)
    mounts = config.get('mounts', [])
    
    for mount in mounts:
        if isinstance(mount, str) and source_path in mount:
            return True
        elif isinstance(mount, dict) and mount.get('source') == source_path:
            return True
    
    return False


def add_mount(config_path, source_path, target_path, mount_type="bind"):
    """
    Add a mount to the devcontainer configuration
    
    Args:
        config_path (str): Path to the devcontainer.json file
        source_path (str): Source path on the host
        target_path (str): Target path in the container
        mount_type (str): Type of mount (bind, volume, etc.), defaults to "bind"
    
    Returns:
        bool: True if successful, False otherwise
    """
    config = read_devcontainer_config(config_path)
    
    # Ensure mounts section exists
    if 'mounts' not in config:
        config['mounts'] = []
    
    # Create mount spec
    mount_spec = f"type={mount_type},source={source_path},target={target_path}"
    
    # Add mount if it doesn't already exist
    if mount_spec not in config['mounts']:
        config['mounts'].append(mount_spec)
    
    return write_devcontainer_config(config_path, config)


def get_container_user(config_path):
    """
    Get the container user from devcontainer configuration
    
    Args:
        config_path (str): Path to the devcontainer.json file
    
    Returns:
        str: Container user or "vscode" if not specified
    """
    config = read_devcontainer_config(config_path)
    return config.get('containerUser', 'vscode')


def validate_config_structure_basic(config_data):
    """
    Validate basic devcontainer.json structure (for in-memory structure)

    Args:
        config_data (dict): Configuration dictionary to validate

    Returns:
        bool: True if valid, False otherwise
    """
    if not isinstance(config_data, dict):
        return False

    # Validate required structures
    features = config_data.get('features', {})
    if features and not isinstance(features, dict):
        return False

    mounts = config_data.get('mounts', [])
    if mounts and not isinstance(mounts, list):
        return False

    return True


def validate_config_structure(config_path):
    """
    Validate basic devcontainer.json structure

    Args:
        config_path (str): Path to the devcontainer.json file

    Returns:
        tuple(bool, list): (is_valid, list_of_issues)
    """
    config = read_devcontainer_config(config_path)
    issues = []

    if not isinstance(config, dict):
        issues.append("Config is not a valid JSON object")
        return False, issues

    # Validate required structures
    features = config.get('features', {})
    if features and not isinstance(features, dict):
        issues.append("Features section must be an object (map)")

    mounts = config.get('mounts', [])
    if mounts and not isinstance(mounts, list):
        issues.append("Mounts section must be an array")

    return len(issues) == 0, issues


def main():
    if len(sys.argv) < 3:
        print("Usage: json_utils.py <operation> <config_path> [args...]", file=sys.stderr)
        print("Operations:", file=sys.stderr)
        print("  read <config_path> - Read and output config", file=sys.stderr)
        print("  has_feature <config_path> <feature_id> - Check if feature exists", file=sys.stderr)
        print("  add_feature <config_path> <feature_id> [options_json] - Add a feature", file=sys.stderr)
        print("  get_container_user <config_path> - Get container user", file=sys.stderr)
        print("  validate <config_path> - Validate config structure", file=sys.stderr)
        sys.exit(1)
    
    operation = sys.argv[1]
    config_path = sys.argv[2]
    
    if operation == "read":
        config = read_devcontainer_config(config_path)
        print(json.dumps(config, indent=2))
        
    elif operation == "has_feature":
        if len(sys.argv) < 4:
            print("Error: has_feature requires feature_id argument", file=sys.stderr)
            sys.exit(1)
        feature_id = sys.argv[3]
        result = has_feature(config_path, feature_id)
        print("true" if result else "false")
        
    elif operation == "add_feature":
        if len(sys.argv) < 4:
            print("Error: add_feature requires feature_id argument", file=sys.stderr)
            sys.exit(1)
        feature_id = sys.argv[3]
        options = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}
        result = add_feature(config_path, feature_id, options)
        print("true" if result else "false")
        sys.exit(0 if result else 1)
        
    elif operation == "get_container_user":
        user = get_container_user(config_path)
        print(user)
        
    elif operation == "validate":
        is_valid, issues = validate_config_structure(config_path)
        if is_valid:
            print("valid")
        else:
            print("invalid")
            for issue in issues:
                print(issue)
        sys.exit(0 if is_valid else 1)
        
    elif operation == "add_mount":
        if len(sys.argv) < 5:
            print("Error: add_mount requires source_path and target_path arguments", file=sys.stderr)
            sys.exit(1)
        source_path = sys.argv[3]
        target_path = sys.argv[4]
        mount_type = sys.argv[5] if len(sys.argv) > 5 else "bind"
        result = add_mount(config_path, source_path, target_path, mount_type)
        print("true" if result else "false")
        sys.exit(0 if result else 1)
        
    else:
        print(f"Error: Unknown operation '{operation}'", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()