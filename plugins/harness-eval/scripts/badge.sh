#!/usr/bin/env bash
# badge.sh — README badge generator for harness-eval
# Usage: badge.sh <target-project-root>
# Output: JSON to stdout, logs to stderr
# Exit codes: 0 = success, 1 = no latest.json found, 2 = script error
# A README.md that is a symlink is refused (exit 2) and left unchanged.

set -euo pipefail

###############################################################################
# Dependency checks
###############################################################################
check_dependencies() {
  if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo '{"error":"Bash 4.0+ is required"}' >&2
    exit 2
  fi
  if ! command -v jq &>/dev/null; then
    echo '{"error":"jq is required but not installed"}' >&2
    exit 2
  fi
}

###############################################################################
# Globals
###############################################################################
TARGET=""

###############################################################################
# Logging helpers (all go to stderr)
###############################################################################
log() { echo "[badge] $*" >&2; }
# Build the error JSON with jq so messages containing quotes/backslashes
# (e.g. target paths) stay valid JSON for machine consumers on stderr.
emit_error() { jq -n --arg msg "$*" '{error:$msg}' >&2; }

###############################################################################
# Argument parsing
###############################################################################
parse_args() {
  if [[ $# -eq 0 ]]; then
    emit_error "Usage: badge.sh <target-project-root>"
    exit 2
  fi

  local original_target="$1"
  TARGET="$(cd "$original_target" 2>/dev/null && pwd)" || {
    emit_error "Target directory does not exist: $original_target"
    exit 2
  }

  if [[ ! -d "$TARGET" ]]; then
    emit_error "Target is not a directory: $original_target"
    exit 2
  fi
}

###############################################################################
# Map score to color
###############################################################################
score_to_color() {
  local score="$1"
  # Pass score as a data variable (awk -v) rather than interpolating it into
  # the program text, so a crafted latest.json cannot inject awk/shell code.
  awk -v s="$score" 'BEGIN {
    if (s >= 9.0) print "brightgreen"
    else if (s >= 8.0) print "green"
    else if (s >= 7.0) print "yellow"
    else if (s >= 6.0) print "orange"
    else print "red"
  }'
}

###############################################################################
# URL-encode a string for shields.io badge labels
# Only escapes characters that break shields.io badge URLs
###############################################################################
url_encode_badge() {
  local input="$1"
  # Replace / with %2F and space with %20
  local encoded="${input//\//%2F}"
  encoded="${encoded// /%20}"
  echo "$encoded"
}

###############################################################################
# Escape grade for shields.io
# shields.io uses - as separator, so a single dash in value must be doubled
###############################################################################
escape_grade_for_badge() {
  local grade="$1"
  # Replace each - with -- so shields.io treats it as a literal dash
  echo "${grade//-/--}"
}

###############################################################################
# Build badge markdown block
###############################################################################
build_badge_block() {
  local score="$1"
  local grade="$2"
  local color="$3"
  local date="$4"

  local encoded_score
  encoded_score="$(url_encode_badge "${score}%2F10")"
  # score already contains literal /, encode it for the URL
  # Re-encode: score is e.g. "8.5", we want "8.5%2F10"
  encoded_score="$(url_encode_badge "${score}")/10"
  # Actually shields.io needs the / replaced with %2F in the path segment
  encoded_score="${score}%2F10"

  local escaped_grade
  escaped_grade="$(escape_grade_for_badge "$grade")"

  # Encode date: replace - with -- for shields.io path safety (dates use - as separator)
  # shields.io badge URL format: /badge/label-value-color
  # Dashes in value need to be doubled, spaces become _
  local encoded_date="${date//-/--}"

  cat <<EOF
<!-- harness-eval-badge:start -->
![Harness Score](https://img.shields.io/badge/harness-${encoded_score}-${color})
![Harness Grade](https://img.shields.io/badge/grade-${escaped_grade}-${color})
![Last Eval](https://img.shields.io/badge/eval-${encoded_date}-blue)
<!-- harness-eval-badge:end -->
EOF
}

###############################################################################
# Update README.md in target project
###############################################################################
update_readme() {
  local badge_block="$1"
  local readme="$TARGET/README.md"

  # A repository can commit README.md as a symlink to a file outside the
  # project (or a dangling one). Writing through it would modify or create
  # that file, so refuse and leave the link and its target alone.
  if [[ -L "$readme" ]]; then
    emit_error "README.md is a symlink; refusing to modify it (update the badge in the link target by hand)"
    exit 2
  fi
  if [[ -e "$readme" && ! -f "$readme" ]]; then
    emit_error "README.md is not a regular file; leaving it unchanged"
    exit 2
  fi

  if [[ ! -f "$readme" ]]; then
    log "README.md not found, creating new one"
    printf '%s\n' "$badge_block" > "$readme"
    return
  fi

  local start_marker="<!-- harness-eval-badge:start -->"
  local end_marker="<!-- harness-eval-badge:end -->"

  local has_start=false has_end=false
  grep -qF "$start_marker" "$readme" && has_start=true
  grep -qF "$end_marker" "$readme" && has_end=true

  if [[ "$has_start" == true && "$has_end" == true ]]; then
    log "Markers found, replacing badge block"
    # Replace content between markers (inclusive). The END guard exits 3 if
    # the block never closed (start seen but end never reached), so a
    # malformed README is preserved rather than truncated.
    # The rewrite goes to a fresh mktemp file: a fixed name such as
    # README.md.tmp could itself be a committed symlink that `>` would follow.
    local tmp mode awk_rc=0
    tmp="$(mktemp "$TARGET/.README.md.XXXXXX")" || {
      emit_error "Cannot create a temporary file in $TARGET; leaving README.md unchanged"
      exit 2
    }
    # Keep README.md's mode (mktemp creates 0600). GNU stat, then BSD stat.
    mode="$(stat -c %a "$readme" 2>/dev/null || stat -f %Lp "$readme" 2>/dev/null || true)"
    if [[ "$mode" =~ ^[0-7]{3,4}$ ]]; then
      chmod "$mode" "$tmp" 2>/dev/null || true
    fi
    # The block reaches awk through the environment, not `awk -v`: BSD awk
    # (macOS /usr/bin/awk) rejects a -v value that contains a newline, and
    # ENVIRON also takes the text as is, without -v's escape processing.
    NEW_BLOCK="$badge_block" awk '
      /<!-- harness-eval-badge:start -->/ { in_block=1; print ENVIRON["NEW_BLOCK"]; next }
      /<!-- harness-eval-badge:end -->/   { in_block=0; next }
      !in_block { print }
      END { if (in_block == 1) exit 3 }
    ' "$readme" > "$tmp" || awk_rc=$?
    if [[ "$awk_rc" -ne 0 ]]; then
      rm -f "$tmp"
      # Only exit 3 means the README itself is at fault. Any other status is
      # awk (or the write to the temp file) failing, and blaming the README
      # for that would send the user to fix a file that is fine.
      if [[ "$awk_rc" -eq 3 ]]; then
        emit_error "README badge block is malformed (start marker without matching end); leaving README.md unchanged"
      else
        emit_error "Rewriting the badge block failed (awk exit $awk_rc); leaving README.md unchanged"
      fi
      exit 2
    fi
    mv -f "$tmp" "$readme" || {
      rm -f "$tmp"
      emit_error "Cannot replace README.md with the rewritten copy; leaving README.md unchanged"
      exit 2
    }
  elif [[ "$has_start" == true ]]; then
    # Start marker present but end marker missing: a destructive rewrite would
    # delete everything after the start marker. Preserve the file instead.
    emit_error "README badge block is malformed (start marker without matching end); leaving README.md unchanged"
    exit 2
  else
    log "No markers found, appending badges to README.md"
    printf '\n%s\n' "$badge_block" >> "$readme"
  fi
}

###############################################################################
# Main logic
###############################################################################
main() {
  check_dependencies
  parse_args "$@"

  local latest_json="$TARGET/.harness-eval/latest.json"
  if [[ ! -f "$latest_json" ]]; then
    emit_error "No latest.json found at: $latest_json"
    exit 1
  fi

  log "Reading $latest_json"

  local score grade timestamp
  score="$(jq -r '.scores.overall' "$latest_json")" || {
    emit_error "Failed to parse scores.overall from latest.json"
    exit 2
  }
  grade="$(jq -r '.scores.grade' "$latest_json")" || {
    emit_error "Failed to parse scores.grade from latest.json"
    exit 2
  }
  timestamp="$(jq -r '.timestamp' "$latest_json")" || {
    emit_error "Failed to parse timestamp from latest.json"
    exit 2
  }

  if [[ "$score" == "null" || "$grade" == "null" || "$timestamp" == "null" ]]; then
    emit_error "Missing required fields in latest.json (scores.overall, scores.grade, timestamp)"
    exit 2
  fi

  # SECURITY: latest.json may originate from an untrusted target project.
  # Validate every field before it is fed to awk / jq / markdown / URLs so a
  # crafted file cannot inject code or corrupt the badge output.
  # score flows into an awk program and jq --argjson: it MUST be numeric.
  if [[ ! "$score" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    emit_error "Invalid non-numeric score in latest.json: $score"
    exit 2
  fi
  # grade is embedded in badge markdown/URLs: restrict to a safe charset.
  if [[ ! "$grade" =~ ^[A-Za-z][+-]?$ ]]; then
    emit_error "Invalid grade in latest.json: $grade"
    exit 2
  fi

  # Extract date portion from ISO timestamp (e.g. "2026-04-06T00:00:00Z" -> "2026-04-06")
  local date="${timestamp%%T*}"
  # date is embedded in a badge URL: require a plain ISO date (digits/dashes).
  if [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    emit_error "Invalid timestamp in latest.json (expected ISO date): $timestamp"
    exit 2
  fi

  local color
  color="$(score_to_color "$score")"
  log "Score=$score Grade=$grade Color=$color Date=$date"

  local badge_block
  badge_block="$(build_badge_block "$score" "$grade" "$color" "$date")"

  update_readme "$badge_block"

  log "README.md updated successfully"

  # Output result JSON
  jq -n \
    --arg updated "README.md" \
    --argjson score "$score" \
    --arg grade "$grade" \
    --arg color "$color" \
    '{"updated":$updated,"score":$score,"grade":$grade,"color":$color}'
}

main "$@"
