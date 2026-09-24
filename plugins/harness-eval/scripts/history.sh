#!/usr/bin/env bash
# history.sh — Evaluation history tracking for harness-eval
# Usage:
#   history.sh <project> save              # Read score JSON from stdin, append to history
#   history.sh <project> list [--last N]   # List evaluation summaries
#   history.sh <project> compare [--eval-id ID]  # Compare latest with previous
# Output: JSON to stdout, logs to stderr
# Exit codes: 0 = success, 1 = issues, 2 = script error
# save exits 2 without writing when .harness-eval/, history.json, or latest.json
# is a symlink, and creates .harness-eval/.gitignore ("*") when none exists.

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
# Build the error JSON with jq so messages containing quotes/backslashes
# (e.g. target paths) stay valid JSON for machine consumers on stderr.
emit_error() { jq -n --arg msg "$*" '{error:$msg}' >&2; }

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

# A target repository can commit .harness-eval/, history.json, or latest.json
# as a symlink to a file outside the project. These writes happen inside this
# script, where Claude Code's permission checks cannot see them, so refuse any
# storage path that is a symlink or that exists as something other than the
# expected kind of file.
refuse_unsafe_storage() {
  local dir hfile lfile p
  dir="$(harness_dir)"
  hfile="$(history_file)"
  lfile="$(latest_file)"
  for p in "$dir" "$hfile" "$lfile"; do
    if [[ -L "$p" ]]; then
      emit_error "Refusing to write through a symlink: $p"
      exit 2
    fi
  done
  if [[ -e "$dir" && ! -d "$dir" ]]; then
    emit_error "Not a directory: $dir"
    exit 2
  fi
  for p in "$hfile" "$lfile"; do
    if [[ -e "$p" && ! -f "$p" ]]; then
      emit_error "Not a regular file: $p"
      exit 2
    fi
  done
}

# write_file <dest> <content>: write content to a new temp file beside dest,
# then rename it over dest. The rename replaces the directory entry, so a link
# planted after the checks above is replaced rather than followed.
write_file() {
  local dest="$1" content="$2" tmp mode=""
  tmp="$(mktemp "$(dirname "$dest")/.$(basename "$dest").XXXXXX")" || {
    emit_error "Cannot create a temporary file next to $dest"
    exit 2
  }
  # mktemp creates the file 0600, and the rename replaces dest with it, so set
  # the mode here. An existing dest keeps its own mode (GNU stat, then BSD
  # stat): a user who narrowed history.json or latest.json, say to 600, would
  # otherwise see it widened again on every save. Only a new file gets the mode
  # a plain redirect would give under the caller's umask.
  if [[ -f "$dest" ]]; then
    mode="$(stat -c %a "$dest" 2>/dev/null || stat -f %Lp "$dest" 2>/dev/null || true)"
  fi
  if [[ ! "$mode" =~ ^[0-7]{3,4}$ ]]; then
    mode="$(printf '%o' $(( 0666 & ~$(umask) )))"
  fi
  chmod "$mode" "$tmp" 2>/dev/null || true
  if printf '%s\n' "$content" > "$tmp" && mv -f "$tmp" "$dest"; then
    return 0
  fi
  rm -f "$tmp"
  emit_error "Failed to write $dest"
  exit 2
}

ensure_storage() {
  refuse_unsafe_storage

  local dir
  dir="$(harness_dir)"
  if [[ ! -d "$dir" ]]; then
    log "Creating .harness-eval directory at $dir"
    mkdir -p "$dir"
  fi

  # Evaluation output (history, reports, the collector inventory) should not be
  # committed by accident, and the target repo may have no ignore rule for it.
  # A .gitignore containing "*" ignores the whole directory, itself included.
  # An existing file or link is left as it is, so a user's own rules win.
  if [[ ! -e "$dir/.gitignore" && ! -L "$dir/.gitignore" ]]; then
    printf '*\n' > "$dir/.gitignore" 2>/dev/null \
      || log "Could not create $dir/.gitignore; continuing"
  fi

  local hfile
  hfile="$(history_file)"
  if [[ ! -f "$hfile" ]]; then
    local project_name initial
    project_name="$(basename "$TARGET")"
    log "Initializing history.json for project: $project_name"
    initial="$(jq -n -c \
      --arg version "1.0" \
      --arg project "$project_name" \
      '{"version":$version,"project":$project,"evaluations":[]}')"
    write_file "$hfile" "$initial"
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
  local updated latest
  updated="$(jq -c --argjson eval "$evaluation" '.evaluations += [$eval]' "$hfile")"
  latest="$(jq '.' <<<"$evaluation")"
  write_file "$hfile" "$updated"

  # Write latest.json
  write_file "$(latest_file)" "$latest"

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
        # Validate up front: without this, a non-numeric value reaches the
        # arithmetic test `[[ "$last_n" -gt 0 ]]` below, which under `set -u`
        # reinterprets it as a variable name and crashes with an "unbound
        # variable" error (exit 1) instead of the documented usage error.
        if [[ ! "$1" =~ ^[0-9]+$ ]]; then
          emit_error "--last requires a non-negative integer, got: $1"
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
