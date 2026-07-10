#!/usr/bin/env bash
# post-eval-badge.sh — Auto-update README badge after harness evaluation.
# Triggered on the Stop event.
#
# OPT-IN ONLY: rewriting a user's README.md is disabled by default. This hook
# runs on every session Stop for every project the plugin is installed in, so
# it must never modify files without explicit consent. It updates README.md
# (via badge.sh) ONLY when the user has opted in, either by:
#   - exporting HARNESS_EVAL_AUTO_BADGE=1, or
#   - setting {"autoBadge": true} in <project>/.harness-eval/config.json
# Without opt-in it prints a one-line notice to stderr (only when a fresh
# evaluation is present) and exits 0 without touching any file.

set -euo pipefail

PROJECT_ROOT="$(pwd)"
LATEST="$PROJECT_ROOT/.harness-eval/latest.json"
CONFIG="$PROJECT_ROOT/.harness-eval/config.json"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BADGE_SCRIPT="$PLUGIN_ROOT/scripts/badge.sh"

# Nothing to do unless a recent evaluation exists and badge.sh is available.
[[ -f "$LATEST" && -f "$BADGE_SCRIPT" ]] || exit 0

# Only consider evaluations refreshed in the last 5 minutes.
# Cross-platform stat: try GNU stat first, then BSD stat.
LATEST_MOD=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null || echo 0)
NOW=$(date +%s)
AGE=$(( NOW - LATEST_MOD ))
[[ $AGE -lt 300 ]] || exit 0

# --- Determine opt-in status ------------------------------------------------
auto_badge=0
if [[ "${HARNESS_EVAL_AUTO_BADGE:-0}" == "1" ]]; then
  auto_badge=1
elif [[ -f "$CONFIG" ]] && command -v jq &>/dev/null; then
  if [[ "$(jq -r '.autoBadge // false' "$CONFIG" 2>/dev/null)" == "true" ]]; then
    auto_badge=1
  fi
fi

if [[ $auto_badge -ne 1 ]]; then
  echo "[post-eval-badge] Fresh evaluation detected, but README auto-badge is disabled (no consent). To update README.md automatically set HARNESS_EVAL_AUTO_BADGE=1 or add {\"autoBadge\": true} to .harness-eval/config.json, or run: bash \"$BADGE_SCRIPT\" \"$PROJECT_ROOT\"" >&2
  exit 0
fi

# Opt-in confirmed: update the badge. Do not swallow stderr — a failure (e.g.
# badge.sh data-loss or parse errors) must remain visible. Keep stdout quiet.
if bash "$BADGE_SCRIPT" "$PROJECT_ROOT" >/dev/null; then
  echo "[post-eval-badge] Updated $PROJECT_ROOT/README.md harness-eval badge." >&2
else
  status=$?
  echo "[post-eval-badge] badge.sh failed to update README.md (exit $status)." >&2
fi
