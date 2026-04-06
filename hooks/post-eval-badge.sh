#!/usr/bin/env bash
# post-eval-badge.sh — Auto-update README badge after harness evaluation
# Triggered on Stop event. Checks if .harness-eval/latest.json was recently updated.

set -euo pipefail

PROJECT_ROOT="$(pwd)"
LATEST="$PROJECT_ROOT/.harness-eval/latest.json"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BADGE_SCRIPT="$PLUGIN_ROOT/scripts/badge.sh"

# Only run if latest.json exists and was modified in the last 5 minutes
if [[ -f "$LATEST" ]] && [[ -f "$BADGE_SCRIPT" ]]; then
  # Cross-platform stat: try GNU stat first, then BSD stat
  LATEST_MOD=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  AGE=$(( NOW - LATEST_MOD ))

  if [[ $AGE -lt 300 ]]; then
    bash "$BADGE_SCRIPT" "$PROJECT_ROOT" > /dev/null 2>&1 || true
  fi
fi
