#!/usr/bin/env bash
# history.sh — Evaluation history tracking for harness-eval
# Usage:
#   history.sh <project> save              # Read score JSON from stdin, append to history
#   history.sh <project> list [--last N]   # List evaluation summaries
#   history.sh <project> compare [--eval-id ID]  # Compare latest with previous
# Output: JSON to stdout, logs to stderr
# Exit codes: 0 = success, 1 = issues, 2 = script error

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
SUBCMD=""

###############################################################################
# Logging helpers (all go to stderr)
###############################################################################
log() { echo "[history] $*" >&2; }
emit_error() { echo "{\"error\":\"$*\"}" >&2; }

###############################################################################
# Argument parsing
###############################################################################
parse_args() {
  if [[ $# -lt 2 ]]; then
    emit_error "Usage: history.sh <project> <save|list|compare> [options]"
    exit 2
  fi

  local original_target="$1"
  TARGET="$(cd "$1" 2>/dev/null && pwd)" || {
    emit_error "Target directory does not exist: $original_target"
    exit 2
  }

  SUBCMD="$2"
  shift 2

  case "$SUBCMD" in
    save)
      cmd_save "$@"
      ;;
    list)
      cmd_list "$@"
      ;;
    compare)
      cmd_compare "$@"
      ;;
    *)
      emit_error "Unknown subcommand: $SUBCMD (must be save, list, or compare)"
      exit 2
      ;;
  esac
}

###############################################################################
# Storage helpers
###############################################################################
harness_dir() {
  echo "$TARGET/.harness-eval"
}

history_file() {
  echo "$(harness_dir)/history.json"
}

latest_file() {
  echo "$(harness_dir)/latest.json"
}

ensure_storage() {
  local dir
  dir="$(harness_dir)"
  if [[ ! -d "$dir" ]]; then
    log "Creating .harness-eval directory at $dir"
    mkdir -p "$dir"
  fi

  local hfile
  hfile="$(history_file)"
  if [[ ! -f "$hfile" ]]; then
    local project_name
    project_name="$(basename "$TARGET")"
    log "Initializing history.json for project: $project_name"
    jq -n \
      --arg version "1.0" \
      --arg project "$project_name" \
      '{"version":$version,"project":$project,"evaluations":[]}' > "$hfile"
  fi
}

###############################################################################
# Generate eval ID: eval-YYYY-MM-DD-NNN
###############################################################################
generate_eval_id() {
  local today
  today="$(date -u +"%Y-%m-%d")"

  local hfile
  hfile="$(history_file)"

  # Count existing evaluations for today
  local count
  count="$(jq -r --arg today "$today" '
    [ .evaluations[] | select(.id | startswith("eval-" + $today + "-")) ] | length
  ' "$hfile" 2>/dev/null || echo 0)"

  local seq
  seq="$(printf "%03d" $(( count + 1 )))"
  echo "eval-${today}-${seq}"
}

###############################################################################
# Subcommand: save
###############################################################################
cmd_save() {
  # Read JSON from stdin
  local input
  input="$(cat)"

  # Validate it's valid JSON
  if ! echo "$input" | jq -e . &>/dev/null; then
    emit_error "stdin is not valid JSON"
    exit 2
  fi

  ensure_storage

  local eval_id
  eval_id="$(generate_eval_id)"
  log "Saving evaluation as $eval_id"

  # Attach the id to the evaluation document
  local evaluation
  evaluation="$(echo "$input" | jq -c --arg id "$eval_id" '. + {id: $id}')"

  # Append to history.json
  local hfile
  hfile="$(history_file)"
  local updated
  updated="$(jq -c --argjson eval "$evaluation" '.evaluations += [$eval]' "$hfile")"
  echo "$updated" > "$hfile"

  # Write latest.json
  echo "$evaluation" | jq '.' > "$(latest_file)"

  # Output confirmation
  jq -n --arg id "$eval_id" '{"id":$id,"saved":true}'
}

###############################################################################
# Subcommand: list
###############################################################################
cmd_list() {
  local last_n=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --last)
        shift
        if [[ $# -eq 0 ]]; then
          emit_error "--last requires a numeric argument"
          exit 2
        fi
        last_n="$1"
        shift
        ;;
      *)
        emit_error "Unknown option for list: $1"
        exit 2
        ;;
    esac
  done

  local hfile
  hfile="$(history_file)"

  if [[ ! -f "$hfile" ]]; then
    echo "[]"
    return 0
  fi

  # Build summaries: [{"id","timestamp","mode","overall","grade"}]
  local summaries
  summaries="$(jq -c '
    [ .evaluations[] | {
        id: .id,
        timestamp: .timestamp,
        mode: .mode,
        overall: .scores.overall,
        grade: .scores.grade
      }
    ]
  ' "$hfile")"

  if [[ "$last_n" -gt 0 ]]; then
    summaries="$(echo "$summaries" | jq -c --argjson n "$last_n" '.[-$n:]')"
  fi

  echo "$summaries"
}

###############################################################################
# Subcommand: compare
###############################################################################
cmd_compare() {
  local eval_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --eval-id)
        shift
        if [[ $# -eq 0 ]]; then
          emit_error "--eval-id requires an argument"
          exit 2
        fi
        eval_id="$1"
        shift
        ;;
      *)
        emit_error "Unknown option for compare: $1"
        exit 2
        ;;
    esac
  done

  local hfile
  hfile="$(history_file)"

  if [[ ! -f "$hfile" ]]; then
    jq -n '{"error":"No previous evaluation found. Run at least 2 evaluations first."}'
    return 1
  fi

  local total_count
  total_count="$(jq -r '.evaluations | length' "$hfile")"

  if [[ -z "$eval_id" ]]; then
    # Default: compare latest vs previous
    if [[ "$total_count" -lt 2 ]]; then
      jq -n '{"error":"No previous evaluation found. Run at least 2 evaluations first."}'
      return 1
    fi

    # current = last, previous = second to last
    local current previous
    current="$(jq -c '.evaluations[-1]' "$hfile")"
    previous="$(jq -c '.evaluations[-2]' "$hfile")"
  else
    # Look up specific eval-id as the "previous" to compare against latest
    local found
    found="$(jq -r --arg id "$eval_id" '.evaluations[] | select(.id == $id) | .id' "$hfile" 2>/dev/null || true)"
    if [[ -z "$found" ]]; then
      jq -n --arg id "$eval_id" '{"error":("Evaluation not found: " + $id)}'
      return 1
    fi

    if [[ "$total_count" -lt 1 ]]; then
      jq -n '{"error":"No previous evaluation found. Run at least 2 evaluations first."}'
      return 1
    fi

    local current previous
    current="$(jq -c '.evaluations[-1]' "$hfile")"
    previous="$(jq -c --arg id "$eval_id" '.evaluations[] | select(.id == $id)' "$hfile")"
  fi

  # Build per_tier comparison using checklist data
  # Tiers: basic, functional, robust, production
  local tier_order=("basic" "functional" "robust" "production")

  # Start building output
  local output
  output="$(jq -n \
    --argjson cur "$current" \
    --argjson prev "$previous" \
    '{
      current: {
        id: $cur.id,
        overall: $cur.scores.overall,
        grade: $cur.scores.grade,
        timestamp: $cur.timestamp
      },
      previous: {
        id: $prev.id,
        overall: $prev.scores.overall,
        grade: $prev.scores.grade,
        timestamp: $prev.timestamp
      },
      delta: {
        overall: ($cur.scores.overall - $prev.scores.overall),
        grade_changed: ($cur.scores.grade != $prev.scores.grade)
      }
    }'
  )"

  # Build per_tier
  local per_tier="{}"
  for tier in "${tier_order[@]}"; do
    # Check if tier exists in either evaluation
    local cur_ratio prev_ratio
    cur_ratio="$(echo "$current" | jq -r --arg t "$tier" '.checklist[$t].ratio // 0')"
    prev_ratio="$(echo "$previous" | jq -r --arg t "$tier" '.checklist[$t].ratio // 0')"

    # Skip tiers not present in checklist data
    if [[ "$cur_ratio" == "0" && "$prev_ratio" == "0" ]]; then
      # Only include if at least one eval has it explicitly
      local cur_has prev_has
      cur_has="$(echo "$current" | jq -r --arg t "$tier" '.checklist | has($t)')"
      prev_has="$(echo "$previous" | jq -r --arg t "$tier" '.checklist | has($t)')"
      if [[ "$cur_has" == "false" && "$prev_has" == "false" ]]; then
        continue
      fi
    fi

    per_tier="$(echo "$per_tier" | jq -c \
      --arg tier "$tier" \
      --argjson cur_r "$cur_ratio" \
      --argjson prev_r "$prev_ratio" \
      '. + {($tier): {
        current: $cur_r,
        previous: $prev_r,
        delta: ($cur_r - $prev_r)
      }}'
    )"
  done

  # Merge per_tier into output
  output="$(echo "$output" | jq -c --argjson pt "$per_tier" '. + {per_tier: $pt}')"

  echo "$output"
}

###############################################################################
# Entry point
###############################################################################
main() {
  check_dependencies
  parse_args "$@"
}

main "$@"
