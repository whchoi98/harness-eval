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

echo "=== scoring.sh tests ==="
echo ""

echo "--- Score ranges ---"
assert_score_range "minimal-project"    1.0 3.5  "minimal scores 1.0-3.5"
assert_score_range "functional-project" 3.0 6.0  "functional scores 3.0-6.0"
assert_score_range "robust-project"     5.5 8.5  "robust scores 5.5-8.5"
assert_score_range "production-project" 8.5 10.0 "production scores 8.5-10.0"

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
echo "--- Grade mapping ---"
prod_grade=$("$SCORING" "$FIXTURES/production-project" 2>/dev/null | jq -r '.scores.grade') || true
min_grade=$("$SCORING" "$FIXTURES/minimal-project" 2>/dev/null | jq -r '.scores.grade') || true
if [[ "$prod_grade" == "A+" || "$prod_grade" == "A" ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: production grade is $prod_grade"
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}\n  FAIL: production grade is $prod_grade (expected A+ or A)"
fi
if [[ "$min_grade" == "F" || "$min_grade" == "C" ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: minimal grade is $min_grade"
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}\n  FAIL: minimal grade is $min_grade (expected F or C)"
fi

echo ""
echo "========================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailures:$ERRORS"
  exit 1
fi
echo "All tests passed!"
