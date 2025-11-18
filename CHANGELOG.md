# Changelog

## [Unreleased]

### Added
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
