#!/usr/bin/env bash
# post-eval-badge.sh — Auto-update README badge after harness evaluation.
# Registered on the Stop event, which fires each time Claude finishes a
# response (not only when the session ends).
#
# OPT-IN ONLY: rewriting a user's README.md is disabled by default. This hook
# runs at the end of every response in every project the plugin is installed
# in, so it must never modify files without explicit consent. It updates
# README.md (via badge.sh) ONLY when the user has opted in, either by:
#   - exporting HARNESS_EVAL_AUTO_BADGE=1, or
#   - setting {"autoBadge": true} in <project>/.harness-eval/config.json
#     (a config.json tracked by git does not count: the repository cannot
#     opt in on the user's behalf)
#
# Each saved evaluation is handled once. The hook records latest.json's mtime
# in .harness-eval/.badge-seen and acts only when latest.json is newer than the
# recorded value and less than a day old, however long the evaluation took to
# finish its response. Without opt-in it writes a one-line note to stderr,
# which Claude Code does not show for a hook that exits 0, and changes nothing
# but that marker.
#
# The repository must not be able to drive this hook. It does nothing when
# .harness-eval/, latest.json, config.json, or .badge-seen is a symlink, or
# when latest.json is tracked by git: such files did not come from an
# evaluation run in this checkout. A symlinked README.md is refused by
# badge.sh, and that failure is reported.

set -euo pipefail

PROJECT_ROOT="$(pwd)"
HE_DIR="$PROJECT_ROOT/.harness-eval"
LATEST="$HE_DIR/latest.json"
CONFIG="$HE_DIR/config.json"
SEEN="$HE_DIR/.badge-seen"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BADGE_SCRIPT="$PLUGIN_ROOT/scripts/badge.sh"

# Nothing to do unless an evaluation exists and badge.sh is available.
[[ -f "$LATEST" && -f "$BADGE_SCRIPT" ]] || exit 0

# Links planted by the repository: never follow them.
for p in "$HE_DIR" "$LATEST" "$CONFIG" "$SEEN"; do
  if [[ -L "$p" ]]; then
    exit 0
  fi
done
if [[ -e "$SEEN" && ! -f "$SEEN" ]]; then
  exit 0
fi

# Act once per saved evaluation. Cross-platform stat: GNU first, then BSD.
LATEST_MOD=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null || echo 0)
[[ "$LATEST_MOD" =~ ^[0-9]{1,19}$ ]] || exit 0
LATEST_MOD=$((10#$LATEST_MOD))
SEEN_MOD=$(cat "$SEEN" 2>/dev/null || echo 0)
[[ "$SEEN_MOD" =~ ^[0-9]{1,19}$ ]] || SEEN_MOD=0
SEEN_MOD=$((10#$SEEN_MOD))
[[ $LATEST_MOD -gt $SEEN_MOD ]] || exit 0

# An evaluation older than a day is not a new one; leave it alone.
AGE=$(( $(date +%s) - LATEST_MOD ))
[[ $AGE -lt 86400 ]] || exit 0

# A latest.json that git tracks came from the repository, not from a save.
if git -C "$PROJECT_ROOT" ls-files --error-unmatch .harness-eval/latest.json >/dev/null 2>&1; then
  exit 0
fi

# Mark this evaluation as handled before acting, so the note or the badge
# update happens once. Write a temp file and rename it, which replaces rather
# than follows anything placed at the marker path.
if tmp="$(mktemp "$HE_DIR/.badge-seen.XXXXXX" 2>/dev/null)"; then
  if ! { printf '%s\n' "$LATEST_MOD" > "$tmp" && mv -f "$tmp" "$SEEN"; }; then
    rm -f "$tmp"
  fi
fi

# --- Determine opt-in status ------------------------------------------------
config_is_tracked() {
  git -C "$PROJECT_ROOT" ls-files --error-unmatch .harness-eval/config.json >/dev/null 2>&1
}

auto_badge=0
if [[ "${HARNESS_EVAL_AUTO_BADGE:-0}" == "1" ]]; then
  auto_badge=1
elif [[ -f "$CONFIG" ]] && command -v jq &>/dev/null && ! config_is_tracked; then
  if [[ "$(jq -r '.autoBadge // false' "$CONFIG" 2>/dev/null)" == "true" ]]; then
    auto_badge=1
  fi
fi

if [[ $auto_badge -ne 1 ]]; then
  echo "[post-eval-badge] New evaluation detected, but README auto-badge is disabled (no consent). To update README.md automatically set HARNESS_EVAL_AUTO_BADGE=1 or add {\"autoBadge\": true} to .harness-eval/config.json, or run: bash \"$BADGE_SCRIPT\" \"$PROJECT_ROOT\"" >&2
  exit 0
fi

# badge.sh needs jq; without it, skip quietly as for any missing dependency.
if ! command -v jq &>/dev/null; then
  echo "[post-eval-badge] jq is not installed; README badge not updated." >&2
  exit 0
fi

# Opt-in confirmed: update the badge. Do not swallow stderr, and exit 1 on
# failure: Claude Code shows a Stop hook's stderr to the user only for exit
# codes other than 0 and 2, and a failed update (e.g. a malformed badge block
# or a symlinked README) must stay visible. Keep stdout quiet.
if bash "$BADGE_SCRIPT" "$PROJECT_ROOT" >/dev/null; then
  echo "[post-eval-badge] Updated $PROJECT_ROOT/README.md harness-eval badge." >&2
else
  status=$?
  echo "[post-eval-badge] badge.sh failed to update README.md (exit $status)." >&2
  exit 1
fi
