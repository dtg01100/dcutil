#!/usr/bin/env python3
"""
Feature manager for dcutil - handles devcontainer feature addition and management
"""

import json
import os
import sys
import subprocess


def get_devcontainer_config_path(project_dir):
    """
    Find the devcontainer.json file in the project directory

    Args:
        project_dir (str): Project directory path

    Returns:
        str or None: Path to devcontainer.json file, or None if not found
    """
    config_paths = [
        os.path.join(project_dir, '.devcontainer', 'devcontainer.json'),
        os.path.join(project_dir, '.devcontainer.json'),
        os.path.join(os.getcwd(), '.devcontainer', 'devcontainer.json'),
        os.path.join(os.getcwd(), '.devcontainer.json')
    ]

    for path in config_paths:
        if os.path.exists(path):
            return path

    return None


def feature_exists_in_devcontainer(config_path, feature_id):
    """
    Check if a feature already exists in the devcontainer.json file

    Args:
        config_path (str): Path to the devcontainer.json file
        feature_id (str): ID of the feature to check

    Returns:
        bool: True if feature exists, False otherwise
    """
    try:
        with open(config_path, 'r') as f:
            config_data = json.load(f)

        # Check if features section exists and the feature is in it
        if 'features' in config_data and isinstance(config_data['features'], dict):
            return feature_id in config_data['features']

        return False

    except (FileNotFoundError, json.JSONDecodeError):
        # If file doesn't exist or is invalid JSON, the feature doesn't exist
        return False


# Import the JSON utilities for consistent processing
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
try:
    from json_utils import (
        has_feature as json_has_feature,
        add_feature as json_add_feature
    )
except ImportError:
    print("Warning: Could not import json_utils. Falling back to basic JSON operations.", file=sys.stderr)
    # Define fallback implementations
    def json_has_feature(config_path, feature_id):
        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)

            # Check if features section exists and the feature is in it
            if 'features' in config_data and isinstance(config_data['features'], dict):
                return feature_id in config_data['features']

            return False

        except (FileNotFoundError, json.JSONDecodeError):
            # If file doesn't exist or is invalid JSON, the feature doesn't exist
            return False

    def json_add_feature(config_path, feature_id, options=None):
        if options is None:
            options = {}

        try:
            # Read the current configuration
            with open(config_path, 'r') as f:
                config_data = json.load(f)

            # Ensure the features section exists
            if 'features' not in config_data:
                config_data['features'] = {}

            # Add the feature
            config_data['features'][feature_id] = options

            # Write the updated configuration back to the file
            with open(config_path, 'w') as f:
                json.dump(config_data, f, indent=2)

            print(f"Feature {feature_id} added successfully to {config_path}")
            return True

        except FileNotFoundError:
            print(f"Error: Config file not found at {config_path}", file=sys.stderr)
            return False
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in config file {config_path}: {e}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"Error adding feature to devcontainer.json: {e}", file=sys.stderr)
            return False


def suggest_feature_for_agent(agent, project_dir):
    """
    Suggest appropriate features for an agent and optionally add them
    
    Args:
        agent (str): Name of the agent (e.g., "opencode", "aider")
        project_dir (str): Project directory path
    
    Returns:
        bool: True if feature was added or already exists, False if declined or failed
    """
    # Define feature mappings
    feature_map = {
        'opencode': ('ghcr.io/devcontainers/features/node:1', 'For Node.js/npm dependencies'),
        'aider': ('ghcr.io/devcontainers/features/python', 'For Python/pip dependencies'),
        'copilot-cli': ('ghcr.io/devcontainers/features/node:1', 'For Node.js/npm dependencies'),
        'cody': ('ghcr.io/devcontainers/features/node:1', 'For Node.js/npm dependencies'),
        'qwen-cli': ('ghcr.io/devcontainers/features/node:1', 'For Node.js/npm dependencies'),
        'gemini': ('ghcr.io/devcontainers/features/node:1', 'For Node.js/npm dependencies'),
        'claude-cli': ('ghcr.io/devcontainers/features/node:1', 'For Node.js/npm dependencies'),
        'openai-cli': ('ghcr.io/devcontainers/features/node:1', 'For Node.js/npm dependencies')
    }
    
    if agent not in feature_map:
        print(f"No recommended feature for agent: {agent}")
        return False
    
    feature_id, feature_desc = feature_map[agent]
    
    # Find the devcontainer configuration
    config_path = get_devcontainer_config_path(project_dir)
    if not config_path:
        print("No devcontainer configuration found in project directory")
        return False
    
    # Check if feature already exists using local function
    if feature_exists_in_devcontainer(config_path, feature_id):
        print(f"Feature {feature_id} already exists in devcontainer configuration")
        return True
    
    # Suggest the feature to the user with ANSI color codes
    YELLOW = '\033[1;33m'
    NC = '\033[0m'  # No Color
    
    print(f"{YELLOW}🚀 Quick Setup Option:{NC}")
    print(f"{YELLOW}Add the recommended feature ({feature_id}) to your devcontainer for better {agent} integration?{NC}")
    print(f"{YELLOW}This will automatically install {feature_id} dependencies in your container{NC}")
    print()
    
    try:
        response = input("Add feature to devcontainer? (Recommended) [Y/n]: ").strip().lower()
    except EOFError:
        # Default to 'n' if no input (for non-interactive environments)
        response = 'n'
    
    if response in ['', 'y', 'yes']:
        # Add the feature using the local function for reliable addition
        success = json_add_feature(config_path, feature_id, {})
        if success:
            print(f"{YELLOW}✅ Feature {feature_id} added to your devcontainer configuration.{NC}")
            print(f"{YELLOW}The container needs to be recreated for the new feature to take effect.{NC}")
            print(f"{YELLOW}Would you like to restart your container now?{NC}")
            print()
            
            try:
                restart_response = input("Restart container now? [Y/n]: ").strip().lower()
            except EOFError:
                restart_response = 'n'
                
            if restart_response in ['', 'y', 'yes']:
                print("Restarting container to apply new feature...")
                try:
                    # Run dcutil up to restart the container with new features
                    result = subprocess.run(['dcutil', 'up'], 
                                          capture_output=True, text=True, cwd=project_dir)
                    if result.returncode == 0:
                        print(f"Container restarted with new feature {feature_id}")
                        return True
                    else:
                        print("Failed to restart container automatically.")
                        print("Please run 'dcutil up' to restart your container to apply the new feature.")
                        return True
                except Exception as e:
                    print(f"Error restarting container: {e}")
                    print("Please run 'dcutil up' to restart your container to apply the new feature.")
                    return True
            else:
                print(f"{YELLOW}⚠️  Remember to run 'dcutil up' to restart your container to apply the new feature.{NC}")
                return True
        else:
            print("Could not add feature to devcontainer.json automatically")
            return False
    else:
        print("Skipping automatic feature installation - proceeding with manual approach")
        return False


def main():
    if len(sys.argv) < 3:
        print("Usage: feature_manager.py <agent> <project_dir>", file=sys.stderr)
        print("Supported agents: opencode, aider, copilot-cli, cody, qwen-cli, gemini, claude-cli, openai-cli", file=sys.stderr)
        sys.exit(1)
    
    agent = sys.argv[1]
    project_dir = sys.argv[2]
    
    success = suggest_feature_for_agent(agent, project_dir)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()