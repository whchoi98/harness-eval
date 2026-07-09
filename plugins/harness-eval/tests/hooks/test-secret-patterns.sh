#!/bin/bash
# End-to-end tests for the REAL secret-detection hook: .claude/hooks/secret-scan.sh
#
# This file is SOURCED by harness-run-all.sh and uses its exported helpers
# (pass/fail/skip) plus REPO_ROOT. Rather than re-implementing the hook's regexes
# in the test (which lets the hook rot undetected — the previous version only grep'd
# copied patterns and never ran the hook), every case stages a candidate file in a
# throwaway git repo and runs the actual hook, asserting its block/allow decision and
# message. Secret-shaped tokens are assembled from parts at runtime so this test file
# itself never contains a complete credential on a single source line.

SECRET_SCAN="$REPO_ROOT/.claude/hooks/secret-scan.sh"
FIXTURE_DIR="$PLUGIN_ROOT/tests/fixtures"

# --- Preconditions ---------------------------------------------------------
assert_file_exists "secret-scan.sh: hook present" "$SECRET_SCAN"
if [ ! -f "$SECRET_SCAN" ]; then
    return 0 2>/dev/null || exit 0
fi

if ! command -v git >/dev/null 2>&1; then
    skip "secret-scan.sh end-to-end tests" "git not available"
    return 0 2>/dev/null || exit 0
fi

# The hook's patterns rely on PCRE (grep -P); when unavailable it falls back to -E
# and relaxes patterns, so the exact TP/FP expectations below only hold under PCRE.
if ! printf 'AKIA0000000000000000\n' | grep -qP 'AKIA[0-9A-Z]{16}' 2>/dev/null; then
    skip "secret-scan.sh end-to-end tests" "grep -P (PCRE) not supported on this platform"
    return 0 2>/dev/null || exit 0
fi

# --- Sandbox: throwaway staging repos --------------------------------------
SECRET_TEST_ROOT="$(mktemp -d)"

_new_repo() {
    local d="$SECRET_TEST_ROOT/$1"
    mkdir -p "$d"
    git -C "$d" init -q
    printf '%s' "$d"
}

# Stage <name>=<content> in <repo>, run the hook with that repo as CWD, and set
# globals SCAN_OUT / SCAN_RC. The `|| SCAN_RC=$?` idiom captures the exit code
# without tripping errexit if it is active in the caller.
_scan() {
    local repo="$1" name="$2" content="$3"
    printf '%s\n' "$content" > "$repo/$name"
    git -C "$repo" add -- "$name" >/dev/null 2>&1
    SCAN_RC=0
    SCAN_OUT="$( ( cd "$repo" && bash "$SECRET_SCAN" </dev/null ) 2>&1 )" || SCAN_RC=$?
}

# Stage an existing file <src> as <name> in <repo>, run the hook.
_scan_file() {
    local repo="$1" name="$2" src="$3"
    cp "$src" "$repo/$name"
    git -C "$repo" add -- "$name" >/dev/null 2>&1
    SCAN_RC=0
    SCAN_OUT="$( ( cd "$repo" && bash "$SECRET_SCAN" </dev/null ) 2>&1 )" || SCAN_RC=$?
}

# --- True positives: one staged secret per pattern MUST block --------------
# Tokens are split across concatenation so no full credential appears literally.
TP_REPO="$(_new_repo tp)"

tp() {
    local label="$1" sample="$2"
    _scan "$TP_REPO" "candidate.txt" "$sample"
    if [ "$SCAN_RC" -ne 0 ] && printf '%s' "$SCAN_OUT" | grep -q "candidate.txt"; then
        pass "TP: $label blocked (rc=$SCAN_RC)"
    else
        fail "TP: $label" "expected block+filename, rc=$SCAN_RC out=[$SCAN_OUT]"
    fi
}

B16="IOSFODNN7EXAMPLE"                                        # 16 upper/num
B24="abcdefghijklmnopqrstuvwx"                                # 24 alnum
B36="abcdefghijklmnopqrstuvwxyz0123456789"                    # 36 alnum
B40="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"                # 40 base64-ish
G35="SyA1234567890abcdefghijklmnopqrstuv"                     # 35 for AIza
B82="abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz012345"  # 82
B90="abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz0123456789012345"  # 95
SLACK_BODY="123456789012-abcdefABCDEF0123"
YA_BODY="1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdefghij"  # 56
OA_A="abcdefghij0123456789"                                  # 20 alnum
OA_B="klmnopqrst0123456789"                                  # 20 alnum
OA_MID="T3BlbkFJ"                                            # OpenAI key infix (marker only)

tp "AWS Access Key ID"     "aws_id = AKIA${B16}"
tp "AWS Secret Access Key" "aws_secret_access_key = ${B40}"
tp "OpenAI API Key"        "token=sk-${OA_A}${OA_MID}${OA_B}"
tp "Anthropic API Key"     "key=sk-ant-${B90}"
tp "GitHub PAT"            "gh=ghp_${B36}"
tp "GitHub OAuth Token"    "gh=gho_${B36}"
tp "GitHub Fine-grained PAT" "gh=github_pat_${B82}"
tp "Slack Bot Token"       "slack=xoxb-${SLACK_BODY}"
tp "Slack User Token"      "slack=xoxp-${SLACK_BODY}"
tp "Stripe Secret Key"     "stripe=sk_live_${B24}"
tp "Stripe Restricted Key" "stripe=rk_live_${B24}"
tp "Google API Key"        "g=AIza${G35}"
tp "Google OAuth Token"    "g=ya29.${YA_BODY}"
tp "Azure Connection String" "conn=DefaultEndpointsProtocol=https;AccountName=demo"
tp "Password assignment"   'password = "mysecretpassword123"'
tp "Secret assignment"     'secret: "supersecretvalue"'
tp "API key assignment"    'api_key = "abcdef123456"'

# --- Block contract: PreToolUse block must be exit code 2 (decision #6) -----
_scan "$TP_REPO" "candidate.txt" "aws_id = AKIA${B16}"
assert_eq "block uses exit code 2 (PreToolUse block contract)" "2" "$SCAN_RC"

# --- Clean file must not block ---------------------------------------------
_scan "$TP_REPO" "candidate.txt" "just a normal line with no credentials"
if [ "$SCAN_RC" -eq 0 ]; then
    pass "clean staged file exits 0 (no block)"
else
    fail "clean staged file exits 0" "rc=$SCAN_RC out=[$SCAN_OUT]"
fi

# --- SKIP_PATTERNS: secrets in excluded files must NOT block ---------------
SKIP_REPO="$(_new_repo skip)"
_scan "$SKIP_REPO" ".env.example" "aws_id = AKIA${B16}"
if [ "$SCAN_RC" -eq 0 ]; then
    pass "SKIP: secret in .env.example is not blocked"
else
    fail "SKIP: secret in .env.example is not blocked" "rc=$SCAN_RC out=[$SCAN_OUT]"
fi

_scan "$SKIP_REPO" "README.md" "aws_id = AKIA${B16}"
if [ "$SCAN_RC" -eq 0 ]; then
    pass "SKIP: secret in *.md is not blocked"
else
    fail "SKIP: secret in *.md is not blocked" "rc=$SCAN_RC out=[$SCAN_OUT]"
fi

# --- No staged files: exit 0 -----------------------------------------------
EMPTY_REPO="$(_new_repo empty)"
SCAN_RC=0
SCAN_OUT="$( ( cd "$EMPTY_REPO" && bash "$SECRET_SCAN" </dev/null ) 2>&1 )" || SCAN_RC=$?
if [ "$SCAN_RC" -eq 0 ]; then
    pass "no staged files exits 0"
else
    fail "no staged files exits 0" "rc=$SCAN_RC out=[$SCAN_OUT]"
fi

# --- False positives fixture: must NOT block -------------------------------
FP_REPO="$(_new_repo fp)"
_scan_file "$FP_REPO" "false-positives.txt" "$FIXTURE_DIR/false-positives.txt"
if [ "$SCAN_RC" -eq 0 ]; then
    pass "FP: fixtures/false-positives.txt produces no block"
else
    fail "FP: fixtures/false-positives.txt produces no block" "rc=$SCAN_RC out=[$SCAN_OUT]"
fi

# --- Documentation fixture (secret-samples.txt describes patterns in prose,
#     contains no real tokens) must NOT block -------------------------------
_scan_file "$FP_REPO" "secret-samples.txt" "$FIXTURE_DIR/secret-samples.txt"
if [ "$SCAN_RC" -eq 0 ]; then
    pass "FP: fixtures/secret-samples.txt (prose only) produces no block"
else
    fail "FP: fixtures/secret-samples.txt (prose only) produces no block" "rc=$SCAN_RC out=[$SCAN_OUT]"
fi

# --- Cleanup ---------------------------------------------------------------
rm -rf "$SECRET_TEST_ROOT"
unset SCAN_OUT SCAN_RC
