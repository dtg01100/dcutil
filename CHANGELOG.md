# Changelog

## [1.1.0] - 2025-11-24

### 🚀 Major Refactoring
- **Devcontainer CLI Integration**: Replaced all direct docker/podman exec calls with the official devcontainer CLI
- **Simplified Architecture**: Removed Python fallbacks for JSON processing (jq is now required)
- **Container-First Execution**: All operations now prefer running through the devcontainer CLI for consistency

### 🔧 Technical Improvements
- **Reduced Maintenance**: No longer maintaining low-level docker exec logic
- **Better Compatibility**: Leverages official devcontainer CLI for cross-platform consistency
- **Improved Feature Installation**: Enhanced container detection and in-container execution
- **Cleaner Dependencies**: Removed unnecessary Python dependency from Homebrew formula

### 📦 Package Updates
- **Homebrew Formula**: Updated to remove Python dependency, agents install in containers

## [1.0.8] - 2025-11-23

### Added
- Comprehensive completion files for bash, zsh, and fish shells with support for all commands and options

## [1.0.7] - 2025-11-23

### Added
- Automated Homebrew formula updates via GitHub Actions
- Repository dispatch workflows for cross-repo automation

## [1.0.6] - 2025-11-23

### Added
- Embed version in script for better version detection

## [1.0.5] - 2025-11-23

### Added
- `dcutil version` command to show current version
- Version command support in bash/zsh completion

## [1.0.4] - 2025-11-23

### Changed
- Update help text to use `--help` convention instead of `help`

## [1.0.3] - 2025-11-23

### Fixed
- Fix `dcutil init` exiting immediately in non-interactive environments
- Add check for interactive terminal before running wizard mode

## [1.0.2] - 2025-11-23

### Added
- Initial release with full devcontainer specification compliance

## [Unreleased]

### Added
- **Docker-Native Mode**: Complete container management without devcontainer CLI dependency
- **Interactive Container Entry**: Smart `dcutil enter` command that offers to start stopped containers
- **Advanced Volume Management**: Atomic JSON operations with file locking and race condition prevention
- **Cross-Platform Portability**: Portable bash shebangs (`#!/usr/bin/env bash`) and relative paths
- **Path Resolution Fixes**: Proper handling of symlinks and relative Dockerfile paths

### Fixed
- **Logging Output Contamination**: Fixed stdout/stderr redirection to prevent log messages from interfering with command output
- **Symlink Path Resolution**: Script directory detection now works correctly with symlinked dcutil installations
- **Dockerfile Path Resolution**: Custom Dockerfiles in subdirectories now build correctly
- **Container Entry Detection**: Fixed CONTAINER_NAME initialization in docker_enter function
- **Hermetic Portable Python Installation**: True isolation with portable Python binaries from python-build-standalone
- **Enhanced Security Scanning**: Multi-layered vulnerability detection including Safety, dependency conflict checking, and core package validation
- **Robust Portable Python Downloads**: Hardcoded checksums and fallback to system Python for reliability
- **Platform Detection**: Automatic platform and architecture detection for portable Python
- **Agent Activation Instructions**: Clear guidance for activating installed AI agents
- **Conflict Detection**: Advanced package dependency conflict resolution for AI agents
- **Robust error handling** with structured exit codes (0-6)
- **Input validation** for all commands and arguments
- **Self-contained auto-completion** system (no installation required)
- **Docker daemon connectivity** validation
- **Project path validation** with permission checking
- **Safe command execution** wrapper for devcontainer operations
- **Automatic shell detection** in setup script
- **Completion command** (`dcutil completion bash|zsh`)

### Enhanced
- **Python Setup**: Completely rewritten with portable Python downloads, SHA256 verification, and virtual environment nesting
- **Security**: Advanced vulnerability scanning with multiple tools and extensive package analysis
- **Venv Creation Centralization**: Consolidated duplicated venv creation logic into reusable helpers (`create_system_venv`, `create_portable_venv`)
- **Agent Installation Refactoring**: Streamlined pip agent installation with direct venv python/pip usage and reduced redundancy
- Better error messages with actionable guidance
- Graceful failure handling for non-critical operations
- Improved project directory detection and validation
- Enhanced dependency checking with clear error messages
- More reliable container state checking

### Security
- **Portable Python Isolation**: Agents now run in hermetic environments separate from system Python
- **SHA256 Verification**: All downloads verified with cryptographic checksums
- **Package Vulnerability Scanning**: Automated security checks for installed packages
- **Dependency Conflict Detection**: Prevents incompatible package installations
- **Core Package Validation**: Ensures pip, setuptools, and other core packages are up-to-date
- Permission validation for file and directory access
- Safe path resolution and directory traversal protection
- Input sanitization for user-provided arguments

### Developer Experience
- **Hermetic Environments**: AI agents are truly isolated, preventing conflicts with system or project packages
- **Clear Activation Instructions**: Step-by-step guidance for using installed agents
- **Platform Compatibility**: Automatic detection and fallback for different architectures
- Tab completion for commands, project paths, and container commands
- Smart context-aware suggestions
- One-command setup script for auto-completion
- Consistent colored output with proper error/warning/success indicators

### Files Added
- `setup-completion.sh` - Automatic completion setup script
- `completion.bash` - Standalone bash completion (legacy)
- `_dcutil` - Standalone zsh completion (legacy)

### Breaking Changes
- None - all existing functionality preserved

### Migration
- Existing users can continue using dcutil as before
- Auto-completion is now available without any installation
- Error codes are now standardized for better scripting support
- Python installations are now more secure and isolated
