# dcutil

A general purpose devcontainer utility script that provides convenient commands for managing development containers.

## Features

- Start, stop, and manage devcontainers with simple commands
- Automatic project directory detection
- Colored output for better visibility
- Support for running commands inside containers
- Built-in opencode installation support

## Commands

- `up` - Start the devcontainer
- `down` - Stop the devcontainer  
- `enter` - Enter the container shell
- `build` - Build the devcontainer image
- `clean` - Remove the devcontainer and clean up
- `status` - Show container status
- `logs` - Show container logs
- `run <cmd>` - Run a command in the container
- `install-opencode` - Install opencode inside the devcontainer
- `help` - Show help message

## Usage

```bash
./dcutil <command> [project_path]
```

The script automatically detects the project directory:
1. Uses the provided path if specified
2. Uses current directory if it contains `.devcontainer/`
3. Falls back to the script's directory

## Requirements

- Devcontainer CLI (`npm install -g @devcontainers/cli`)
- Docker