# dcutil

Manage your development environments with ease - **no Docker knowledge required!**

dcutil is a command-line tool that makes it simple to create, run, and manage isolated development environments. Focus on coding, not on learning container platforms.

## Why dcutil?

- **Beginner-Friendly**: Plain language commands and helpful error messages
- **No Docker Expertise Needed**: Just use `dcutil up` to start coding
- **Guided Setup**: Interactive wizard walks you through environment creation
- **Smart Monitoring**: Check resource usage without understanding containers  
- **Helpful Guidance**: Every error tells you exactly what to do next
- **Cross-Platform**: Works on Linux, macOS, and other Unix-like systems

## What You Can Do

- **Quick Start**: `dcutil up` - Start your development environment
- **Interactive Setup**: `dcutil init` - Guided wizard for new projects
- **Monitor Resources**: `dcutil stats` - See CPU, memory usage in plain language
- **Manage Storage**: `dcutil volumes` - Handle persistent data easily
- **Add Tools**: `dcutil features` - Install languages and tools with one command
- **AI Assistants**: `dcutil install-agent` - Add coding helpers to your environment

## For the Curious

Under the hood, dcutil uses industry-standard development containers (the same technology VS Code uses). But you don't need to know that to use it effectively!

- **Auto-Detection**: Automatically works with Docker or Podman
- **Full Specification Support**: Implements the complete Devcontainer Specification
- **Seamless Integration**: Compatible with VS Code and other dev container tools

## Beginner-Friendly Features

### 🎯 Interactive Menu

Run `dcutil` without any arguments to see a friendly menu of common tasks:

```bash
$ dcutil
🚀 What would you like to do?
  1) Start my development environment
  2) Open a shell in my environment
  3) Stop my environment
  ...
```

### 💡 Smart Command Suggestions

Typos? No problem! dcutil suggests what you meant:

```bash
$ dcutil stauts
💡 Did you mean: dcutil status
```

### 👋 First-Run Welcome

New users see a helpful quick-start guide that appears once.

### 📊 Contextual Tips

Get helpful hints based on what you're doing:

- After `dcutil init` → "Run 'dcutil up' to start your environment"
- After `dcutil status` when stopped → Tips on how to start
- After `dcutil status` when running → What you can do now

### ⚠️ Clear Error Messages

Every error includes the exact command to fix it - no guessing!

## Installation

### Homebrew (Linux)

```bash
# Install dcutil from the custom tap
brew install dtg01100/dcutil/dcutil

# Install required dependencies
brew install jq devcontainer

# Install a container runtime (choose one)
sudo apt-get install docker.io       # Docker
# or
brew install podman                  # Podman

# Optional: Install additional tools for full functionality
brew install git docker-compose node
```

**Note**: Currently Linux-only. The Homebrew formula is automatically updated when new releases are published on GitHub.

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/dtg01100/dcutil.git
cd dcutil

# Make executable
chmod +x dcutil

# Install dependencies
# Ubuntu/Debian
sudo apt-get install jq curl

# macOS
brew install jq curl

# Install devcontainer CLI
npm install -g @devcontainers/cli

# Install container runtime
# Docker: https://docs.docker.com/get-docker/
# Podman: https://podman.io/getting-started/installation/
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

## Commands

### Core Container Management

- `up [options]` - Start the devcontainer (with optional --project-home)
- `down` - Stop the devcontainer
- `restart` - Restart the devcontainer
- `enter` - Enter the container shell (offers to start if stopped)
- `build` - Build the devcontainer image
- `clean` - Remove containers, volumes, and configuration files
- `status` - Show container status
- `stats` - Monitor container resource usage (CPU, memory, network, disk I/O)
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

### Container Backend Management

- `status` - Show container status and backend information
- Environment variable `DCUTIL_BACKEND` - Control container backend (docker, podman, auto)

### Orchestration & Utilities

- `compose <cmd>` - Docker Compose environments (up, down, restart, logs, exec, status, scale, config)
- `volumes <cmd>` - Volume management (list, add, remove, mount, unmount, status, backup, restore)
- `environment <cmd>` - Environment configuration (export-env, info, validate)
- `init` - Initialize a devcontainer (fast or wizard mode)
- `install-agent <agent>` - Install AI agent inside the devcontainer
- `completion` - Generate shell completion scripts
- `help` - Show help message

## Usage

```bash
./dcutil <command> [project_path] [options]
```

The script automatically detects the project directory:

1. Uses the provided path if specified
2. Uses current directory if it contains `.devcontainer/`
3. Falls back to the script's directory

### Project Home Directory Feature

The `--project-home` option allows you to set the container's home folder to the project directory:

```bash
# Start devcontainer with project directory as home folder
./dcutil up --project-home

# Start devcontainer with project directory as home folder for a specific project
./dcutil up --project-home /path/to/project
```

When using `--project-home`, the project directory will be mounted as the home directory (`/home/vscode`) in the container, allowing the container to use the project as the default home folder.

### Container Backend Selection

dcutil supports both Docker and Podman. Set the backend via environment variable:

```bash
# Use Docker (default)
./dcutil up

# Use Podman
DCUTIL_BACKEND=podman ./dcutil up

# Check status
./dcutil status
```

### Initialization

Use the `init` command to create a devcontainer configuration with an interactive wizard or fast setup:

```bash
# Interactive wizard with dynamic template and feature selection
./dcutil init

# Interactive wizard (explicit)
./dcutil init wizard

# Quick basic Ubuntu setup
./dcutil init fast
```

#### Enhanced Interactive Wizard

The wizard provides a comprehensive setup experience with:

**Dynamic Content Fetching:**

- **40+ Official Templates**: Automatically fetches and displays all available devcontainer templates from Microsoft's GitHub repository
- **27+ Devcontainer Features**: Live feature catalog with tools and runtimes (Node.js, Python, Go, Docker, AWS CLI, etc.)
- **24-hour Caching**: Templates and features are cached locally for improved performance

**User Interface Options:**

- **Dialog Interface**: Professional ncurses-based UI using `dialog` command (when available)
- **Text Interface**: Reliable fallback for environments without dialog support
- **Auto-Detection**: Automatically chooses the best interface based on terminal capabilities

**Configuration Options:**

- **Template Selection**: Choose from official templates (Ubuntu, Alpine, Node.js, Python, Go, etc.) or specify custom images
- **Feature Installation**: Select multiple features to install (Git, Docker, AWS CLI, etc.)
- **Container Configuration**: Auto-generated container names, customizable workspace folders, user settings
- **Mount Options**: Optional bind mounting of host project directory with proper permissions
- **Permission Management**: Configurable ownership settings for workspace directories

**Advanced Features:**

- **Numeric UID/GID Support**: Enter container user as name or UID[:GID] (e.g., "vscode" or "1000:1000")
- **Workspace Validation**: Ensures absolute paths, prevents root mounting, validates input
- **Smart Defaults**: Auto-generates meaningful container names from project directory
- **Immediate Startup**: Option to start the container immediately after configuration

**Example Wizard Flow:**

```
📋 Available Devcontainer Templates:
1) ubuntu          2) alpine          3) python
4) javascript-node 5) go             6) dotnet
...

🔧 Available Devcontainer Features:
1) git             2) github-cli      3) docker-in-docker
4) node           5) python         6) aws-cli
...

Container Configuration:
- Container name: dcutil-myproject
- Workspace folder: /workspaces
- Container user: vscode
- Mount options: bind mount enabled
- Permissions: chown to container user
```

The wizard creates production-ready devcontainer.json configurations with proper features, mounts, and customizations.

### Volume Management

dcutil provides comprehensive volume management with atomic operations and race condition prevention:

```bash
# Add a volume configuration
./dcutil volumes add my-volume /host/path /container/path bind

# List configured volumes
./dcutil volumes list

# Remove a volume configuration
./dcutil volumes remove my-volume

# Mount a volume to a running container
./dcutil volumes mount my-volume

# Check volume status
./dcutil volumes status

# Backup a volume
./dcutil volumes backup my-volume

# Restore a volume from backup
./dcutil volumes restore my-volume backup.tar.gz
```

#### Volume Types

- **bind**: Direct host directory mounting with consistency options
- **volume**: Named Docker volumes for persistent data
- **tmpfs**: Temporary filesystem mounts

#### Volume Management Advanced Features

- **Atomic Operations**: File locking prevents concurrent access corruption
- **Race Condition Prevention**: Retry logic for multi-process scenarios
- **Data Consistency**: fsync operations ensure data durability
- **Backup/Restore**: Full volume backup and restoration capabilities
- **Mount Type Validation**: Ensures correct mount configuration
- **Path Expansion**: Automatic tilde (~) and relative path resolution

### Interactive Container Entry

The `enter` command provides intelligent container access with automatic startup:

```bash
# If container is running - enters directly
$ dcutil enter

# If container exists but is stopped - offers to start it
$ dcutil enter
⚠️  Devcontainer exists but is not running.
Would you like to start it? (y/N): y
ℹ️  Starting devcontainer...
✅ Devcontainer restarted successfully
# (enters container)

# If no container exists - offers to create one
$ dcutil enter
⚠️  No devcontainer found for this project.
Would you like to start the devcontainer first? (y/N): y
# Creates and starts container, then enters
```

#### Interactive Entry Features

- **Smart Detection**: Automatically detects container state
- **User-Friendly Prompts**: Clear options for different scenarios
- **Non-Intrusive**: Non-interactive mode maintains script compatibility
- **Seamless Experience**: No need to manually check/start containers

### Resource Monitoring

Monitor your container's resource usage in real-time with the `stats` command. **No Docker/Podman knowledge required** - just check if your code is using a lot of resources!

```bash
# Quick snapshot - "Is my code using a lot of resources?"
dcutil stats

# Watch live while running tests or builds
dcutil stats watch

# See detailed limits - "Am I hitting my memory limit?"
dcutil stats detailed

# Check what's actually running
dcutil stats top
```

#### What You Can Check

- **CPU Usage** - Is your code doing heavy processing?
- **Memory Usage** - Are you running out of RAM?
- **Network I/O** - How much data is being transferred (for web apps)
- **Disk I/O** - File read/write activity
- **Running Programs** - What's actually executing inside

#### Beginner-Friendly Output

The stats command explains what everything means in plain language:

```
📊 Resource Usage for Your Development Container
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O         PIDS
12.5%     256MB / 2GB          12.8%     1.2MB / 856kB     15.2MB / 0B       42

💡 What does this mean?

  • CPU %      - How much processing power is being used (higher = busier)
  • MEM USAGE  - How much memory (RAM) your code is using
  • MEM %      - Percentage of available memory being used
  • NET I/O    - Data sent/received over the network
  • BLOCK I/O  - Data read from or written to disk
  • PIDS       - Number of running programs/processes

📌 Tips:
  • High CPU (>80%)?  Your code might be processing-intensive
  • High Memory (>80%)? Consider optimizing or increasing limits
  • Use 'dcutil stats watch' to see live updates
  • Use 'dcutil stats detailed' to see configured limits
```

### Environment Configuration

Use the `environment` command to manage environment configuration for devcontainers, including exporting the same environment variables used by the devcontainer CLI:

```bash
# Export environment variables that match devcontainer CLI environment
./dcutil environment export-env

# Source the environment variables in your current shell
eval "$(./dcutil environment export-env)"

# Or save to a file and source it
./dcutil environment export-env > env_vars.sh
source env_vars.sh

# Show environment configuration
./dcutil environment info

# Validate environment configuration
./dcutil environment validate
```

#### Export Environment Variables

The `export-env` command generates shell export statements that replicate the environment settings used by the devcontainer CLI, including:

- `DEVCONTAINER_CONFIG` - Path to the devcontainer.json configuration file
- `DEVCONTAINER_WORKSPACE_FOLDER` - Current workspace directory path
- `DEVCONTAINER_CONTAINER_ENGINE` - Container engine being used (docker/podman)
- `DEVCONTAINER_CONTAINER_USER` - Container user setting from configuration
- `DEVCONTAINER_REMOTE_USER` - Remote user setting from configuration
- `DEVCONTAINER_CLI` - Path to the devcontainer CLI executable
- `DEVCONTAINER_CONTAINER_NAME` - Name of the container that would be created

Use this to run Docker/Podman commands with the same environment settings that devcontainer would use.

### Installing AI Agents

Use the `install-agent` command to install AI coding assistants inside your devcontainer. Agents are installed hermetically using portable Python binaries, ensuring no conflicts with system packages:

```bash
# Install opencode
./dcutil install-agent opencode

# Install aider
./dcutil install-agent aider

# Install in specific project
./dcutil install-agent aider /path/to/project
```

Currently supported agents:

- `opencode` - Installs opencode AI assistant
- `aider` - Installs aider-chat AI coding assistant
- `copilot-cli` - Installs GitHub Copilot CLI
- `cody` - Installs Sourcegraph Cody CLI
- `qwen-cli` - Installs Qwen CLI
- `gemini` - Installs Gemini CLI
- `claude-cli` - Installs Claude CLI
- `openai-cli` - Installs OpenAI CLI

## Auto-completion

dcutil has built-in completion that works without any installation or external files.

### Quick Setup (Recommended)

```bash
# Auto-detect shell and setup completion
./setup-completion.sh

# Or specify dcutil path explicitly
./setup-completion.sh /path/to/dcutil
```

### Manual Setup

**Bash:**

```bash
# Add to ~/.bashrc
eval "$(dcutil completion bash)"
```

**Zsh:**

```bash
# Add to ~/.zshrc  
eval "$(dcutil completion zsh)"
```

### One-time Use

```bash
# Temporary completion for current session
eval "$(dcutil completion bash)"  # or zsh
```

### Completion Features

- **Command completion**: Tab-complete all dcutil commands
- **Project path completion**: Automatically detects directories with `.devcontainer/`
- **Init mode completion**: Complete init options (fast, wizard, etc.)
- **Run command completion**: Suggest common container commands (bash, npm, python, etc.)
- **Smart context**: Different completions based on command context
- **No installation required**: Works immediately without external files

## Exit Codes

dcutil includes comprehensive error handling with specific exit codes:

- `0` - Success
- `1` - Invalid arguments or user input
- `2` - Dependencies not found (devcontainer CLI)
- `3` - Container daemon errors (Docker/Podman)
- `4` - Devcontainer operation failures
- `5` - Permission errors
- `6` - Configuration errors

All errors provide clear, actionable messages to help resolve issues quickly.

## Devcontainer Specification

dcutil supports the full Devcontainer Specification, including:

### ✅ Complete Feature Set

- **Orchestration**: Image, Dockerfile, and Docker Compose containers
- **Lifecycle**: onCreateCommand, updateContentCommand, postAttachCommand, waitFor, initializeCommand
- **Configuration**: forwardPorts, portsAttributes, workspaceMount, workspaceFolder
- **Security**: updateRemoteUserUID, overrideCommand, entrypoint control
- **Features**: Complete Devcontainer Features support with caching and inputs
- **Integration**: VS Code extensions, settings, and tool customizations
- **Advanced**: userEnvProbe, hostRequirements, shutdownAction
- **Dynamic Variables**: `${localEnv:VAR}` and `${config:setting}` expansion
- **Schema Validation**: Comprehensive configuration validation
- **Compose Enhancements**: Profiles, scaling, dependencies, restart policies

### Example devcontainer.json

```json
{
    "name": "Full Featured Dev Environment",
    "dockerFile": "Dockerfile",
    "userEnvProbe": "bash",
    "hostRequirements": {
        "cpu": ">=2",
        "memory": "4GB",
        "storage": "10GB",
        "gpu": "optional"
    },
    "shutdownAction": "stop",
    "initializeCommand": "echo 'Initializing development environment...'",
    "features": {
        "ghcr.io/devcontainers/features/git:1": {},
        "ghcr.io/devcontainers/features/docker-in-docker:1": {}
    },
    "forwardPorts": [3000, 8080],
    "portsAttributes": {
        "3000": {"label": "Web App", "onAutoForward": "notify"}
    },
    "workspaceMount": "source=${localWorkspaceFolder},target=/workspaces,type=bind,consistency=cached",
    "customizations": {
        "vscode": {
            "extensions": ["ms-vscode.cpptools"],
            "settings": {"editor.tabSize": 4}
        }
    },
    "dockerComposeFile": ["docker-compose.yml", "docker-compose.dev.yml"],
    "service": "app",
    "runServices": ["database", "redis"],
    "composeProfiles": ["test", "development"],
    "dependsOn": ["database"],
    "restartPolicy": "unless-stopped",
    "inputs": {
        "gitUserName": {
            "type": "string",
            "default": "Developer",
            "description": "Your Git username"
        },
        "gitUserEmail": {
            "type": "string",
            "default": "dev@example.com",
            "description": "Your Git email address"
        }
    },
    "onCreateCommand": "npm install",
    "postAttachCommand": "echo 'Ready for development!'"
}
```

## Requirements

- Bash or Zsh shell
- Docker or Podman container runtime
- Official devcontainer CLI (`npm install -g @devcontainers/cli`)
- jq (optional, for enhanced JSON processing in volume management)
- curl (for fetching templates and features during initialization)

## Testing

Run the test suite to validate functionality:

```bash
# Run all tests
./test.sh

# Test specific components
dcutil schema validate
dcutil features validate
```

## Error Messages & Codes

dcutil provides clear error messages and uses specific exit codes:

- `0`: Success
- `1`: Invalid arguments
- `2`: Missing dependencies
- `3`: Container runtime errors
- `4`: Devcontainer operation failures
- `5`: Permission errors
- `6`: Configuration errors

## Developer Information

For technical details about dcutil's architecture, implementation approach, and contribution guidelines, see [DEVELOPER.md](DEVELOPER.md).

## Testing & CI Integration

### Automated Testing

The project includes comprehensive test suites:

```bash
# Run full compliance test
./test_final_compliance.sh

# Run specific feature tests
dcutil schema validate
dcutil compose config
dcutil features validate
```

### CI Integration

GitHub Actions workflow for automated testing:

```yaml
name: Test dcutil
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y docker.io jq
          npm install -g @devcontainers/cli
      - name: Run tests
        run: ./test.sh
```

## Contributing

Contributions welcome. Please submit issues and pull requests on GitHub. See [DEVELOPER.md](DEVELOPER.md) for technical details and contribution guidelines.
