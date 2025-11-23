# dcutil - Complete Devcontainer Specification Implementation

A comprehensive devcontainer utility script providing **100% Devcontainer Specification compliance** with advanced features for managing development containers. Includes robust error handling, intelligent auto-completion, and support for all specification features.

## Features

### ✅ 100% Devcontainer Specification Compliant

#### Core Features
- **Complete orchestration support**: Image, Dockerfile, and Docker Compose containers
- **Advanced lifecycle management**: onCreateCommand, updateContentCommand, postAttachCommand
- **Devcontainer Features**: Full feature installation, caching, and management
- **Security features**: updateRemoteUserUID, overrideCommand, entrypoint control
- **Port management**: forwardPorts, portsAttributes with rich configuration
- **Workspace mounting**: Advanced workspaceMount with consistency options

#### Extended Features
- **userEnvProbe**: Shell-based environment variable extraction with dynamic expansion
- **hostRequirements**: System requirements validation (CPU, memory, storage, GPU)
- **shutdownAction**: Configurable container shutdown behavior
- **Tool integration**: VS Code extensions, settings, and customizations
- **Image metadata merging**: Combine image labels with devcontainer.json
- **Dynamic variables**: `${localEnv:VAR}` and `${config:setting}` syntax support

#### User Experience
- **Intelligent auto-completion** for bash and zsh (no installation required)
- **Robust error handling** with specific exit codes and actionable messages
- **Hermetic AI agent installation** with portable Python binaries
- **Comprehensive validation** for all configurations and inputs
- **Colored output** for better visibility and debugging
- **Automatic project detection** with multiple fallback strategies
- **Interactive container entry** with smart startup prompts
- **Cross-platform portability** with env-based shebangs and relative paths

#### Container Backend Support
- **Docker Backend**: Full Docker CLI compatibility with all features
- **Podman Backend**: Complete Podman support with rootless containers
- **Docker-Native Mode**: Direct Docker API usage without devcontainer CLI dependency
- **Auto-Detection**: Automatically detects and uses available container runtime
- **Backend Switching**: Runtime backend selection via environment variables
- **Enterprise Ready**: Rootless support, enhanced security, OCI compliance

## Commands

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

### Container Backend Management
- `status` - Show container status and backend information
- Environment variable `DCUTIL_BACKEND` - Control container backend (docker, podman, auto)

### Orchestration & Utilities
- `compose <cmd>` - Docker Compose environments (up, down, restart, logs, exec, status, scale, config)
- `volumes <cmd>` - Volume management (list, add, remove, mount, unmount, status, backup, restore)
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

dcutil supports both Docker and Podman as container backends:

```bash
# Auto-detect backend (default)
./dcutil up

# Force Docker backend
DCUTIL_BACKEND=docker ./dcutil up

# Force Podman backend
DCUTIL_BACKEND=podman ./dcutil up

# Check current backend
./dcutil status
```

#### Backend Features

**Docker Backend:**
- Full Docker CLI compatibility
- All existing workflows preserved
- Traditional daemon-based architecture

**Podman Backend:**
- Rootless container support
- No persistent daemon required
- Enhanced security model
- Direct OCI runtime integration
- Kubernetes YAML support (`podman play kube`)
- Enterprise-grade capabilities

**Auto-Detection:**
- Prefers Podman if available
- Falls back to Docker automatically
- Seamless backend switching
- Consistent command interface across backends

### Docker-Native Mode

dcutil supports a Docker-native mode that operates without requiring the devcontainer CLI, providing enhanced performance and reliability:

```bash
# Use Docker-native mode (no devcontainer CLI required)
./dcutil up

# The script automatically detects when devcontainer CLI is unavailable
# and switches to Docker-native mode seamlessly
```

#### Docker-Native Features
- **No External Dependencies**: Works with just Docker/Podman installed
- **Enhanced Performance**: Direct API calls eliminate CLI overhead
- **Robust Container Management**: Advanced naming, collision prevention, and cleanup
- **Environment Sanitization**: Proper handling of environment variables for Docker compatibility
- **Lifecycle Command Execution**: Full support for onCreateCommand, updateContentCommand, postAttachCommand
- **Tool Integration**: VS Code extensions, settings, and customizations
- **Volume Management**: Atomic JSON operations with file locking for concurrent access
- **Race Condition Prevention**: File locking and retry logic for multi-process operations

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

#### Advanced Features
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

## Error Handling

dcutil includes comprehensive error handling with specific exit codes:

- `0` - Success
- `1` - Invalid arguments or user input
- `2` - Dependencies not found (devcontainer CLI)
- `3` - Container daemon errors (Docker/Podman)
- `4` - Devcontainer operation failures
- `5` - Permission errors
- `6` - Configuration errors

All errors provide clear, actionable messages to help resolve issues quickly.

## Devcontainer Specification Compliance

dcutil implements **100% of the Devcontainer Specification** including:

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

- **Container Runtime**: Docker or Podman
- **Devcontainer CLI**: Optional - `npm install -g @devcontainers/cli` (only needed for legacy devcontainer CLI mode)
- **Bash or Zsh**: For auto-completion support (optional)
- **jq**: For JSON processing and volume management (optional, enhances some features)

**Note**: dcutil works out-of-the-box with just Docker/Podman installed. No additional dependencies required for core functionality.

## Testing & Validation

Run the comprehensive test suite to validate all features:

```bash
# Test all features
./test_final_compliance.sh

# Test specific modules
dcutil userprobe validate
dcutil hostrequirements validate
dcutil shutdown validate

# Test configuration parsing
dcutil merging show
dcutil advanced info
```

## Architecture

### Modular Design
- **Core modules**: Fundamental utilities and validation
- **Feature modules**: Specialized functionality (userprobe, hostrequirements, etc.)
- **Integration modules**: Tool and IDE integration
- **Orchestration modules**: Docker Compose and advanced container management

### Error Handling
Comprehensive error handling with specific exit codes:
- `0` - Success
- `1` - Invalid arguments
- `2` - Missing dependencies
- `3` - Docker daemon errors
- `4` - Container operation failures
- `5` - Permission errors
- `6` - Configuration errors

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
A GitHub Actions workflow is ready for automated testing:

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
        run: |
          ./test_final_compliance.sh
```

## Contributing

This implementation provides a complete, production-ready Devcontainer solution. For issues or feature requests, please use the GitHub issue tracker.