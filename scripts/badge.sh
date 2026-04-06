#!/usr/bin/env bash
# badge.sh — README badge generator for harness-eval
# Usage: badge.sh <target-project-root>
# Output: JSON to stdout, logs to stderr
# Exit codes: 0 = success, 1 = no latest.json found, 2 = script error

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
emit_error() { echo "{\"error\":\"$*\"}" >&2; }

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
  awk "BEGIN {
    s = $score
    if (s >= 9.0) print \"brightgreen\"
    else if (s >= 8.0) print \"green\"
    else if (s >= 7.0) print \"yellow\"
    else if (s >= 6.0) print \"orange\"
    else print \"red\"
  }"
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

  if [[ ! -f "$readme" ]]; then
    log "README.md not found, creating new one"
    printf '%s\n' "$badge_block" > "$readme"
    return
  fi

  local content
  content="$(cat "$readme")"

  local start_marker="<!-- harness-eval-badge:start -->"
  local end_marker="<!-- harness-eval-badge:end -->"

  if echo "$content" | grep -qF "$start_marker"; then
    log "Markers found, replacing badge block"
    # Use awk to replace content between markers (inclusive)
    awk -v new_block="$badge_block" '
      /<!-- harness-eval-badge:start -->/ { in_block=1; print new_block; next }
      /<!-- harness-eval-badge:end -->/ { in_block=0; next }
      !in_block { print }
    ' "$readme" > "$readme.tmp" && mv "$readme.tmp" "$readme"
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

  # Extract date portion from ISO timestamp (e.g. "2026-04-06T00:00:00Z" -> "2026-04-06")
  local date="${timestamp%%T*}"

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
