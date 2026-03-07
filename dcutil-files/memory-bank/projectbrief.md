# Project Brief

**Project:** dcutil
**Purpose:** Provide a beginner-friendly CLI wrapper around the official Devcontainer CLI, simplifying creation and management of development containers on Docker/Podman with clear guidance and automation.

**Scope:**
- Offer user-friendly commands (up/down/status/enter/build/etc.) with guided wizard for new devcontainers.
- Manage templates, features, volume operations, and environment export helpers.
- Maintain compatibility with Devcontainer Specification while abstracting backend (Docker/Podman) details.

**Success Criteria:**
- Commands work reliably across Docker and Podman.
- Clear error messages with actionable guidance.
- Tests (expect scripts + bash helpers) remain green.
- Minimal user-required container knowledge; workflows feel guided and safe.
