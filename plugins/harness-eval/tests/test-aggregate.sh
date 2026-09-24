#!/usr/bin/env bash
set -euo pipefail

# test-aggregate.sh — Tests for aggregate.sh (Full-mode score aggregation)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGGREGATE="$PROJECT_ROOT/scripts/aggregate.sh"
SCORING="$PROJECT_ROOT/scripts/scoring.sh"
HISTORY="$PROJECT_ROOT/scripts/history.sh"
BADGE="$PROJECT_ROOT/scripts/badge.sh"
GRADE_LIB="$PROJECT_ROOT/scripts/lib/grade.sh"
FIXTURES="$PROJECT_ROOT/tests/fixtures"

export HARNESS_EVAL_ROOT="$PROJECT_ROOT"

PASS=0
FAIL=0
ERRORS=""

DIM_KEYS=(correctness safety completeness consistency
          actionability testability costEfficiency contractBasedTesting
          agentCommunication contextManagement feedbackLoopMaturity evolvability)

# ---------------------------------------------------------------------------
# Input fixtures
# ---------------------------------------------------------------------------
# Basic 8,7,9,6 (avg 7.5); Operational 6,5,7,8 (avg 6.5); Design 9,8,7,6 (avg 7.5)
# overall = 0.5*7.5 + 0.25*6.5 + 0.25*7.5 = 7.25 -> printf "%.1f" -> 7.2 (B)
ALL_DIMS='{"timestamp":"2026-09-23T12:00:00Z","dimensions":{"correctness":8,"safety":7,"completeness":9,"consistency":6,"actionability":6,"testability":5,"costEfficiency":7,"contractBasedTesting":8,"agentCommunication":9,"contextManagement":8,"feedbackLoopMaturity":7,"evolvability":6}}'

# ---------------------------------------------------------------------------
# Temporary directory management
# ---------------------------------------------------------------------------
TMPDIR_LIST=()

new_tmpdir() {
  local d
  d="$(mktemp -d)"
  TMPDIR_LIST+=("$d")
  echo "$d"
}

cleanup_all() {
  for d in "${TMPDIR_LIST[@]+"${TMPDIR_LIST[@]}"}"; do
    [[ -d "$d" ]] && rm -rf "$d"
  done
}

trap cleanup_all EXIT

# ---------------------------------------------------------------------------
# Assert helpers
# ---------------------------------------------------------------------------
pass() {
  local label="$1"
  PASS=$((PASS + 1))
  echo "  PASS: $label"
}

fail() {
  local label="$1"
  local detail="${2:-}"
  FAIL=$((FAIL + 1))
  local msg="  FAIL: $label"
  [[ -n "$detail" ]] && msg="$msg — $detail"
  ERRORS="${ERRORS}\n${msg}"
  echo "$msg"
}

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label" "expected='$expected' actual='$actual'"
  fi
}

# Numeric equality, so a jq that prints 7.0 as 7 (jq < 1.7) still compares equal.
assert_num_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if awk -v a="$actual" -v e="$expected" 'BEGIN { exit !(a == e && a ~ /^-?[0-9.]+$/) }'; then
    pass "$label"
  else
    fail "$label" "expected=$expected actual='$actual'"
  fi
}

assert_match() {
  local label="$1"
  local pattern="$2"
  local actual="$3"
  if [[ "$actual" =~ $pattern ]]; then
    pass "$label"
  else
    fail "$label" "value='$actual' did not match pattern='$pattern'"
  fi
}

# Run aggregate.sh with the given stdin; sets AGG_OUT, AGG_ERR, AGG_RC.
run_aggregate() {
  local input="$1"
  shift
  local errfile
  errfile="$(mktemp)"
  set +e
  AGG_OUT="$(printf '%s' "$input" | bash "$AGGREGATE" "$@" 2>"$errfile")"
  AGG_RC=$?
  set -e
  AGG_ERR="$(cat "$errfile")"
  rm -f "$errfile"
}

# Input where every one of the 12 dimensions has the same score.
uniform_input() {
  local score="$1"
  local body="" k
  for k in "${DIM_KEYS[@]}"; do
    body="${body:+$body,}\"$k\":$score"
  done
  echo "{\"dimensions\":{$body}}"
}

# Asserts that an input is rejected: exit 2, empty stdout, {"error": ...} on stderr.
assert_rejected() {
  local label="$1"
  local input="$2"
  shift 2
  run_aggregate "$input" "$@"
  local has_error
  has_error="$(printf '%s' "$AGG_ERR" | jq -rs 'map(select(type == "object" and has("error"))) | length > 0' 2>/dev/null || echo false)"
  if [[ "$AGG_RC" -eq 2 && -z "$AGG_OUT" && "$has_error" == "true" ]]; then
    pass "$label"
  else
    fail "$label" "rc=$AGG_RC stdout='$AGG_OUT' stderr='$AGG_ERR'"
  fi
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
echo "=== aggregate.sh tests ==="
echo ""

# ---------------------------------------------------------------------------
echo "--- 1. All 12 dimensions present ---"
# ---------------------------------------------------------------------------
run_aggregate "$ALL_DIMS"
assert_eq "all dims: exit code 0" "0" "$AGG_RC"
assert_num_eq "all dims: overall 7.2 (7.25 rounded with printf %.1f)" "7.2" "$(echo "$AGG_OUT" | jq -r '.scores.overall')"
assert_eq "all dims: grade B" "B" "$(echo "$AGG_OUT" | jq -r '.scores.grade')"
assert_eq "all dims: category averages" '{"basicQuality":7.5,"operational":6.5,"designQuality":7.5}' \
  "$(echo "$AGG_OUT" | jq -c '.categories')"
assert_eq "all dims: missing is []" "[]" "$(echo "$AGG_OUT" | jq -c '.missing')"
assert_eq "all dims: mode defaults to full" "full" "$(echo "$AGG_OUT" | jq -r '.mode')"
assert_eq "all dims: timestamp passed through" "2026-09-23T12:00:00Z" "$(echo "$AGG_OUT" | jq -r '.timestamp')"
assert_eq "all dims: 12 dimension keys in report order" "$(IFS=,; echo "${DIM_KEYS[*]}")" \
  "$(echo "$AGG_OUT" | jq -r '.dimensions | keys_unsorted | join(",")')"
assert_eq "all dims: 12 status keys in report order" "$(IFS=,; echo "${DIM_KEYS[*]}")" \
  "$(echo "$AGG_OUT" | jq -r '.status | keys_unsorted | join(",")')"
assert_eq "all dims: top-level keys are the canonical record" \
  "timestamp,mode,scores,dimensions,categories,status,missing" \
  "$(echo "$AGG_OUT" | jq -r 'keys_unsorted | join(",")')"

run_aggregate "$(uniform_input 7)"
assert_match "default timestamp is ISO 8601 UTC" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
  "$(echo "$AGG_OUT" | jq -r '.timestamp')"

run_aggregate '{"mode":"full-custom","dimensions":{"safety":8}}'
assert_eq "mode passed through when given" "full-custom" "$(echo "$AGG_OUT" | jq -r '.mode')"

# ---------------------------------------------------------------------------
echo ""
echo "--- 2. Missing dimensions and weight renormalization ---"
# ---------------------------------------------------------------------------
# Design Quality evaluator failed (4 null) and one Operational dim absent:
# basic 7.5, operational (6+5+7)/3 = 6.0 -> (0.5*7.5 + 0.25*6.0) / 0.75 = 7.0
run_aggregate '{"dimensions":{"correctness":8,"safety":7,"completeness":9,"consistency":6,"actionability":6,"testability":5,"costEfficiency":7,"agentCommunication":null,"contextManagement":null,"feedbackLoopMaturity":null,"evolvability":null}}'
assert_eq "design missing: exit code 0" "0" "$AGG_RC"
assert_num_eq "design missing: overall renormalized to 7.0" "7.0" "$(echo "$AGG_OUT" | jq -r '.scores.overall')"
assert_num_eq "design missing: operational averages its 3 scored dims" "6" "$(echo "$AGG_OUT" | jq -r '.categories.operational')"
assert_eq "design missing: designQuality is null" "null" "$(echo "$AGG_OUT" | jq -r '.categories.designQuality')"
assert_eq "design missing: missing lists null and absent keys in order" \
  '["contractBasedTesting","agentCommunication","contextManagement","feedbackLoopMaturity","evolvability"]' \
  "$(echo "$AGG_OUT" | jq -c '.missing')"
assert_eq "design missing: absent key stored as null" "null" "$(echo "$AGG_OUT" | jq -r '.dimensions.contractBasedTesting')"
assert_eq "design missing: missing dim status is null" "null" "$(echo "$AGG_OUT" | jq -r '.status.evolvability')"

# static-analysis.sh failed (SCRIPT_FAILED): all 4 Basic Quality dims missing.
# (0.25*6.5 + 0.25*7.5) / 0.5 = 7.0
run_aggregate '{"dimensions":{"actionability":6,"testability":5,"costEfficiency":7,"contractBasedTesting":8,"agentCommunication":9,"contextManagement":8,"feedbackLoopMaturity":7,"evolvability":6}}'
assert_num_eq "basic missing: overall from operational+design only (7.0)" "7.0" "$(echo "$AGG_OUT" | jq -r '.scores.overall')"
assert_eq "basic missing: basicQuality is null" "null" "$(echo "$AGG_OUT" | jq -r '.categories.basicQuality')"

# Only Basic Quality scored (all evaluators failed): overall = basic average.
run_aggregate '{"dimensions":{"correctness":9,"safety":8,"completeness":7,"consistency":null}}'
assert_num_eq "basic only: overall equals the basic average (8.0)" "8.0" "$(echo "$AGG_OUT" | jq -r '.scores.overall')"
assert_eq "basic only: grade B+" "B+" "$(echo "$AGG_OUT" | jq -r '.scores.grade')"
assert_eq "basic only: 9 missing dims" "9" "$(echo "$AGG_OUT" | jq -r '.missing | length')"

# A zero score is a score, not a missing value.
run_aggregate '{"dimensions":{"correctness":0,"safety":10}}'
assert_num_eq "zero is scored: overall 5.0" "5.0" "$(echo "$AGG_OUT" | jq -r '.scores.overall')"
assert_eq "zero is scored: status fail, not null" "fail" "$(echo "$AGG_OUT" | jq -r '.status.correctness')"

# ---------------------------------------------------------------------------
echo ""
echo "--- 3. Rejected input (exit 2, empty stdout, {\"error\"} on stderr) ---"
# ---------------------------------------------------------------------------
assert_rejected "all 12 dimensions null" "$(uniform_input null)"
assert_rejected "empty dimensions object" '{"dimensions":{}}'
assert_rejected "no dimensions key" '{"timestamp":"2026-09-23T12:00:00Z"}'
assert_rejected "unknown dimension key" '{"dimensions":{"safety":7,"saftey":8}}'
assert_rejected "unknown top-level key" '{"dimensions":{"safety":7},"overall":7}'
assert_rejected "value above 10" '{"dimensions":{"safety":10.5}}'
assert_rejected "negative value" '{"dimensions":{"safety":-0.5}}'
assert_rejected "string value" '{"dimensions":{"safety":"7"}}'
assert_rejected "boolean value" '{"dimensions":{"safety":true}}'
assert_rejected "dimensions not an object" '{"dimensions":[7,8]}'
assert_rejected "stdin not an object" '[1,2,3]'
assert_rejected "stdin not JSON" 'Safety: 7/10'
assert_rejected "empty stdin" ''
assert_rejected "two JSON values" '{"dimensions":{"safety":7}}{"dimensions":{"safety":8}}'
assert_rejected "invalid timestamp" '{"dimensions":{"safety":7},"timestamp":"23 Sep 2026"}'
assert_rejected "positional argument" '{"dimensions":{"safety":7}}' /some/project

run_aggregate '{"dimensions":{"saftey":8}}'
assert_match "error message names the unknown key" 'saftey' "$AGG_ERR"

# ---------------------------------------------------------------------------
echo ""
echo "--- 4. Grade boundaries (shared lib/grade.sh, parity with scoring.sh) ---"
# ---------------------------------------------------------------------------
# shellcheck source=/dev/null
source "$GRADE_LIB"
while read -r score expected; do
  run_aggregate "$(uniform_input "$score")"
  got_overall="$(echo "$AGG_OUT" | jq -r '.scores.overall')"
  got_grade="$(echo "$AGG_OUT" | jq -r '.scores.grade')"
  lib_grade="$(score_to_grade "$score")"
  if [[ "$got_grade" == "$expected" && "$lib_grade" == "$expected" ]] \
     && awk -v a="$got_overall" -v e="$score" 'BEGIN { exit !(a == e) }'; then
    pass "grade at $score is $expected (aggregate.sh and lib/grade.sh)"
  else
    fail "grade at $score is $expected" "aggregate overall=$got_overall grade=$got_grade, lib=$lib_grade"
  fi
done <<'EOF'
5.9 F
6.0 C
6.9 C
7.0 B
7.9 B
8.0 B+
8.4 B+
8.5 A-
8.9 A-
9.0 A
9.4 A
9.5 A+
10.0 A+
EOF

# scoring.sh must use the shared helper instead of its own copy of the thresholds.
if grep -q 'score_to_grade' "$SCORING" && grep -q 'lib/grade.sh' "$SCORING" \
   && ! grep -qE '>= ?9\.5' "$SCORING"; then
  pass "scoring.sh grades via lib/grade.sh (no inline threshold table)"
else
  fail "scoring.sh grades via lib/grade.sh (no inline threshold table)" "inline thresholds found or helper not sourced"
fi

# Same overall -> same grade across modes: feed each fixture's scoring.sh overall
# to aggregate.sh as a uniform 12-dimension input. A scoring.sh error (exit 2)
# or an output without a numeric overall and a letter grade fails the check,
# because comparing two empty grades would pass without testing parity.
for fixture in minimal-project robust-project production-project; do
  set +e
  s_json="$(bash "$SCORING" "$FIXTURES/$fixture" 2>/dev/null)"
  s_rc=$?
  set -e
  s_overall="$(echo "$s_json" | jq -r '.scores.overall' 2>/dev/null || true)"
  s_grade="$(echo "$s_json" | jq -r '.scores.grade' 2>/dev/null || true)"
  if [[ "$s_rc" -gt 1 || ! "$s_overall" =~ ^[0-9]+(\.[0-9]+)?$ || ! "$s_grade" =~ ^[A-F][+-]?$ ]]; then
    fail "parity with scoring.sh on $fixture" "scoring.sh rc=$s_rc overall='$s_overall' grade='$s_grade'"
    continue
  fi
  run_aggregate "$(uniform_input "$s_overall")"
  a_grade="$(echo "$AGG_OUT" | jq -r '.scores.grade' 2>/dev/null || true)"
  if [[ "$AGG_RC" -eq 0 && "$a_grade" == "$s_grade" ]]; then
    pass "parity with scoring.sh on $fixture ($s_overall -> $s_grade)"
  else
    fail "parity with scoring.sh on $fixture" "aggregate rc=$AGG_RC grade='$a_grade', scoring.sh grade='$s_grade'"
  fi
done

# ---------------------------------------------------------------------------
echo ""
echo "--- 5. Status boundaries ---"
# ---------------------------------------------------------------------------
run_aggregate '{"dimensions":{"correctness":3.9,"safety":4.0,"completeness":6.9,"consistency":7.0,"actionability":null}}'
assert_eq "status 3.9 is fail" "fail" "$(echo "$AGG_OUT" | jq -r '.status.correctness')"
assert_eq "status 4.0 is warn" "warn" "$(echo "$AGG_OUT" | jq -r '.status.safety')"
assert_eq "status 6.9 is warn" "warn" "$(echo "$AGG_OUT" | jq -r '.status.completeness')"
assert_eq "status 7.0 is pass" "pass" "$(echo "$AGG_OUT" | jq -r '.status.consistency')"
assert_eq "status null is null" "null" "$(echo "$AGG_OUT" | jq -r '.status.actionability')"

# ---------------------------------------------------------------------------
echo ""
echo "--- 6. Output is a valid history record (history.sh save, compare, badge.sh) ---"
# ---------------------------------------------------------------------------
T="$(new_tmpdir)"
mkdir -p "$T/proj"
run_aggregate "$ALL_DIMS"
save_out="$(printf '%s' "$AGG_OUT" | bash "$HISTORY" "$T/proj" save 2>/dev/null || true)"
assert_eq "history.sh save accepts the record" "true" "$(echo "$save_out" | jq -r '.saved' 2>/dev/null || echo parse-error)"
assert_match "history.sh save assigns an eval id" '^eval-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{3}$' \
  "$(echo "$save_out" | jq -r '.id' 2>/dev/null || echo parse-error)"

latest="$T/proj/.harness-eval/latest.json"
assert_match "latest.json .scores.overall is numeric" '^[0-9]+(\.[0-9]+)?$' "$(jq -r '.scores.overall' "$latest")"
assert_match "latest.json .scores.grade is badge-safe" '^[A-Za-z][+-]?$' "$(jq -r '.scores.grade' "$latest")"
assert_match "latest.json .timestamp has an ISO date" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$(jq -r '.timestamp' "$latest")"

list_out="$(bash "$HISTORY" "$T/proj" list 2>/dev/null)"
assert_eq "history.sh list reads overall/grade" '7.2 B full' \
  "$(echo "$list_out" | jq -r '.[-1] | "\(.overall) \(.grade) \(.mode)"')"

run_aggregate "$(uniform_input 8.5)"
printf '%s' "$AGG_OUT" | bash "$HISTORY" "$T/proj" save >/dev/null 2>&1
cmp_out="$(bash "$HISTORY" "$T/proj" compare 2>/dev/null || true)"
assert_eq "history.sh compare computes delta between two records" "true" \
  "$(echo "$cmp_out" | jq -r '(.delta.overall | type) == "number" and .delta.grade_changed' 2>/dev/null || echo parse-error)"

set +e
badge_out="$(bash "$BADGE" "$T/proj" 2>/dev/null)"
badge_rc=$?
set -e
assert_eq "badge.sh reads latest.json (exit 0)" "0" "$badge_rc"
assert_eq "badge.sh reports the saved grade" "A-" "$(echo "$badge_out" | jq -r '.grade' 2>/dev/null || echo parse-error)"

# ---------------------------------------------------------------------------
echo ""
echo "========================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailures:$ERRORS"
  exit 1
fi
echo "All tests passed!"
