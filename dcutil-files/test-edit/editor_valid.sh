#!/usr/bin/env bash
# Always write valid JSON
cat > "$1" <<JD
{
  "name": "test-edit-edited",
  "image": "mcr.microsoft.com/vscode/devcontainers/base:0-focal",
  "note": "edited-by-editor"
}
JD
exit 0
