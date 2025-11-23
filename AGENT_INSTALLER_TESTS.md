# Agent Installer Testing Suite

This directory contains multiple test scripts for thoroughly testing the agent installer functionality in dcutil. Each script focuses on different aspects of agent installation and security.

## Test Scripts

### 1. `test_all_agent_installers.sh`
- Tests installation of all supported AI agents
- Supports: aider, copilot-cli, cody, qwen-cli, gemini, claude-cli, openai-cli, opencode
- Each agent is tested in a clean environment
- Handles high-risk agents like opencode appropriately

### 2. `test_advanced_agent_installers.sh`
- Comprehensive testing for installation scenarios
- Tests virtual environment creation and isolation
- Tests configuration mounting functionality
- Includes security scanning tests
- Tests idempotency (multiple installations)
- Handles edge cases and error conditions

### 3. `test_security_agent_installers.sh`
- Security-focused testing
- Specifically tests high-risk agents like opencode
- Tests security prompts and user confirmations
- Validates virtual environment isolation
- Tests dependency conflict detection
- Tests portable Python environment handling

### 4. `test_opencode_installers.sh`
- Specialized testing for OpenCode agent
- Tests current curl-based installation method
- Documents potential npm-based implementation
- Highlights security differences between methods

## Running the Tests

To run all tests:

```bash
# Run basic agent installer tests
./test_all_agent_installers.sh

# Run advanced scenario tests
./test_advanced_agent_installers.sh

# Run security-focused tests
./test_security_agent_installers.sh
```

## Supported Agents

The dcutil agent installer currently supports the following agents (all using npm for installation):

- **aider**: AI coding assistant (now using npm)
- **copilot-cli**: GitHub Copilot CLI (npm-based)
- **cody**: Sourcegraph Cody (npm-based)
- **qwen-cli**: Qwen CLI (now using npm)
- **gemini**: Google Gemini CLI (now using npm)
- **claude-cli**: Claude CLI (now using npm)
- **openai-cli**: OpenAI CLI (now using npm)
- **opencode**: OpenCode (now using npm - no longer high-risk!)

## Security Features Tested

- Virtual environment isolation for Python-based agents
- Security prompts for high-risk agents
- Dependency vulnerability scanning
- Configuration file mounting with user consent
- Safe installation in containerized environment