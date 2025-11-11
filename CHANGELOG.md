# Changelog

## [Unreleased]

### Added
- **Robust error handling** with structured exit codes (0-6)
- **Input validation** for all commands and arguments
- **Self-contained auto-completion** system (no installation required)
- **Docker daemon connectivity** validation
- **Project path validation** with permission checking
- **Safe command execution** wrapper for devcontainer operations
- **Automatic shell detection** in setup script
- **Completion command** (`dcutil completion bash|zsh`)

### Enhanced
- Better error messages with actionable guidance
- Graceful failure handling for non-critical operations
- Improved project directory detection and validation
- Enhanced dependency checking with clear error messages
- More reliable container state checking

### Security
- Permission validation for file and directory access
- Safe path resolution and directory traversal protection
- Input sanitization for user-provided arguments

### Developer Experience
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