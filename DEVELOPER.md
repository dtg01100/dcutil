# dcutil Developer Documentation

This document provides technical details about dcutil's architecture and implementation for developers interested in contributing or understanding the codebase.

## Architecture

dcutil is organized as a modular bash script with the following components:

- `core.sh`: Core utilities, validation, and shared functions
- `api_official_cli.sh`: Wrappers for official devcontainer CLI commands
- `docker.sh`: Direct container runtime operations for CLI-unsupported features
- `podman.sh`: Podman-specific backend support
- Various feature modules (volumes, init, etc.) for extended functionality

## Implementation Approach

dcutil acts as a wrapper around the official Microsoft devcontainer CLI, providing enhanced user experience and additional utilities. It delegates all Devcontainer Specification-compliant operations to the official CLI and uses direct Docker/Podman calls only for features not supported by the CLI (e.g., restart, status, logs, list).

## Backend Detection

dcutil automatically detects which container runtime (Docker or Podman) the devcontainer CLI uses by inspecting containers after `devcontainer up`. It caches this information in the `DETECTED_BACKEND` variable and uses the same backend for subsequent direct operations, ensuring consistency.

The detection logic:
1. After `devcontainer up`, check for containers with the label `devcontainer.local_folder=$PROJECT_DIR`
2. If found in Docker, set `DETECTED_BACKEND=docker`
3. If found in Podman, set `DETECTED_BACKEND=podman`
4. For operations without existing containers, fall back to dcutil's `DCUTIL_BACKEND` setting (prefers Docker)

## Error Handling

Uses specific exit codes for different failure modes:
- `0`: Success
- `1`: Invalid arguments or user input
- `2`: Missing dependencies (e.g., devcontainer CLI)
- `3`: Container runtime errors
- `4`: Devcontainer operation failures
- `5`: Permission errors
- `6`: Configuration errors

## Environment Export Implementation

The `environment export-env` command exports environment variables to match those used by the devcontainer CLI for consistency with VSCode's devcontainer functionality:

- Implemented in `lib/environment.sh`
- Uses `devcontainer read-configuration` as the authoritative source for validation
- Generates shell export statements for key environment variables
- Provides easy integration for users who need to run Docker commands with the same environment settings

## Contributing

When modifying backend operations, ensure they respect the `DETECTED_BACKEND` variable to maintain consistency with the devcontainer CLI's runtime choice.

For new features, prefer extending the official CLI integration over adding direct runtime calls unless the CLI genuinely lacks support.

Environment variable handling should leverage the devcontainer CLI as the primary validation and configuration source.