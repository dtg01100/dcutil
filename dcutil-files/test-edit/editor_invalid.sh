#!/usr/bin/env bash
# Write invalid JSON (for non-interactive invalid test)
printf '{ "name": "broken", "image": }' > "$1"
exit 0
