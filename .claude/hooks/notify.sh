#!/bin/bash
# Send notifications via webhook on Claude Code events.
# Wired as a Claude Code Notification hook in .claude/settings.json.
# Claude Code delivers the event payload as JSON on stdin; this hook parses it.
# Configure the webhook via the CLAUDE_NOTIFY_WEBHOOK environment variable.

WEBHOOK_URL="${CLAUDE_NOTIFY_WEBHOOK:-}"
[ -z "$WEBHOOK_URL" ] && exit 0

# jq is required to safely build/escape the JSON payload.
command -v jq >/dev/null 2>&1 || exit 0

# Resolve event/message. Positional args take precedence (manual/testing use);
# otherwise read the hook event JSON from stdin.
if [ "$#" -ge 1 ]; then
    EVENT="${1:-unknown}"
    MESSAGE="${2:-Claude Code event occurred}"
else
    INPUT=""
    [ ! -t 0 ] && INPUT=$(cat)
    EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
    MESSAGE=$(printf '%s' "$INPUT" | jq -r '.message // empty' 2>/dev/null)
    EVENT="${EVENT:-unknown}"
    MESSAGE="${MESSAGE:-Claude Code event occurred}"
fi

PROJECT="$(basename "$(pwd)")"
BRANCH="$(git branch --show-current 2>/dev/null || echo 'unknown')"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build payload with jq so every value is safely escaped (no shell interpolation
# into the JSON body).
PAYLOAD=$(jq -n \
    --arg event "$EVENT" \
    --arg msg "$MESSAGE" \
    --arg project "$PROJECT" \
    --arg branch "$BRANCH" \
    --arg timestamp "$TIMESTAMP" \
    '{text: ("[" + $event + "] " + $msg), project: $project, branch: $branch, timestamp: $timestamp}')

# Send notification (non-blocking)
curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" > /dev/null 2>&1 &
