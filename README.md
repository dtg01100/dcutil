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
- `init` - Initialize a devcontainer (fast or wizard mode)
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

### Initialization

Use the `init` command to create a devcontainer configuration:

```bash
# Interactive wizard with multiple project types
./dcutil init

# Quick basic Ubuntu setup
./dcutil init fast
```

The wizard supports:
- Basic Ubuntu container with common tools
- Node.js development environment
- Python development environment  
- Go development environment
- Custom Docker images

## Requirements

- Devcontainer CLI (`npm install -g @devcontainers/cli`)
- Docker