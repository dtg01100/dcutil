# Product Context

**Why:** Developers want isolated, repeatable dev environments without learning container internals. dcutil makes devcontainer usage approachable with friendly UX.

**Problems it solves:**
- Hides Docker/Podman complexity; auto-detects backend.
- Provides wizards for devcontainer setup, template/feature selection, and volume management.
- Supplies clear remediation tips and exit codes.

**How it should work:**
- Simple commands (`dcutil up`, `dcutil init`, `dcutil status`, `dcutil volumes ...`, `dcutil features ...`).
- Interactive menu when run without args; dialog UI when available, text fallback otherwise.
- Error messages include next steps and actionable commands.

**User experience goals:**
- Beginner-friendly guidance and smart suggestions on typos.
- Works out-of-the-box on Linux/macOS with minimal prerequisites.
- Integrates cleanly with VS Code / Devcontainer workflows.
