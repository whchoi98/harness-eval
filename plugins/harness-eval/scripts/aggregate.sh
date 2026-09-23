#!/usr/bin/env bash
# aggregate.sh — Full-mode score aggregation for harness-eval
# Usage: aggregate.sh < input.json
#   Reads stdin only and takes no arguments (any argument is a usage error).
#   stdin: {"dimensions": {<dimension>: <number 0-10> | null, ...},
#           "timestamp": "<ISO 8601 UTC>",   (optional; default: now)
#           "mode": "<mode>"}                (optional; default: "full")
#   The 12 dimension keys: correctness, safety, completeness, consistency,
#   actionability, testability, costEfficiency, contractBasedTesting,
#   agentCommunication, contextManagement, feedbackLoopMaturity, evolvability.
#   An absent key counts as null (missing). An unknown key, or a value that is not a
#   number in 0-10 or null, is an error. All 12 null is an error ("no dimension scores").
# Output: the canonical history record JSON to stdout (history.sh save appends it
#   verbatim; badge.sh reads .scores.overall, .scores.grade, .timestamp):
#   {timestamp, mode, scores:{overall, grade}, dimensions:{12}, categories:
#   {basicQuality, operational, designQuality}, status:{12}, missing:[keys]}
#   Logs and {"error": ...} messages go to stderr.
# Scoring: category average = mean of its non-null dimensions (null if none);
#   weights basicQuality 0.50, operational 0.25, designQuality 0.25, renormalized over
#   the categories that have an average; overall rounded with printf "%.1f" (as in
#   scoring.sh); grade from lib/grade.sh (shared with scoring.sh). Per-dimension status:
#   >= 7.0 "pass", 4.0-<7.0 "warn", < 4.0 "fail", null -> null.
# HARNESS_EVAL_ROOT is optional and not needed: lib/grade.sh is located relative to
#   this script.
# Exit codes: 0 = success, 2 = error (invalid input, usage, or missing dependency)

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
# Logging helpers (all go to stderr)
###############################################################################
log() { echo "[aggregate] $*" >&2; }
# Build the error JSON with jq so messages containing quotes/backslashes stay
# valid JSON for machine consumers on stderr.
emit_error() { jq -n --arg msg "$*" '{error:$msg}' >&2; }

###############################################################################
# Shared grade thresholds (lib/grade.sh, also used by scoring.sh)
###############################################################################
load_grade_lib() {
  local lib
  lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/grade.sh"
  if [[ ! -f "$lib" ]]; then
    emit_error "Grade helper not found: $lib"
    exit 2
  fi
  # shellcheck source=/dev/null
  source "$lib"
}

###############################################################################
# Dimension model: categories in weight order, dimensions in report order
###############################################################################
DIMENSIONS_JSON='[
  "correctness", "safety", "completeness", "consistency",
  "actionability", "testability", "costEfficiency", "contractBasedTesting",
  "agentCommunication", "contextManagement", "feedbackLoopMaturity", "evolvability"
]'
CATEGORIES_JSON='[
  {"name": "basicQuality",  "weight": 0.50,
   "dims": ["correctness", "safety", "completeness", "consistency"]},
  {"name": "operational",   "weight": 0.25,
   "dims": ["actionability", "testability", "costEfficiency", "contractBasedTesting"]},
  {"name": "designQuality", "weight": 0.25,
   "dims": ["agentCommunication", "contextManagement", "feedbackLoopMaturity", "evolvability"]}
]'

###############################################################################
# Input validation: prints one error message, or nothing when the input is valid
###############################################################################
validate_input() {
  local input="$1"
  echo "$input" | jq -r --argjson dims "$DIMENSIONS_JSON" '
    def iso_utc: test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$");
    if type != "object" then
      "stdin must be a JSON object with a \"dimensions\" object"
    elif ((keys - ["dimensions", "timestamp", "mode"]) | length) > 0 then
      "unknown top-level key(s): " + ((keys - ["dimensions", "timestamp", "mode"]) | join(", "))
        + " (allowed: dimensions, timestamp, mode)"
    elif (.dimensions != null and (.dimensions | type) != "object") then
      "\"dimensions\" must be an object"
    elif (((.dimensions // {}) | keys) - $dims | length) > 0 then
      "unknown dimension key(s): " + ((((.dimensions // {}) | keys) - $dims) | join(", "))
        + " (allowed: " + ($dims | join(", ")) + ")"
    elif ([(.dimensions // {}) | to_entries[]
           | select(.value != null and ((.value | type) != "number" or .value < 0 or .value > 10))]
          | length) > 0 then
      ([(.dimensions // {}) | to_entries[]
        | select(.value != null and ((.value | type) != "number" or .value < 0 or .value > 10))
        | "\(.key)=\(if (.value | type) == "number" and (.value | isnan) then "NaN" else (.value | tojson) end)"]
       | "invalid dimension value(s): " + join(", ") + " (each must be a number from 0 to 10, or null)")
    elif ([$dims[] as $k | (.dimensions // {})[$k] | select(. != null)] | length) == 0 then
      "no dimension scores: every dimension is null or absent"
    elif (.timestamp != null and ((.timestamp | type) != "string" or (.timestamp | iso_utc | not))) then
      "invalid timestamp: \(.timestamp | tojson) (expected ISO 8601, e.g. 2026-09-23T12:00:00Z)"
    elif (.mode != null and ((.mode | type) != "string" or .mode == "")) then
      "invalid mode: \(.mode | tojson) (expected a non-empty string)"
    else
      empty
    end
  '
}

###############################################################################
# Main
###############################################################################
main() {
  check_dependencies
  load_grade_lib

  if [[ $# -gt 0 ]]; then
    emit_error "Usage: aggregate.sh < input.json (reads stdin; takes no arguments, got: $*)"
    exit 2
  fi

  local input value_count
  input="$(cat)"

  if [[ -z "${input//[[:space:]]/}" ]]; then
    emit_error "stdin is empty (expected a JSON object with a \"dimensions\" object)"
    exit 2
  fi
  if ! value_count="$(echo "$input" | jq -s 'length' 2>/dev/null)"; then
    emit_error "stdin is not valid JSON"
    exit 2
  fi
  if [[ "$value_count" != "1" ]]; then
    emit_error "stdin must contain exactly one JSON object, got $value_count JSON values"
    exit 2
  fi

  local validation_error
  validation_error="$(validate_input "$input")"
  if [[ -n "$validation_error" ]]; then
    emit_error "$validation_error"
    exit 2
  fi

  # Normalize: all 12 keys in report order, absent -> null. Compute the category
  # averages and the unrounded overall (weights renormalized over scored categories).
  local computed
  computed="$(echo "$input" | jq -c \
    --argjson dims "$DIMENSIONS_JSON" \
    --argjson cats "$CATEGORIES_JSON" '
    (.dimensions // {}) as $d
    | (reduce $dims[] as $k ({}; . + {($k): $d[$k]})) as $dimensions
    | [ $cats[] | {name, weight,
          avg: ([ .dims[] as $k | $dimensions[$k] | select(. != null) ]
                | if length == 0 then null else (add / length) end)} ] as $avgs
    | [ $avgs[] | select(.avg != null) ] as $scored
    | {
        dimensions: $dimensions,
        categories: (reduce $avgs[] as $c ({};
          . + {($c.name): (if $c.avg == null then null
                           else ((($c.avg * 100) + 0.5) | floor) / 100 end)})),
        raw_overall: (($scored | map(.weight * .avg) | add) / ($scored | map(.weight) | add)),
        status: (reduce $dims[] as $k ({};
          . + {($k): ($dimensions[$k] as $v
                      | if $v == null then null
                        elif $v >= 7.0 then "pass"
                        elif $v >= 4.0 then "warn"
                        else "fail" end)})),
        missing: [ $dims[] as $k | select($dimensions[$k] == null) | $k ]
      }
  ')"

  local raw_overall overall grade
  raw_overall="$(echo "$computed" | jq -r '.raw_overall')"
  # Same rounding as scoring.sh: awk printf "%.1f".
  overall="$(awk -v r="$raw_overall" 'BEGIN { printf "%.1f", r }')"
  grade="$(score_to_grade "$overall")"

  local timestamp mode
  timestamp="$(echo "$input" | jq -r '.timestamp // empty')"
  [[ -n "$timestamp" ]] || timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mode="$(echo "$input" | jq -r '.mode // empty')"
  [[ -n "$mode" ]] || mode="full"

  log "Overall: $overall ($grade); missing: $(echo "$computed" | jq -r '.missing | if length == 0 then "none" else join(",") end')"

  jq -n \
    --arg timestamp "$timestamp" \
    --arg mode "$mode" \
    --argjson overall "$overall" \
    --arg grade "$grade" \
    --argjson computed "$computed" \
    '{
      timestamp: $timestamp,
      mode: $mode,
      scores: {
        overall: $overall,
        grade: $grade
      },
      dimensions: $computed.dimensions,
      categories: $computed.categories,
      status: $computed.status,
      missing: $computed.missing
    }'
}

main "$@"
