# dcutil

A general purpose devcontainer utility script that provides convenient commands for managing development containers with robust error handling and intelligent auto-completion.

## Features

- Start, stop, and manage devcontainers with simple commands
- Automatic project directory detection with validation
- Colored output for better visibility
- Support for running commands inside containers
- **Hermetic AI agent installation** with portable Python binaries
- Support for installing AI agents inside devcontainers
- **Robust error handling** with proper exit codes
- **Self-contained auto-completion** for bash and zsh
- **Input validation** for all commands and arguments
- **Docker daemon connectivity** checking

## Commands

- `up` - Start the devcontainer
- `down` - Stop the devcontainer
- `restart` - Restart the devcontainer
- `enter` - Enter the container shell
- `build` - Build the devcontainer image
- `clean` - Remove the devcontainer and clean up
- `status` - Show container status
- `logs` - Show container logs
- `list` - List running devcontainers
- `run <cmd>` - Run a command in the container
- `init` - Initialize a devcontainer (fast or wizard mode)
- `install-agent <agent>` - Install AI agent inside the devcontainer
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
- `tabnine` - Installs Tabnine CLI
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
- `3` - Docker daemon errors
- `4` - Devcontainer operation failures
- `5` - Permission errors
- `6` - Configuration errors

All errors provide clear, actionable messages to help resolve issues quickly.

## Requirements

- Devcontainer CLI (`npm install -g @devcontainers/cli`)
- Docker
- Bash or Zsh shell (for auto-completion)