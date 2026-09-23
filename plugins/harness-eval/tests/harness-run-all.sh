#!/bin/bash
# Test runner for harness engineering validation tests.
# Tests the plugin's OWN harness quality (hooks, structure, secrets).
# Usage: bash tests/harness-run-all.sh [test-file-pattern]
# Example: bash tests/harness-run-all.sh          # run all harness tests
#          bash tests/harness-run-all.sh hooks     # run only hook tests

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
FAILURES=()

export TEST_RUNNER_ACTIVE=1

pass() {
    TOTAL=$((TOTAL + 1))
    PASSED=$((PASSED + 1))
    echo -e "  ${GREEN}✓${NC} $1"
}

fail() {
    TOTAL=$((TOTAL + 1))
    FAILED=$((FAILED + 1))
    FAILURES+=("$1: $2")
    echo -e "  ${RED}✗${NC} $1"
    echo -e "    ${RED}→ $2${NC}"
}

skip() {
    TOTAL=$((TOTAL + 1))
    SKIPPED=$((SKIPPED + 1))
    echo -e "  ${YELLOW}○${NC} $1 (skipped: $2)"
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    [ "$expected" = "$actual" ] && pass "$desc" || fail "$desc" "expected '$expected', got '$actual'"
}

# Helpers feed grep with here-strings, not `echo | grep -q`: under pipefail, grep -q
# exiting on the first match can SIGPIPE the writer and fail a check that matched.
assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    grep -q -- "$needle" <<< "$haystack" && pass "$desc" || fail "$desc" "output does not contain '$needle'"
}

assert_file_exists() {
    local desc="$1" filepath="$2"
    [ -f "$filepath" ] && pass "$desc" || fail "$desc" "file not found: $filepath"
}

assert_file_executable() {
    local desc="$1" filepath="$2"
    [ -x "$filepath" ] && pass "$desc" || fail "$desc" "file not executable: $filepath"
}

assert_json_valid() {
    local desc="$1" filepath="$2"
    python3 -m json.tool "$filepath" > /dev/null 2>&1 && pass "$desc" || fail "$desc" "invalid JSON: $filepath"
}

assert_bash_syntax() {
    local desc="$1" filepath="$2"
    bash -n "$filepath" 2>/dev/null && pass "$desc" || fail "$desc" "bash syntax error in: $filepath"
}

assert_grep_match() {
    local desc="$1" pattern="$2" input="$3"
    grep -qP -- "$pattern" <<< "$input" 2>/dev/null && pass "$desc" || fail "$desc" "pattern '$pattern' did not match"
}

assert_grep_no_match() {
    local desc="$1" pattern="$2" input="$3"
    grep -qP -- "$pattern" <<< "$input" 2>/dev/null && fail "$desc" "pattern '$pattern' matched (expected no match)" || pass "$desc"
}

export -f pass fail skip assert_eq assert_contains assert_file_exists
export -f assert_file_executable assert_json_valid assert_bash_syntax
export -f assert_grep_match assert_grep_no_match

FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
export PLUGIN_ROOT REPO_ROOT
cd "$REPO_ROOT"

echo -e "${CYAN}=== Harness Validation Test Suite ===${NC}"
echo ""

# Run harness tests from hooks/ and structure/ subdirectories.
# Each file is sourced so it can call the exported pass/fail helpers that mutate the
# shared counters. errexit is disabled around the source so that a hook-behaviour
# regression (e.g. `OUTPUT=$(bash hook.sh)` returning non-zero) records a FAIL and the
# suite still prints its full summary instead of aborting mid-run without one.
# This script runs under `set -euo pipefail`, so a pipeline or command substitution
# whose first command fails (find on a missing directory, grep with no match) would
# end the whole run before the summary. Such commands carry `|| true` or a check.
for subdir in hooks structure; do
    if [ ! -d "$SCRIPT_DIR/$subdir" ]; then
        echo -e "${CYAN}▸ $subdir/${NC}"
        fail "$subdir/ tests" "directory not found: $SCRIPT_DIR/$subdir"
        echo ""
        continue
    fi
    TEST_FILES=$(find "$SCRIPT_DIR/$subdir" -name "test-*.sh" 2>/dev/null | sort) || true
    for test_file in $TEST_FILES; do
        test_name=$(basename "$test_file" .sh)
        if [ -n "$FILTER" ] && ! grep -q -- "$FILTER" <<< "$test_name"; then
            continue
        fi
        echo -e "${CYAN}▸ $test_name${NC}"
        set +e
        # shellcheck source=/dev/null
        source "$test_file"
        src_rc=$?
        set -e
        if [ "$src_rc" -ne 0 ]; then
            fail "$test_name (aborted)" "test file returned exit code $src_rc before completing"
        fi
        echo ""
    done
done

# Run the four evaluation-script suites (scoring / static-analysis / history / aggregate)
# so a single `harness-run-all.sh` invocation truly covers all suites. They are standalone
# scripts with their own PASS/FAIL accounting and their own `set -euo pipefail`, so run
# each as a subprocess (never source — they call `exit`) and fold their totals in.
EVAL_SUITES=(test-scoring test-static-analysis test-history test-aggregate)
for suite in "${EVAL_SUITES[@]}"; do
    if [ -n "$FILTER" ] && ! grep -q -- "$FILTER" <<< "$suite"; then
        continue
    fi
    suite_file="$SCRIPT_DIR/$suite.sh"
    echo -e "${CYAN}▸ $suite${NC}"
    if [ ! -f "$suite_file" ]; then
        skip "$suite" "file not found: $suite_file"
        echo ""
        continue
    fi
    suite_rc=0
    suite_out="$(HARNESS_EVAL_ROOT="$PLUGIN_ROOT" bash "$suite_file" 2>&1)" || suite_rc=$?
    # A crashed suite prints no Results line, so grep finds nothing and exits 1;
    # `|| true` keeps that from ending the run, so the FAIL below is recorded.
    summary_line="$(printf '%s\n' "$suite_out" | grep -E '^Results: [0-9]+ passed, [0-9]+ failed' | tail -1)" || true
    if [ -z "$summary_line" ]; then
        fail "$suite" "no results summary produced (suite crashed? exit code $suite_rc); last lines of its output follow"
        printf '%s\n' "$suite_out" | tail -15
        echo ""
        continue
    fi
    s_pass="$(printf '%s' "$summary_line" | awk '{print $2}')"
    s_fail="$(printf '%s' "$summary_line" | awk '{print $4}')"
    TOTAL=$((TOTAL + s_pass + s_fail))
    PASSED=$((PASSED + s_pass))
    FAILED=$((FAILED + s_fail))
    if [ "$s_fail" -gt 0 ]; then
        FAILURES+=("$suite: $s_fail failing assertion(s)")
        echo -e "  ${RED}✗${NC} $suite: $s_pass passed, $s_fail failed"
        printf '%s\n' "$suite_out" | grep -E 'FAIL:' | head -20 || true
    else
        echo -e "  ${GREEN}✓${NC} $suite: $s_pass passed"
    fi
    echo ""
done

# Shellcheck stage: static-lint every tracked shell script. SKIP when shellcheck is
# not installed. Gated at error severity so genuine defects fail the suite while the
# existing warning/info backlog (tracked separately) does not block it; CI runs the
# stricter warning-level lint as an advisory job.
if [ -z "$FILTER" ] || grep -q -- "$FILTER" <<< "shellcheck"; then
    echo -e "${CYAN}▸ shellcheck${NC}"
    if command -v shellcheck >/dev/null 2>&1; then
        SC_FILES=()
        while IFS= read -r -d '' f; do
            SC_FILES+=("$f")
        done < <(find "$REPO_ROOT" -name '*.sh' -not -path '*/.git/*' -print0 | sort -z)
        if [ "${#SC_FILES[@]}" -eq 0 ]; then
            skip "shellcheck lint" "no .sh files found"
        else
            SC_LOG="$(mktemp)"
            if shellcheck -S error "${SC_FILES[@]}" >"$SC_LOG" 2>&1; then
                pass "shellcheck: ${#SC_FILES[@]} scripts clean (error severity)"
            else
                fail "shellcheck: error-severity findings" "$(head -20 "$SC_LOG")"
            fi
            rm -f "$SC_LOG"
        fi
    else
        skip "shellcheck lint" "shellcheck not installed"
    fi
    echo ""
fi

echo -e "${CYAN}=== Results ===${NC}"
echo -e "  Total:   $TOTAL"
echo -e "  ${GREEN}Passed:  $PASSED${NC}"
[ "$FAILED" -gt 0 ] && echo -e "  ${RED}Failed:  $FAILED${NC}" || echo -e "  Failed:  0"
[ "$SKIPPED" -gt 0 ] && echo -e "  ${YELLOW}Skipped: $SKIPPED${NC}" || echo -e "  Skipped: 0"

if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo -e "${RED}=== Failures ===${NC}"
    for f in "${FAILURES[@]}"; do
        echo -e "  ${RED}✗${NC} $f"
    done
    exit 1
else
    echo ""
    echo -e "${GREEN}All harness tests passed.${NC}"
fi
