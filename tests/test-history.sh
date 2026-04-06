#!/usr/bin/env bash
set -euo pipefail

# test-history.sh — Tests for history.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HISTORY="$PROJECT_ROOT/scripts/history.sh"

PASS=0
FAIL=0
ERRORS=""

# ---------------------------------------------------------------------------
# Sample score JSON fixtures
# ---------------------------------------------------------------------------
SCORE_A='{"timestamp":"2026-04-06T00:00:00Z","mode":"quick","scores":{"overall":7.5,"grade":"B"},"checklist":{"basic":{"ratio":1.0,"weight":1.0,"passed":4,"total":4},"functional":{"ratio":0.5,"weight":1.5,"passed":2,"total":4},"robust":{"ratio":0.0,"weight":2.0,"passed":0,"total":5},"production":{"ratio":0.0,"weight":2.5,"passed":0,"total":3}},"results":[]}'
SCORE_B='{"timestamp":"2026-04-06T01:00:00Z","mode":"quick","scores":{"overall":8.5,"grade":"A-"},"checklist":{"basic":{"ratio":1.0,"weight":1.0,"passed":4,"total":4},"functional":{"ratio":1.0,"weight":1.5,"passed":4,"total":4},"robust":{"ratio":0.5,"weight":2.0,"passed":3,"total":5},"production":{"ratio":0.0,"weight":2.5,"passed":0,"total":3}},"results":[]}'

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

assert_exit_code() {
  local label="$1"
  local expected="$2"
  shift 2
  # "$@" is the command to run
  set +e
  "$@" >/dev/null 2>&1
  local actual=$?
  set -e
  if [[ "$actual" -eq "$expected" ]]; then
    pass "$label"
  else
    fail "$label" "exit code $actual (expected $expected)"
  fi
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
echo "=== history.sh tests ==="
echo ""

# ---------------------------------------------------------------------------
echo "--- 1. Save roundtrip ---"
# ---------------------------------------------------------------------------
T="$(new_tmpdir)"
mkdir -p "$T/proj"

output="$(echo "$SCORE_A" | "$HISTORY" "$T/proj" save 2>/dev/null)"
list_out="$(           "$HISTORY" "$T/proj" list 2>/dev/null)"
count="$(echo "$list_out" | jq 'length')"
assert_eq "save roundtrip: list returns 1 entry" "1" "$count"

# ---------------------------------------------------------------------------
echo ""
echo "--- 2. Save creates .harness-eval directory ---"
# ---------------------------------------------------------------------------
T="$(new_tmpdir)"
mkdir -p "$T/proj"
# proj has no .harness-eval yet
echo "$SCORE_A" | "$HISTORY" "$T/proj" save >/dev/null 2>&1
if [[ -d "$T/proj/.harness-eval" ]]; then
  pass "save creates .harness-eval directory"
else
  fail "save creates .harness-eval directory" ".harness-eval not found"
fi

# ---------------------------------------------------------------------------
echo ""
echo "--- 3. Save generates ID matching eval-YYYY-MM-DD-NNN ---"
# ---------------------------------------------------------------------------
T="$(new_tmpdir)"
mkdir -p "$T/proj"
save_out="$(echo "$SCORE_A" | "$HISTORY" "$T/proj" save 2>/dev/null)"
eval_id="$(echo "$save_out" | jq -r '.id')"
assert_match "save generates eval-YYYY-MM-DD-NNN id" \
  '^eval-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{3}$' \
  "$eval_id"

# ---------------------------------------------------------------------------
echo ""
echo "--- 4. Multiple saves produce 2 entries with different IDs ---"
# ---------------------------------------------------------------------------
T="$(new_tmpdir)"
mkdir -p "$T/proj"
id1="$(echo "$SCORE_A" | "$HISTORY" "$T/proj" save 2>/dev/null | jq -r '.id')"
id2="$(echo "$SCORE_B" | "$HISTORY" "$T/proj" save 2>/dev/null | jq -r '.id')"
count="$("$HISTORY" "$T/proj" list 2>/dev/null | jq 'length')"
assert_eq "multiple saves: list returns 2 entries" "2" "$count"
if [[ "$id1" != "$id2" ]]; then
  pass "multiple saves: different IDs ($id1 vs $id2)"
else
  fail "multiple saves: IDs should differ" "both=$id1"
fi

# ---------------------------------------------------------------------------
echo ""
echo "--- 5. latest.json updated after save ---"
# ---------------------------------------------------------------------------
T="$(new_tmpdir)"
mkdir -p "$T/proj"
echo "$SCORE_A" | "$HISTORY" "$T/proj" save >/dev/null 2>&1
latest_file="$T/proj/.harness-eval/latest.json"
if [[ -f "$latest_file" ]]; then
  pass "latest.json exists after save"
  latest_score="$(jq -r '.scores.overall' "$latest_file")"
  assert_eq "latest.json has correct score (7.5)" "7.5" "$latest_score"
else
  fail "latest.json exists after save" "file not found: $latest_file"
  fail "latest.json has correct score (7.5)" "file did not exist"
fi

# ---------------------------------------------------------------------------
echo ""
echo "--- 6. List --last N returns exactly N entries ---"
# ---------------------------------------------------------------------------
T="$(new_tmpdir)"
mkdir -p "$T/proj"
echo "$SCORE_A" | "$HISTORY" "$T/proj" save >/dev/null 2>&1
echo "$SCORE_B" | "$HISTORY" "$T/proj" save >/dev/null 2>&1
echo "$SCORE_A" | "$HISTORY" "$T/proj" save >/dev/null 2>&1
count="$("$HISTORY" "$T/proj" list --last 2 2>/dev/null | jq 'length')"
assert_eq "list --last 2 returns exactly 2 entries" "2" "$count"

# ---------------------------------------------------------------------------
echo ""
echo "--- 7. List on empty project returns [] ---"
# ---------------------------------------------------------------------------
T="$(new_tmpdir)"
mkdir -p "$T/proj"
list_out="$("$HISTORY" "$T/proj" list 2>/dev/null)"
assert_eq "list empty project returns []" "[]" "$list_out"

# ---------------------------------------------------------------------------
echo ""
echo "--- 8. Compare basic: shows delta ---"
# ---------------------------------------------------------------------------
T="$(new_tmpdir)"
mkdir -p "$T/proj"
echo "$SCORE_A" | "$HISTORY" "$T/proj" save >/dev/null 2>&1
echo "$SCORE_B" | "$HISTORY" "$T/proj" save >/dev/null 2>&1
cmp_out="$("$HISTORY" "$T/proj" compare 2>/dev/null)"
delta="$(echo "$cmp_out" | jq -r '.delta.overall')"
# 8.5 - 7.5 = 1.0
expected_delta="1"
actual_rounded="$(echo "$delta" | awk '{printf "%d", $1}')"
assert_eq "compare basic: delta.overall is 1.0" "$expected_delta" "$actual_rounded"
grade_changed="$(echo "$cmp_out" | jq -r '.delta.grade_changed')"
assert_eq "compare basic: grade_changed is true" "true" "$grade_changed"

# ---------------------------------------------------------------------------
echo ""
echo "--- 9. Compare with only 1 save returns error message ---"
# ---------------------------------------------------------------------------
T="$(new_tmpdir)"
mkdir -p "$T/proj"
echo "$SCORE_A" | "$HISTORY" "$T/proj" save >/dev/null 2>&1
cmp_out="$("$HISTORY" "$T/proj" compare 2>/dev/null || true)"
has_error="$(echo "$cmp_out" | jq -r 'has("error")' 2>/dev/null || echo "false")"
assert_eq "compare no-previous: output has error field" "true" "$has_error"

# ---------------------------------------------------------------------------
echo ""
echo "--- 10. Compare --eval-id: latest vs specific earlier entry ---"
# ---------------------------------------------------------------------------
T="$(new_tmpdir)"
mkdir -p "$T/proj"
first_id="$(echo "$SCORE_A" | "$HISTORY" "$T/proj" save 2>/dev/null | jq -r '.id')"
echo "$SCORE_B" | "$HISTORY" "$T/proj" save >/dev/null 2>&1
echo "$SCORE_A" | "$HISTORY" "$T/proj" save >/dev/null 2>&1
cmp_out="$("$HISTORY" "$T/proj" compare --eval-id "$first_id" 2>/dev/null)"
prev_id="$(echo "$cmp_out" | jq -r '.previous.id')"
assert_eq "compare --eval-id: previous.id matches requested id" "$first_id" "$prev_id"
cur_score="$(echo "$cmp_out" | jq -r '.current.overall')"
assert_eq "compare --eval-id: current is latest (7.5)" "7.5" "$cur_score"

# ---------------------------------------------------------------------------
echo ""
echo "--- 11. Exit codes ---"
# ---------------------------------------------------------------------------
T="$(new_tmpdir)"
mkdir -p "$T/proj"

# save exits 0
assert_exit_code "exit code: save=0" 0 \
  bash -c "echo '$SCORE_A' | \"$HISTORY\" \"$T/proj\" save"

# list on empty exits 0
T2="$(new_tmpdir)"
mkdir -p "$T2/proj"
assert_exit_code "exit code: list-empty=0" 0 \
  "$HISTORY" "$T2/proj" list

# compare with no previous exits 1
T3="$(new_tmpdir)"
mkdir -p "$T3/proj"
echo "$SCORE_A" | "$HISTORY" "$T3/proj" save >/dev/null 2>&1
assert_exit_code "exit code: compare-no-previous=1" 1 \
  "$HISTORY" "$T3/proj" compare

# bad subcommand exits 2
T4="$(new_tmpdir)"
mkdir -p "$T4/proj"
assert_exit_code "exit code: bad-subcommand=2" 2 \
  "$HISTORY" "$T4/proj" badcmd

# no arguments exits 2
assert_exit_code "exit code: no-arguments=2" 2 \
  "$HISTORY"

# ---------------------------------------------------------------------------
echo ""
echo "========================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailures:$ERRORS"
  exit 1
fi
echo "All tests passed!"
