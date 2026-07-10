#!/usr/bin/env bash
# Present hook referenced by the nested-schema fixture settings.json.
# Reads the event payload from stdin (Claude Code hook runtime contract) and no-ops.
payload="$(cat 2>/dev/null || true)"
: "${payload:=}"
exit 0
