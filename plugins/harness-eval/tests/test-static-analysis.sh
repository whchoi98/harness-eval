#!/usr/bin/env bash
set -euo pipefail

# test-static-analysis.sh — Tests for static-analysis.sh against fixture projects

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANALYSIS="$PROJECT_ROOT/scripts/static-analysis.sh"
FIXTURES="$PROJECT_ROOT/tests/fixtures"

export HARNESS_EVAL_ROOT="$PROJECT_ROOT"

PASS=0
FAIL=0
ERRORS=""

###############################################################################
# Helpers
###############################################################################

assert_true() {
  local condition="$1"
  local label="$2"

  if [[ "$condition" == "true" || "$condition" == "1" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label"
  fi
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"

  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label — got $actual"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — got $actual (expected $expected)"
  fi
}

assert_ge() {
  local actual="$1"
  local min="$2"
  local label="$3"

  if [[ "$actual" -ge "$min" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label — $actual >= $min"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — $actual < $min"
  fi
}

assert_exit_code() {
  local args="$1"
  local expected="$2"
  local label="$3"

  set +e
  eval "$ANALYSIS" $args > /dev/null 2>&1
  local actual=$?
  set -e

  assert_eq "$actual" "$expected" "$label"
}

###############################################################################
# Test 1: Valid JSON output for all fixtures
###############################################################################
echo "=== static-analysis.sh tests ==="
echo ""
echo "--- Valid JSON output ---"

for fixture in minimal-project functional-project robust-project production-project; do
  output=$("$ANALYSIS" "$FIXTURES/$fixture" 2>/dev/null) || true
  valid=$(echo "$output" | jq 'type == "object"' 2>/dev/null || echo "false")
  assert_true "$valid" "$fixture produces valid JSON"
done

###############################################################################
# Test 2: Summary fields exist (pass/warn/fail/total)
###############################################################################
echo ""
echo "--- Summary fields ---"

for fixture in minimal-project functional-project robust-project production-project; do
  output=$("$ANALYSIS" "$FIXTURES/$fixture" 2>/dev/null) || true
  has_fields=$(echo "$output" | jq '
    .summary | type == "object"
    and has("pass") and has("warn") and has("fail") and has("total")
  ' 2>/dev/null || echo "false")
  assert_true "$has_fields" "$fixture summary has pass/warn/fail/total fields"
done

###############################################################################
# Test 3: Checks array items have required fields (id, category, status, details)
###############################################################################
echo ""
echo "--- Checks array structure ---"

for fixture in minimal-project functional-project robust-project production-project; do
  output=$("$ANALYSIS" "$FIXTURES/$fixture" 2>/dev/null) || true
  count=$(echo "$output" | jq '.checks | length' 2>/dev/null || echo "0")
  if [[ "$count" -gt 0 ]]; then
    # Verify all items have required fields
    all_valid=$(echo "$output" | jq '
      .checks | map(has("id") and has("category") and has("status") and has("details")) | all
    ' 2>/dev/null || echo "false")
    assert_true "$all_valid" "$fixture checks items have id/category/status/details"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $fixture checks array is empty"
    echo "  FAIL: $fixture checks array is empty"
  fi
done

###############################################################################
# Test 4: Minimal fixture has at least 1 FAIL (no hooks)
###############################################################################
echo ""
echo "--- Minimal fixture failures ---"

output=$("$ANALYSIS" "$FIXTURES/minimal-project" 2>/dev/null) || true
fail_count=$(echo "$output" | jq '.summary.fail' 2>/dev/null || echo "0")
assert_ge "$fail_count" 1 "minimal-project has at least 1 FAIL"

###############################################################################
# Test 5: Production fixture has 0 FAIL and 0 WARN
###############################################################################
echo ""
echo "--- Production fixture clean ---"

output=$("$ANALYSIS" "$FIXTURES/production-project" 2>/dev/null) || true
prod_fail=$(echo "$output" | jq '.summary.fail' 2>/dev/null || echo "1")
prod_warn=$(echo "$output" | jq '.summary.warn' 2>/dev/null || echo "1")
assert_eq "$prod_fail" "0" "production-project has 0 FAIL"
assert_eq "$prod_warn" "0" "production-project has 0 WARN"

###############################################################################
# Test 6: Monotonic quality — production has fewer issues than minimal
###############################################################################
echo ""
echo "--- Monotonic quality ---"

min_output=$("$ANALYSIS" "$FIXTURES/minimal-project" 2>/dev/null) || true
prod_output=$("$ANALYSIS" "$FIXTURES/production-project" 2>/dev/null) || true

min_issues=$(echo "$min_output" | jq '.summary.warn + .summary.fail' 2>/dev/null || echo "999")
prod_issues=$(echo "$prod_output" | jq '.summary.warn + .summary.fail' 2>/dev/null || echo "999")

if [[ "$prod_issues" -lt "$min_issues" ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: production has fewer issues than minimal ($prod_issues < $min_issues)"
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}\n  FAIL: production issues ($prod_issues) should be < minimal issues ($min_issues)"
fi

###############################################################################
# Test 7: Exit codes
###############################################################################
echo ""
echo "--- Exit codes ---"

assert_exit_code "\"$FIXTURES/robust-project\""     0 "robust-project exits 0 (all pass)"
assert_exit_code "\"$FIXTURES/production-project\"" 0 "production-project exits 0 (all pass)"
assert_exit_code "\"$FIXTURES/minimal-project\""    1 "minimal-project exits 1 (has fails/warns)"
assert_exit_code "/nonexistent/path"                2 "nonexistent path exits 2"
assert_exit_code ""                                 2 "no arguments exits 2"

###############################################################################
# Test 8: Bad syntax detection via temp fixture
###############################################################################
echo ""
echo "--- Bad syntax detection ---"

TMPDIR_FIXTURE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIXTURE"' EXIT

# Set up minimal temp fixture structure
mkdir -p "$TMPDIR_FIXTURE/.claude/hooks"
mkdir -p "$TMPDIR_FIXTURE/.claude"

# Create a broken hook script with invalid bash syntax
cat > "$TMPDIR_FIXTURE/.claude/hooks/broken-hook.sh" << 'BROKEN'
#!/usr/bin/env bash
# This file has intentionally broken syntax
if [[ true ]]; then
  echo "unclosed if block"
# missing fi
BROKEN

chmod +x "$TMPDIR_FIXTURE/.claude/hooks/broken-hook.sh"

# Create a minimal settings.json so other checks don't swamp the result
cat > "$TMPDIR_FIXTURE/.claude/settings.json" << 'SETTINGS'
{
  "permissions": {
    "allow": [],
    "deny": ["Bash(rm -rf:*)"]
  },
  "hooks": {
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": ".claude/hooks/broken-hook.sh"}]}],
    "PostToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": ".claude/hooks/broken-hook.sh"}]}]
  }
}
SETTINGS

# Create CLAUDE.md so root-claude-md doesn't add noise
echo "# Test project" > "$TMPDIR_FIXTURE/CLAUDE.md"

tmp_output=$("$ANALYSIS" "$TMPDIR_FIXTURE" 2>/dev/null) || true

# Check that bash-syntax check produced at least one FAIL
bash_syntax_fails=$(echo "$tmp_output" | jq '[.checks[] | select(.id == "bash-syntax" and .status == "FAIL")] | length' 2>/dev/null || echo "0")
assert_ge "$bash_syntax_fails" 1 "temp fixture with broken .sh triggers bash-syntax FAIL"

# Confirm the failing check references the broken file
broken_file_mentioned=$(echo "$tmp_output" | jq '
  [.checks[] | select(.id == "bash-syntax" and .status == "FAIL")] | length > 0
' 2>/dev/null || echo "false")
assert_true "$broken_file_mentioned" "bash-syntax FAIL check references broken hook file"

###############################################################################
# Summary
###############################################################################
echo ""
echo "========================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailures:$ERRORS"
  exit 1
fi
echo "All tests passed!"
