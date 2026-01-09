#!/usr/bin/env bash

# Helper script to run dialog verification interactively.
# Run with: ./run_verify_dialog.sh

PROJECT_DIR="$(pwd)"
export PROJECT_DIR
DCUTIL_FORCE_DIALOG=1 TERM=xterm-256color ./dcutil verify-dialog
