#!/usr/bin/env bash
#
# dcutil - Development Container Utility
# https://github.com/dtg01100/dcutil
#
# Help and usage functions
#

# Print compose command usage
print_compose_usage() {
    cat << 'EOF'
Usage: dcutil compose <command> [options]

Docker Compose commands for multi-container devenvironments:

Commands:
  up       Start the Docker Compose environment
  down     Stop the Docker Compose environment
  restart  Restart the Docker Compose environment
  logs     Show logs from the Docker Compose services
  exec     Execute a command in the main service container
  status   Show status of Docker Compose services
  build    Build Docker Compose images
  clean    Clean up Docker Compose environment (stop and remove)
  scale    Scale services to specified replica count
  config   Show Docker Compose configuration

Examples:
  dcutil compose up
  dcutil compose logs
  dcutil compose exec bash
  dcutil compose down
  dcutil compose build

Requires a devcontainer.json with dockerComposeFile and service properties.
EOF
}

# Print features command usage
print_features_usage() {
    cat << 'EOF'
Usage: dcutil features <command> [options]

Dev container features management:

Commands:
  info     Show information about available features
  add      Add a feature to devcontainer.json
  remove   Remove a feature from devcontainer.json
  list     List currently installed features
  update   Update feature versions
  test     Test feature installation
  install  Install features for current environment
  clean    Clean feature cache and temporary files

Examples:
  dcutil features info
  dcutil features add node
  dcutil features remove git
  dcutil features list
  dcutil features install

Features are installed automatically when running 'dcutil up'.
EOF
}

# Print advanced command usage
print_advanced_usage() {
    cat << 'EOF'
Usage: dcutil advanced <command> [options]

Advanced dev container operations:

Commands:
  config    Show complete dev container configuration
  env       Show environment variables
  mounts    Show volume mounts and bind mounts
  ports     Show port mappings and forwarding
  secrets   Show secrets and environment files
  network   Show network configuration
  security  Show security settings and capabilities

Examples:
  dcutil advanced config
  dcutil advanced env
  dcutil advanced mounts
  dcutil advanced ports

Use these commands for debugging and troubleshooting.
EOF
}

# Print integration command usage
print_integration_usage() {
    cat << 'EOF'
Usage: dcutil integration <command> [options]

Dev container integration and customization:

Commands:
  vscode     Configure VS Code settings and extensions
  dotfiles   Configure dotfiles and shell customizations
  git        Configure git settings and hooks
  ssh        Configure SSH keys and agent forwarding
  mounts     Configure additional volume mounts
  env        Configure environment variables
  lifecycle  Configure lifecycle scripts
  templates  Apply dev container templates

Examples:
  dcutil integration vscode
  dcutil integration dotfiles
  dcutil integration ssh
  dcutil integration lifecycle

Integrations are applied during container startup.
EOF
}

# Print merging command usage
print_merging_usage() {
    cat << 'EOF'
Usage: dcutil merging <command> [options]

Configuration merging and conflict resolution:

Commands:
  preview   Preview merged configuration
  apply     Apply merged configuration to devcontainer.json
  resolve   Resolve merge conflicts interactively
  diff      Show differences between configurations
  backup    Create backup of current configuration

Examples:
  dcutil merging preview
  dcutil merging apply
  dcutil merging resolve
  dcutil merging diff

Merging combines base templates with local customizations.
EOF
}

# Print userprobe command usage
print_userprobe_usage() {
    cat << 'EOF'
Usage: dcutil userprobe <command> [options]

User environment probing and configuration:

Commands:
  detect    Detect user shell and environment
  configure Configure shell-specific settings
  test      Test shell configuration
  reset     Reset to default configuration

Examples:
  dcutil userprobe detect
  dcutil userprobe configure bash
  dcutil userprobe test
  dcutil userprobe reset

Automatically detects and configures user environment.
EOF
}

# Print hostrequirements command usage
print_hostrequirements_usage() {
    cat << 'EOF'
Usage: dcutil hostrequirements <command> [options]

Host system requirements checking:

Commands:
  check     Check all host requirements
  docker    Check Docker installation and version
  compose   Check Docker Compose availability
  disk      Check available disk space
  memory    Check available memory
  network   Check network connectivity

Examples:
  dcutil hostrequirements check
  dcutil hostrequirements docker
  dcutil hostrequirements disk

Ensures host system meets dev container requirements.
EOF
}

# Print shutdown command usage
print_shutdown_usage() {
    cat << 'EOF'
Usage: dcutil shutdown [options]

Shutdown dev container environment:

Options:
  --force   Force shutdown without confirmation
  --clean   Clean up containers, volumes, and networks
  --backup  Create backup before shutdown

Examples:
  dcutil shutdown
  dcutil shutdown --force
  dcutil shutdown --clean

Safely stops and optionally cleans up the environment.
EOF
}

# Print lifecycle command usage
print_lifecycle_usage() {
    cat << 'EOF'
Usage: dcutil lifecycle <command> [options]

Container lifecycle management:

Commands:
  initialize    Run initializeCommand
  oncreate      Run onCreateCommand
  update        Run updateContentCommand
  postcreate    Run postCreateCommand
  poststart     Run postStartCommand
  postattach    Run postAttachCommand

Examples:
  dcutil lifecycle initialize
  dcutil lifecycle oncreate
  dcutil lifecycle poststart

Manually trigger lifecycle hooks for testing.
EOF
}