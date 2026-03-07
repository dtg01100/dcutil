# Homebrew Tap for dcutil

This is the official Homebrew tap for [dcutil](https://github.com/dtg01100/dcutil), a command-line tool for managing development containers with enhanced user experience, intelligent auto-completion, and robust error handling.

## Installation

```bash
brew tap dtg01100/homebrew-dcutil
brew install dcutil
```

### Dependencies

**Required:**
- `jq` - JSON processing
- `devcontainer` - Official Microsoft devcontainer CLI
- `curl` - HTTP client for templates/features
- Docker or Podman - Container runtime

**Optional:**
- `git` - Git operations
- `docker-compose` / `podman-compose` - Compose support
- `node` / `npm` - For various agents and tools

### Post-Installation

After installation, you can verify everything works:

```bash
# Check version
dcutil version

# Run tests
dcutil test

# Get help
dcutil help
```

**Note**: Currently Linux-only. The Homebrew formula is automatically updated when new releases are published on GitHub.

## What is dcutil?

dcutil is a command-line tool for managing development containers with enhanced user experience, intelligent auto-completion, and robust error handling. Supports all Devcontainer Specification features through seamless integration with container runtimes.

### Features

- **Container Management**: Start, stop, restart, and monitor development containers
- **Project Initialization**: Interactive wizard for creating devcontainer configurations with templates and features
- **Volume Management**: Create, manage, and backup persistent volumes
- **AI Agent Installation**: Install coding assistants (opencode, aider, etc.) in containers
- **Auto-Completion**: Intelligent shell completion for commands and options
- **Backend Support**: Automatic detection and support for Docker and Podman
- **Error Handling**: Clear error messages with actionable guidance
- **Cross-Platform**: Works on Linux, macOS, and other Unix-like systems

For more information, see the [main repository](https://github.com/dtg01100/dcutil).

## Tab Completion

This Homebrew formula includes tab completion for bash, zsh, and fish:

### Bash
If you have bash-completion installed, dcutil completion will be automatically available.

### Zsh
Zsh completion is installed and will be available automatically if you're using the zsh shell.

### Fish
Fish completion is installed and will be available automatically if you're using the fish shell.

Alternatively, you can use the built-in completion generation feature:
```bash
# Generate bash completion
dcutil completion bash > /path/to/completions/bash/dcutil

# Generate zsh completion
dcutil completion zsh > /path/to/completions/zsh/_dcutil

# Generate fish completion
dcutil completion fish > /path/to/completions/fish/dcutil.fish
```

## Usage

After installation, use `dcutil` commands to manage your devcontainers:

### Core Container Management

- `up [options]` - Start the devcontainer (with optional --project-home)
- `down` - Stop the devcontainer
- `restart` - Restart the devcontainer
- `enter` - Enter the container shell (offers to start if stopped)
- `build` - Build the devcontainer image
- `clean` - Remove containers, volumes, and configuration files
- `status` - Show container status
- `logs` - Show container logs
- `list` - List running devcontainers
- `run <cmd>` - Run a command in the container

### Advanced Features

- `features <cmd>` - Devcontainer Features management (install, info, validate, clean, update)
- `advanced <cmd>` - Advanced configuration (info, validate, apply)
- `integration <cmd>` - Tool integration (info, validate, apply)
- `merging <cmd>` - Image metadata merging (show, validate, cleanup)

### Extended Specification Features

- `userprobe <cmd>` - User environment probing (probe, show, apply, validate, cleanup)
- `hostrequirements <cmd>` - Host system validation (validate, show, cleanup)
- `shutdown <cmd>` - Container shutdown actions (execute, show, validate)
- `schema <cmd>` - Configuration schema validation (validate, show, cleanup)

### Orchestration & Utilities

- `compose <cmd>` - Docker Compose environments (up, down, restart, logs, exec, status, scale, config)
- `volumes <cmd>` - Volume management (list, add, remove, mount, unmount, status, backup, restore)
- `init` - Initialize a devcontainer (fast or wizard mode)

- `completion` - Generate shell completion scripts
- `help` - Show help message

For detailed usage and examples, see the [main repository](https://github.com/dtg01100/dcutil).

## Contributing

Issues and pull requests for the formula should be filed in this tap repository. For dcutil itself, use the [main repository](https://github.com/dtg01100/dcutil).