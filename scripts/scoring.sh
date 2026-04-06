#!/usr/bin/env bash
# scoring.sh — Core checklist evaluation engine for harness-eval
# Usage: scoring.sh [--mode quick|standard] <target-project-root>
# Output: JSON to stdout, logs to stderr
# Exit codes: 0 = all pass, 1 = some failures, 2 = script error

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
MODE="standard"
TARGET=""
HARNESS_EVAL_ROOT="${HARNESS_EVAL_ROOT:-}"

###############################################################################
# Resolve plugin root from script location if not set
###############################################################################
resolve_root() {
  if [[ -z "$HARNESS_EVAL_ROOT" ]]; then
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    HARNESS_EVAL_ROOT="$(cd "$script_dir/.." && pwd)"
  fi
}

###############################################################################
# Argument parsing
###############################################################################
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        shift
        MODE="${1:-standard}"
        if [[ "$MODE" != "quick" && "$MODE" != "standard" ]]; then
          emit_error "Invalid mode: $MODE (must be quick or standard)"
          exit 2
        fi
        shift
        ;;
      -*)
        emit_error "Unknown flag: $1"
        exit 2
        ;;
      *)
        TARGET="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$TARGET" ]]; then
    emit_error "Usage: scoring.sh [--mode quick|standard] <target-project-root>"
    exit 2
  fi

  # Resolve to absolute path
  TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || {
    emit_error "Target directory does not exist: $TARGET"
    exit 2
  }

  if [[ ! -d "$TARGET" ]]; then
    emit_error "Target is not a directory: $TARGET"
    exit 2
  fi
}

###############################################################################
# Logging helpers (all go to stderr)
###############################################################################
log() { echo "[scoring] $*" >&2; }
emit_error() { echo "{\"error\":\"$*\"}" >&2; }

###############################################################################
# Check function: file_exists
#   Params: target (relative path)
###############################################################################
check_file_exists() {
  local target="$1"
  [[ -f "$TARGET/$target" ]]
}

###############################################################################
# Check function: file_exists_any
#   Params: targets (JSON array of relative paths, may include globs)
###############################################################################
check_file_exists_any() {
  local targets_json="$1"
  local count
  count="$(echo "$targets_json" | jq -r 'length')"

  for (( i=0; i<count; i++ )); do
    local t
    t="$(echo "$targets_json" | jq -r ".[$i]")"

    # Check if target contains glob characters
    if [[ "$t" == *"*"* || "$t" == *"?"* || "$t" == *"["* ]]; then
      # Use find for glob expansion
      local dir_part file_part
      dir_part="$(dirname "$t")"
      file_part="$(basename "$t")"
      local found
      found="$(find "$TARGET/$dir_part" -maxdepth 1 -name "$file_part" -print -quit 2>/dev/null || true)"
      if [[ -n "$found" ]]; then
        return 0
      fi
    else
      if [[ -f "$TARGET/$t" ]]; then
        return 0
      fi
    fi
  done
  return 1
}

###############################################################################
# Helper: expand_glob — expand a glob pattern relative to TARGET
#   For patterns with **, uses find recursively
#   For simple patterns, uses find in the specific directory
#   Returns matching files, one per line
###############################################################################
expand_glob() {
  local pattern="$1"

  # Handle brace expansion patterns like *{e2e,integration,integ}*
  # We need to expand these into multiple -name patterns for find
  if [[ "$pattern" == *"{"*"}"* ]]; then
    _expand_glob_with_braces "$pattern"
    return
  fi

  if [[ "$pattern" == *"**"* ]]; then
    # Recursive glob: split into the part before ** and the file pattern after
    local prefix="${pattern%%\*\**}"
    local suffix="${pattern#*\*\*/}"
    # If suffix still has **, just use the whole thing
    if [[ "$suffix" == "$pattern" ]]; then
      suffix="${pattern##*/}"
      prefix="${pattern%/*}/"
    fi
    local search_dir="$TARGET/${prefix}"
    search_dir="${search_dir%/}"

    if [[ ! -d "$search_dir" ]]; then
      return
    fi

    # suffix may contain wildcards — use -name
    find "$search_dir" -type f -name "$suffix" 2>/dev/null || true
  else
    # Non-recursive: find in the specific directory
    local dir_part file_part
    dir_part="$(dirname "$pattern")"
    file_part="$(basename "$pattern")"

    local search_dir="$TARGET/$dir_part"
    if [[ ! -d "$search_dir" ]]; then
      return
    fi

    find "$search_dir" -maxdepth 1 -type f -name "$file_part" 2>/dev/null || true
  fi
}

###############################################################################
# Helper: expand braces in glob pattern
# E.g. tests/**/*{e2e,integration,integ}* becomes multiple find -name calls
###############################################################################
_expand_glob_with_braces() {
  local pattern="$1"

  # Extract the brace content
  local before_brace="${pattern%%\{*}"
  local brace_and_after="${pattern#*\{}"
  local brace_content="${brace_and_after%%\}*}"
  local after_brace="${brace_and_after#*\}}"

  # Split brace content by comma
  IFS=',' read -ra alternatives <<< "$brace_content"

  # Determine if recursive
  if [[ "$pattern" == *"**"* ]]; then
    local prefix="${before_brace%%\*\**}"
    local search_dir="$TARGET/${prefix}"
    search_dir="${search_dir%/}"

    if [[ ! -d "$search_dir" ]]; then
      return
    fi

    # For each alternative, construct a -name pattern
    # The before_brace after ** and the after_brace form the name pattern
    local name_prefix="${before_brace##*/}"
    # Remove leading **/ from name_prefix
    name_prefix="${name_prefix#\*\*/}"

    for alt in "${alternatives[@]}"; do
      local name_pattern="${name_prefix}${alt}${after_brace}"
      find "$search_dir" -type f -name "$name_pattern" 2>/dev/null || true
    done
  else
    local dir_part
    dir_part="$(dirname "$before_brace")"
    local search_dir="$TARGET/$dir_part"

    if [[ ! -d "$search_dir" ]]; then
      return
    fi

    local name_prefix="${before_brace##*/}"
    for alt in "${alternatives[@]}"; do
      local name_pattern="${name_prefix}${alt}${after_brace}"
      find "$search_dir" -maxdepth 1 -type f -name "$name_pattern" 2>/dev/null || true
    done
  fi
}

###############################################################################
# Check function: glob_min
#   Params: target (glob pattern), min (minimum count)
###############################################################################
check_glob_min() {
  local pattern="$1"
  local min="$2"

  local matches
  matches="$(expand_glob "$pattern")"
  local count=0
  if [[ -n "$matches" ]]; then
    count="$(echo "$matches" | sort -u | wc -l)"
  fi

  log "  glob_min: pattern=$pattern min=$min found=$count"
  [[ "$count" -ge "$min" ]]
}

###############################################################################
# Check function: json_field_exists
#   Params: target (JSON file), path (jq path)
###############################################################################
check_json_field_exists() {
  local target="$1"
  local jq_path="$2"
  local file="$TARGET/$target"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  local result
  result="$(jq -e "$jq_path" "$file" 2>/dev/null)" || return 1
  # jq -e exits 1 if result is null or false
  if [[ "$result" == "null" ]]; then
    return 1
  fi
  return 0
}

###############################################################################
# Check function: json_array_min
#   Params: target (JSON file), path (jq path), min (minimum count)
#   Special case: .hooks is an object with event keys containing arrays
###############################################################################
check_json_array_min() {
  local target="$1"
  local jq_path="$2"
  local min="$3"
  local file="$TARGET/$target"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  local count

  if [[ "$jq_path" == ".hooks" ]]; then
    # Special case: hooks is an object like {"PreToolUse": [...], "PostToolUse": [...]}
    # Count total entries across all event arrays
    count="$(jq -r '
      if .hooks then
        [.hooks | to_entries[] | .value | length] | add // 0
      else
        0
      end
    ' "$file" 2>/dev/null)" || count=0
  else
    # Standard: check if it's an array or object and get length
    count="$(jq -r "
      if ($jq_path | type) == \"array\" then
        ($jq_path | length)
      elif ($jq_path | type) == \"object\" then
        ($jq_path | length)
      else
        0
      end
    " "$file" 2>/dev/null)" || count=0
  fi

  log "  json_array_min: target=$target path=$jq_path min=$min count=$count"
  [[ "$count" -ge "$min" ]]
}

###############################################################################
# Check function: json_keys_present
#   Params: target (JSON file), path (jq path), keys (JSON array)
###############################################################################
check_json_keys_present() {
  local target="$1"
  local jq_path="$2"
  local keys_json="$3"
  local file="$TARGET/$target"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  local key_count
  key_count="$(echo "$keys_json" | jq -r 'length')"

  for (( i=0; i<key_count; i++ )); do
    local key
    key="$(echo "$keys_json" | jq -r ".[$i]")"
    local exists
    exists="$(jq -e "${jq_path}.${key}" "$file" 2>/dev/null)" || return 1
    if [[ "$exists" == "null" ]]; then
      return 1
    fi
  done
  return 0
}

###############################################################################
# Check function: grep_match
#   Params: target (file or glob), pattern (regex)
#   Pattern found in ANY matching file
###############################################################################
check_grep_match() {
  local target="$1"
  local pattern="$2"

  # If target is a specific file (no glob chars), check directly
  if [[ "$target" != *"*"* && "$target" != *"?"* && "$target" != *"["* ]]; then
    local file="$TARGET/$target"
    if [[ -f "$file" ]]; then
      grep -qE "$pattern" "$file" 2>/dev/null
      return $?
    fi
    return 1
  fi

  # Target is a glob — expand it
  local files
  files="$(expand_glob "$target")"
  if [[ -z "$files" ]]; then
    return 1
  fi

  while IFS= read -r f; do
    if [[ -f "$f" ]] && grep -qE "$pattern" "$f" 2>/dev/null; then
      return 0
    fi
  done <<< "$files"
  return 1
}

###############################################################################
# Check function: grep_all_files
#   Params: target (file glob), pattern (regex)
#   Pattern found in ALL matching files AND at least 1 file exists
###############################################################################
check_grep_all_files() {
  local target="$1"
  local pattern="$2"

  local files
  files="$(expand_glob "$target")"
  if [[ -z "$files" ]]; then
    log "  grep_all_files: no files match $target"
    return 1
  fi

  local file_count=0
  local match_count=0

  while IFS= read -r f; do
    if [[ -f "$f" ]]; then
      file_count=$((file_count + 1))
      if grep -qE "$pattern" "$f" 2>/dev/null; then
        match_count=$((match_count + 1))
      fi
    fi
  done <<< "$files"

  log "  grep_all_files: target=$target pattern=$pattern files=$file_count matches=$match_count"

  if [[ "$file_count" -eq 0 ]]; then
    return 1
  fi
  [[ "$match_count" -eq "$file_count" ]]
}

###############################################################################
# Dispatch a check based on type
###############################################################################
run_check() {
  local item_json="$1"

  local check_type
  check_type="$(echo "$item_json" | jq -r '.type')"

  case "$check_type" in
    file_exists)
      local target
      target="$(echo "$item_json" | jq -r '.target')"
      check_file_exists "$target"
      ;;
    file_exists_any)
      local targets
      targets="$(echo "$item_json" | jq -c '.targets')"
      check_file_exists_any "$targets"
      ;;
    glob_min)
      local target min
      target="$(echo "$item_json" | jq -r '.target')"
      min="$(echo "$item_json" | jq -r '.min')"
      check_glob_min "$target" "$min"
      ;;
    json_field_exists)
      local target path
      target="$(echo "$item_json" | jq -r '.target')"
      path="$(echo "$item_json" | jq -r '.path')"
      check_json_field_exists "$target" "$path"
      ;;
    json_array_min)
      local target path min
      target="$(echo "$item_json" | jq -r '.target')"
      path="$(echo "$item_json" | jq -r '.path')"
      min="$(echo "$item_json" | jq -r '.min')"
      check_json_array_min "$target" "$path" "$min"
      ;;
    json_keys_present)
      local target path keys
      target="$(echo "$item_json" | jq -r '.target')"
      path="$(echo "$item_json" | jq -r '.path')"
      keys="$(echo "$item_json" | jq -c '.keys')"
      check_json_keys_present "$target" "$path" "$keys"
      ;;
    grep_match)
      local target pattern
      target="$(echo "$item_json" | jq -r '.target')"
      pattern="$(echo "$item_json" | jq -r '.pattern')"
      check_grep_match "$target" "$pattern"
      ;;
    grep_all_files)
      local target pattern
      target="$(echo "$item_json" | jq -r '.target')"
      pattern="$(echo "$item_json" | jq -r '.pattern')"
      check_grep_all_files "$target" "$pattern"
      ;;
    *)
      log "  WARNING: unknown check type: $check_type"
      return 1
      ;;
  esac
}

###############################################################################
# Main evaluation logic
###############################################################################
evaluate() {
  local checklist_file="$HARNESS_EVAL_ROOT/templates/checklist.json"
  if [[ ! -f "$checklist_file" ]]; then
    emit_error "Checklist not found: $checklist_file"
    exit 2
  fi

  local checklist
  checklist="$(cat "$checklist_file")"

  # Tier order matters for dampening
  local tier_order=("basic" "functional" "robust" "production")

  # Arrays for results
  declare -A tier_passed
  declare -A tier_total
  declare -A tier_weight
  declare -A tier_ratio
  local results_json="[]"
  local any_fail=0

  for tier in "${tier_order[@]}"; do
    local tier_data
    tier_data="$(echo "$checklist" | jq -c ".tiers.${tier}")"

    if [[ "$tier_data" == "null" || -z "$tier_data" ]]; then
      log "Tier $tier not found in checklist, skipping"
      tier_passed[$tier]=0
      tier_total[$tier]=0
      tier_weight[$tier]=0
      tier_ratio[$tier]="0"
      continue
    fi

    local weight
    weight="$(echo "$tier_data" | jq -r '.weight')"
    tier_weight[$tier]="$weight"

    local items
    items="$(echo "$tier_data" | jq -c '.items[]')"

    local passed=0
    local total=0

    while IFS= read -r item; do
      [[ -z "$item" ]] && continue

      local id desc
      id="$(echo "$item" | jq -r '.id')"
      desc="$(echo "$item" | jq -r '.description')"

      total=$((total + 1))
      local status="FAIL"

      log "Checking [$tier] $id: $desc"
      if run_check "$item"; then
        status="PASS"
        passed=$((passed + 1))
        log "  -> PASS"
      else
        any_fail=1
        log "  -> FAIL"
      fi

      # Append to results
      results_json="$(echo "$results_json" | jq -c \
        --arg id "$id" \
        --arg desc "$desc" \
        --arg status "$status" \
        --arg tier "$tier" \
        --argjson weight "$weight" \
        '. + [{"id":$id,"description":$desc,"status":$status,"tier":$tier,"weight":$weight}]'
      )"
    done <<< "$items"

    tier_passed[$tier]=$passed
    tier_total[$tier]=$total

    if [[ "$total" -eq 0 ]]; then
      tier_ratio[$tier]="0"
    else
      tier_ratio[$tier]="$(awk "BEGIN {printf \"%.6f\", $passed / $total}")"
    fi

    log "Tier $tier: $passed/$total (ratio=${tier_ratio[$tier]}, weight=$weight)"
  done

  #############################################################################
  # Scoring with tier dampening
  #############################################################################
  local weighted_sum="0"
  local total_weight="0"
  local prev_ratio="1.0"

  for tier in "${tier_order[@]}"; do
    local w="${tier_weight[$tier]}"
    local r="${tier_ratio[$tier]}"

    # Effective contribution = ratio * prev_ratio * weight
    local effective
    effective="$(awk "BEGIN {printf \"%.6f\", $r * $prev_ratio * $w}")"
    weighted_sum="$(awk "BEGIN {printf \"%.6f\", $weighted_sum + $effective}")"
    total_weight="$(awk "BEGIN {printf \"%.6f\", $total_weight + $w}")"

    # Update prev_ratio = min(prev_ratio, current_ratio)
    prev_ratio="$(awk "BEGIN {
      cur = $r
      prev = $prev_ratio
      if (cur < prev) printf \"%.6f\", cur
      else printf \"%.6f\", prev
    }")"

    log "Tier $tier: effective=$effective, weighted_sum=$weighted_sum, prev_ratio=$prev_ratio"
  done

  # Normalize to 1.0-10.0
  local overall
  if awk "BEGIN {exit ($total_weight == 0) ? 0 : 1}"; then
    overall="1.0"
  else
    overall="$(awk "BEGIN {
      raw = ($weighted_sum / $total_weight) * 9.0 + 1.0
      printf \"%.1f\", raw
    }")"
  fi

  # Grade mapping
  local grade
  grade="$(awk "BEGIN {
    s = $overall
    if (s >= 9.5) print \"A+\"
    else if (s >= 9.0) print \"A\"
    else if (s >= 8.5) print \"A-\"
    else if (s >= 8.0) print \"B+\"
    else if (s >= 7.0) print \"B\"
    else if (s >= 6.0) print \"C\"
    else print \"F\"
  }")"

  log "Overall: $overall ($grade)"

  #############################################################################
  # Build output JSON
  #############################################################################
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Build checklist summary
  local checklist_json="{}"
  for tier in "${tier_order[@]}"; do
    checklist_json="$(echo "$checklist_json" | jq -c \
      --arg tier "$tier" \
      --argjson ratio "${tier_ratio[$tier]}" \
      --argjson weight "${tier_weight[$tier]}" \
      --argjson passed "${tier_passed[$tier]}" \
      --argjson total "${tier_total[$tier]}" \
      '. + {($tier): {"ratio":$ratio,"weight":$weight,"passed":$passed,"total":$total}}'
    )"
  done

  # Final JSON output
  jq -n \
    --arg timestamp "$timestamp" \
    --arg mode "$MODE" \
    --argjson overall "$overall" \
    --arg grade "$grade" \
    --argjson checklist "$checklist_json" \
    --argjson results "$results_json" \
    '{
      timestamp: $timestamp,
      mode: $mode,
      scores: {
        overall: $overall,
        grade: $grade
      },
      checklist: $checklist,
      results: $results
    }'

  # Return appropriate exit code
  if [[ "$any_fail" -eq 1 ]]; then
    return 1
  fi
  return 0
}

###############################################################################
# Entry point
###############################################################################
main() {
  check_dependencies
  resolve_root
  parse_args "$@"

  log "Evaluating: $TARGET (mode=$MODE)"
  log "Plugin root: $HARNESS_EVAL_ROOT"

  evaluate
}

main "$@"
