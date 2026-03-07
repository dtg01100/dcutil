#!/usr/bin/env bash
# Quick audit to find interactive prompts and whether they're guarded by non-interactive flags
set -euo pipefail

printf "🔎 Audit: Detect interactive prompts and non-interactive guards\n\n"

# Patterns that are considered interactive prompts
prompt_patterns=('read -r -p' 'read -p' 'read -r ' 'dialog ' 'whiptail ' 'select ' 'read ') 

# Search for files containing prompts
echo "Files containing interactive prompts:"
for p in "${prompt_patterns[@]}"; do
  grep -nR --line-number --exclude-dir=.git --exclude-dir=__pycache__ "$p" . || true
done | sort -u

echo "\nChecking whether prompt sites are guarded by DCUTIL_NONINTERACTIVE or DCUTIL_DISABLE_DIALOG or CI or TTY checks:\n"

# For each file with a prompt, inspect surrounding context to see if it's guarded
grep -R --line-number --exclude-dir=.git -E "read -r -p|read -p|read -r |dialog |whiptail |select |read " . | while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  echo "\n$file:$lineno"
  sed -n "$((lineno-6)),$((lineno+2))p" "$file"
  # Check in the preceding 12 lines for guards
  guard=$(sed -n "$((lineno-12)),$((lineno-1))p" "$file" | grep -E "DCUTIL_NONINTERACTIVE|DCUTIL_DISABLE_DIALOG|\bCI=|\[ -t 0 \]|\[ -t 1 \]" || true)
  if [ -n "$guard" ]; then
    echo "--> Guard found in nearby lines:"; echo "$guard" | sed 's/^/    /'
  else
    echo "--> WARNING: No obvious non-interactive guard near this prompt"
  fi
done

# Check files that test only DCUTIL_NONINTERACTIVE but not DCUTIL_DISABLE_DIALOG
echo "\nFiles that check for DCUTIL_NONINTERACTIVE but not DCUTIL_DISABLE_DIALOG (possible missed legacy flag):"
grep -R --line-number --exclude-dir=.git "DCUTIL_NONINTERACTIVE" . | while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  if ! grep -q "DCUTIL_DISABLE_DIALOG" "$file"; then
    echo "  $file"
  fi
done || true

# Summary
echo "\nAudit complete. Recommend adding DCUTIL_DISABLE_DIALOG checks where only DCUTIL_NONINTERACTIVE is checked, or normalizing env var usage to a helper (e.g., is_interactive())." 
