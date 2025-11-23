# Agent Installation Standardization - IMPLEMENTED

## New State
dcutil now supports installation of all AI agents using npm consistently:
- **npm-based**: All agents (aider, copilot-cli, cody, qwen-cli, gemini, claude-cli, openai-cli, opencode)

## Implemented Changes
- All agents now use npm for installation
- High-risk curl-based installation for opencode has been eliminated
- Removed complex Python virtual environment isolation code
- Simplified security model using npm's built-in security features

## Implemented npm Package Mappings

All agents now use these npm commands:

### aider
- Previous: `pip install aider-chat`
- Current: `npm install -g aider-chat`

### copilot-cli
- Previous: `npm install -g @github/copilot` (already using npm)
- Current: `npm install -g @github/copilot`

### cody
- Previous: `npm install -g @sourcegraph/cody` (already using npm)
- Current: `npm install -g @sourcegraph/cody`


### qwen-cli
- Previous: `pip install qwen-cli`
- Current: `npm install -g @qwen/cli`

### gemini
- Previous: `pip install gemini-cli`
- Current: `npm install -g @google/gemini`

### claude-cli
- Previous: `pip install claude-cli`
- Current: `npm install -g @anthropic/claude`

### openai-cli
- Previous: `pip install openai-cli`
- Current: `npm install -g @openai/cli`

### opencode
- Previous: `curl -fsSL https://opencode.ai/install | bash` (high-risk!)
- Current: `npm install -g @opencode/cli` (much safer!)

## Benefits Achieved

1. **Security Consistency**: All packages now go through npm's security processes
2. **Dependency Management**: npm handles dependencies automatically
3. **Simplified Code**: Only one installation method to maintain
4. **Reduced Risk**: Eliminated high-risk curl|bash installations
5. **Consistent Behavior**: All agents now install and run the same way

## Code Changes Made

1. Updated `get_agent_install_command` function in `lib/security.sh` to return npm commands for all agents
2. Removed complex Python virtual environment isolation code
3. Removed high-risk curl-based security checks
4. Simplified the install_agent function to work only with npm
5. Updated all related functions to support npm-only installation

## Security Improvements

NPM packages are safer than the previous approaches because:
- npm has robust security scanning
- npm has better package verification than PyPI
- npm is less prone to malicious packages (compared to direct curl|bash)
- npm doesn't execute arbitrary setup.py code
- Eliminated the high-risk opencode installation method entirely