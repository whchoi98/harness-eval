#!/bin/bash
# Tests for .claude/hooks/*.sh — existence, permissions, syntax, registration, behavior

# --- Existence and permissions ---
HOOKS=(check-doc-sync secret-scan session-context notify)
for hook in "${HOOKS[@]}"; do
    assert_file_exists "$hook.sh exists" ".claude/hooks/$hook.sh"
    assert_file_executable "$hook.sh is executable" ".claude/hooks/$hook.sh"
    assert_bash_syntax "$hook.sh valid bash" ".claude/hooks/$hook.sh"
done

# --- settings.json hook registration ---
assert_file_exists "settings.json exists" ".claude/settings.json"
assert_json_valid "settings.json is valid JSON" ".claude/settings.json"

SETTINGS=$(cat .claude/settings.json)
assert_contains "SessionStart hook registered" "$SETTINGS" "session-context.sh"
assert_contains "PreCommit hook registered" "$SETTINGS" "secret-scan.sh"
assert_contains "PostToolUse hook registered" "$SETTINGS" "check-doc-sync.sh"
assert_contains "PostToolUse matcher is Write|Edit" "$SETTINGS" "Write|Edit"
assert_contains "Notification hook registered" "$SETTINGS" "notify.sh"

# --- Deny list ---
assert_contains "Deny: rm -rf" "$SETTINGS" "rm -rf"
assert_contains "Deny: git push --force" "$SETTINGS" "git push --force"
assert_contains "Deny: git reset --hard" "$SETTINGS" "git reset --hard"
assert_contains "Deny: eval" "$SETTINGS" "eval"

# --- Behavior tests ---
# check-doc-sync: empty path should produce no output
OUTPUT=$(bash .claude/hooks/check-doc-sync.sh "" 2>&1)
assert_eq "check-doc-sync: empty path produces no output" "" "$OUTPUT"

# session-context: should output project info
OUTPUT=$(bash .claude/hooks/session-context.sh 2>&1)
assert_contains "session-context: shows project header" "$OUTPUT" "Project Context"
assert_contains "session-context: detects marketplace" "$OUTPUT" "harness-eval"

# notify: no webhook URL should exit silently
OUTPUT=$(CLAUDE_NOTIFY_WEBHOOK="" bash .claude/hooks/notify.sh "test" "msg" 2>&1)
assert_eq "notify.sh: no webhook URL produces no output" "" "$OUTPUT"
