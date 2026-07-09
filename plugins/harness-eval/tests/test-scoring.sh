#!/usr/bin/env bash
set -euo pipefail

# test-scoring.sh — Tests for scoring.sh against fixture projects

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCORING="$PROJECT_ROOT/scripts/scoring.sh"
FIXTURES="$PROJECT_ROOT/tests/fixtures"

export HARNESS_EVAL_ROOT="$PROJECT_ROOT"

PASS=0
FAIL=0
ERRORS=""

assert_score_range() {
  local fixture="$1"
  local min="$2"
  local max="$3"
  local label="$4"

  local output score
  output=$("$SCORING" "$FIXTURES/$fixture" 2>/dev/null) || true
  score=$(echo "$output" | jq -r '.scores.overall' 2>/dev/null || echo "null")

  if [[ "$score" == "null" ]]; then
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — no score in output"
    return
  fi

  local in_range
  in_range=$(echo "$score >= $min && $score <= $max" | bc -l)
  if [[ "$in_range" == "1" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label — score $score (expected $min-$max)"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — score $score (expected $min-$max)"
  fi
}

assert_has_results() {
  local fixture="$1"
  local label="$2"

  local output count
  output=$("$SCORING" "$FIXTURES/$fixture" 2>/dev/null) || true
  count=$(echo "$output" | jq '.results | length' 2>/dev/null || echo "0")

  if [[ "$count" -gt 0 ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label — $count check results"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — no check results"
  fi
}

assert_exit_code() {
  local args="$1"
  local expected="$2"
  local label="$3"

  set +e
  eval "$SCORING" $args > /dev/null 2>&1
  local actual=$?
  set -e

  if [[ "$actual" -eq "$expected" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label — exit code $actual"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — exit code $actual (expected $expected)"
  fi
}

assert_fail_ids() {
  local fixture="$1"
  local expected="$2"   # sorted, comma-joined expected FAIL check ids ("" == none)
  local label="$3"

  local output actual
  output=$("$SCORING" "$FIXTURES/$fixture" 2>/dev/null) || true
  actual=$(echo "$output" | jq -r '[.results[] | select(.status=="FAIL") | .id] | sort | join(",")' 2>/dev/null || echo "JQ_ERROR")

  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — FAIL ids [$actual] != [$expected]"
  fi
}

assert_mode_field() {
  local args="$1" expected="$2" label="$3"
  local mode
  mode=$(eval "$SCORING" $args 2>/dev/null | jq -r '.mode' 2>/dev/null || echo "null")
  if [[ "$mode" == "$expected" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label — mode=$mode"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — mode=$mode (expected $expected)"
  fi
}

echo "=== scoring.sh tests ==="
echo ""

# Ranges are deliberately non-overlapping so a check flipping between tiers is caught.
echo "--- Score ranges ---"
assert_score_range "minimal-project"    1.0 2.5  "minimal scores 1.0-2.5"
assert_score_range "functional-project" 3.5 5.0  "functional scores 3.5-5.0"
assert_score_range "robust-project"     6.0 7.5  "robust scores 6.0-7.5"
assert_score_range "production-project" 9.5 10.0 "production scores 9.5-10.0"

echo ""
echo "--- Exact FAIL-check sets (catches a check flipping status without moving the tier score) ---"
assert_fail_ids "minimal-project" \
  "basic-command-exists,basic-hook-registered,basic-settings,func-agent,func-hook-events,func-secret-scanning,func-skills,prod-ci-cd,prod-e2e-tests,prod-migration-guide,robust-agent-schema,robust-deny-list,robust-error-recovery,robust-module-claude-md,robust-tests" \
  "minimal FAILs exactly its 15 basic/func/robust/prod checks"
assert_fail_ids "functional-project" \
  "prod-ci-cd,prod-e2e-tests,prod-migration-guide,robust-agent-schema,robust-deny-list,robust-error-recovery,robust-module-claude-md,robust-tests" \
  "functional FAILs exactly the 8 robust+prod checks"
assert_fail_ids "robust-project" \
  "prod-ci-cd,prod-e2e-tests,prod-migration-guide" \
  "robust FAILs exactly the 3 prod checks"
assert_fail_ids "production-project" \
  "" \
  "production has zero FAIL checks"

echo ""
echo "--- Monotonic ordering ---"
min_score=$("$SCORING" "$FIXTURES/minimal-project" 2>/dev/null | jq '.scores.overall') || true
func_score=$("$SCORING" "$FIXTURES/functional-project" 2>/dev/null | jq '.scores.overall') || true
rob_score=$("$SCORING" "$FIXTURES/robust-project" 2>/dev/null | jq '.scores.overall') || true
prod_score=$("$SCORING" "$FIXTURES/production-project" 2>/dev/null | jq '.scores.overall') || true

monotonic=$(echo "$prod_score >= $rob_score && $rob_score >= $func_score && $func_score >= $min_score" | bc -l)
if [[ "$monotonic" == "1" ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: scores are monotonically increasing ($min_score → $func_score → $rob_score → $prod_score)"
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}\n  FAIL: scores NOT monotonic ($min_score → $func_score → $rob_score → $prod_score)"
fi

echo ""
echo "--- Result structure ---"
assert_has_results "minimal-project" "minimal has check results"
assert_has_results "production-project" "production has check results"

# Check JSON structure fields
output=$("$SCORING" "$FIXTURES/functional-project" 2>/dev/null) || true
has_fields=$(echo "$output" | jq 'has("timestamp") and has("mode") and has("scores") and has("checklist") and has("results")' 2>/dev/null)
if [[ "$has_fields" == "true" ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: output has all required JSON fields"
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}\n  FAIL: output missing required JSON fields"
fi

echo ""
echo "--- Exit codes ---"
assert_exit_code "\"$FIXTURES/minimal-project\"" 1 "minimal exits 1 (has failures)"
assert_exit_code "\"$FIXTURES/production-project\"" 0 "production exits 0 (all pass)"
assert_exit_code "/nonexistent/path" 2 "nonexistent path exits 2"
assert_exit_code "" 2 "no arguments exits 2"
assert_exit_code "--mode" 2 "--mode without value exits 2"

echo ""
echo "--- Mode behavior ---"
# scoring.sh implements quick and standard; full is delegated to the synthesizer and
# must be rejected here. Each mode must be observably distinct.
assert_mode_field "--mode quick \"$FIXTURES/production-project\"" "quick" \
  "--mode quick reports mode=quick"
assert_mode_field "--mode standard \"$FIXTURES/production-project\"" "standard" \
  "--mode standard reports mode=standard"
assert_exit_code "--mode full \"$FIXTURES/production-project\"" 2 \
  "--mode full is rejected (exit 2; full is a synthesizer-only mode)"
# quick and standard score identically on the deterministic checklist (only .mode differs).
quick_overall=$("$SCORING" --mode quick "$FIXTURES/robust-project" 2>/dev/null | jq -r '.scores.overall') || true
std_overall=$("$SCORING" --mode standard "$FIXTURES/robust-project" 2>/dev/null | jq -r '.scores.overall') || true
if [[ "$quick_overall" == "$std_overall" && "$quick_overall" != "null" ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: quick and standard produce the same overall ($quick_overall)"
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}\n  FAIL: quick ($quick_overall) vs standard ($std_overall) overall mismatch"
fi

echo ""
echo "--- Grade mapping (canonical thresholds: A+>=9.5 ... C>=6.0 else F) ---"
prod_grade=$("$SCORING" "$FIXTURES/production-project" 2>/dev/null | jq -r '.scores.grade') || true
min_grade=$("$SCORING" "$FIXTURES/minimal-project" 2>/dev/null | jq -r '.scores.grade') || true
rob_grade=$("$SCORING" "$FIXTURES/robust-project" 2>/dev/null | jq -r '.scores.grade') || true
assert_eq_local() {
  local expected="$1" actual="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1)); echo "  PASS: $label — $actual"
  else
    FAIL=$((FAIL + 1)); ERRORS="${ERRORS}\n  FAIL: $label — got $actual (expected $expected)"
  fi
}
assert_eq_local "A+" "$prod_grade" "production grade is A+ (10.0)"
assert_eq_local "C"  "$rob_grade"  "robust grade is C (6.8)"
assert_eq_local "F"  "$min_grade"  "minimal grade is F (1.6)"

echo ""
echo "========================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailures:$ERRORS"
  exit 1
fi
echo "All tests passed!"
