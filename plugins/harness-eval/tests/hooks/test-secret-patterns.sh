#!/bin/bash
# True positive and false positive tests for secret detection patterns.
# Tokens are constructed at runtime to avoid triggering GitHub Push Protection.

# --- True positives (MUST match) ---
assert_grep_match "TP: AWS Access Key ID" 'AKIA[0-9A-Z]{16}' "AKIAIOSFODNN7EXAMPLE"

# Runtime-constructed tokens
SLACK_PREFIX="xoxb-"
SLACK_BODY="123456789012-1234567890123-abcdef"
assert_grep_match "TP: Slack Bot Token" 'xoxb-[0-9]+-[A-Za-z0-9]+' "${SLACK_PREFIX}${SLACK_BODY}"

STRIPE_PREFIX="sk_live_"
STRIPE_BODY="abcdefghijklmnopqrstuvwx"
assert_grep_match "TP: Stripe Secret Key" 'sk_live_[A-Za-z0-9]{24,}' "${STRIPE_PREFIX}${STRIPE_BODY}"

GOOGLE_PREFIX="AIza"
GOOGLE_BODY="SyA1234567890abcdefghijklmnopqrstuv"
assert_grep_match "TP: Google API Key" 'AIza[A-Za-z0-9_-]{35}' "${GOOGLE_PREFIX}${GOOGLE_BODY}"

GHP_PREFIX="ghp_"
GHP_BODY="abcdefghijklmnopqrstuvwxyz0123456789"
assert_grep_match "TP: GitHub PAT" 'ghp_[A-Za-z0-9]{36}' "${GHP_PREFIX}${GHP_BODY}"

assert_grep_match "TP: Password assignment" 'password\s*[:=]\s*["\x27][^"\x27]{8,}' 'password = "mysecretpassword123"'

# --- False positives (must NOT match) ---
assert_grep_no_match "FP: Normal base64" 'AKIA[0-9A-Z]{16}' "dGhpcyBpcyBhIHRlc3Q="
assert_grep_no_match "FP: Empty password" 'password\s*[:=]\s*["\x27][^"\x27]{8,}' 'password = ""'
assert_grep_no_match "FP: Short password" 'password\s*[:=]\s*["\x27][^"\x27]{8,}' 'password = "short"'
assert_grep_no_match "FP: Normal variable" 'sk_live_[A-Za-z0-9]{24,}' "my_variable = hello"
assert_grep_no_match "FP: Random string" 'ghp_[A-Za-z0-9]{36}' "this_is_a_regular_string_value"
