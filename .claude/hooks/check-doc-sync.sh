#!/bin/bash
# Detect documentation sync needs after file changes.
# Wired as a Claude Code PostToolUse hook (matcher: Write|Edit) in .claude/settings.json.
# Claude Code delivers the event payload as JSON on stdin; the edited file path is
# read from .tool_input.file_path (an absolute path) and normalized to repo-relative.

# Resolve the changed file path. A positional arg takes precedence (manual/testing
# use); otherwise parse the PostToolUse event JSON from stdin.
if [ "$#" -ge 1 ]; then
    FILE_PATH="$1"
else
    INPUT=""
    [ ! -t 0 ] && INPUT=$(cat)
    if command -v jq >/dev/null 2>&1; then
        FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    else
        FILE_PATH=""
    fi
fi

[ -z "$FILE_PATH" ] && exit 0

# Normalize absolute paths (Claude Code passes absolute file paths) to a
# repo-relative path so the prefix matches below work.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$FILE_PATH" in
    "$PROJECT_DIR"/*) FILE_PATH="${FILE_PATH#"$PROJECT_DIR"/}" ;;
esac

# Plugin source directories (adapted for harness-eval monorepo)
SOURCE_ROOTS="plugins/harness-eval/scripts plugins/harness-eval/agents plugins/harness-eval/skills plugins/harness-eval/commands plugins/harness-eval/hooks plugins/harness-eval/templates plugins/harness-eval/tests"

for ROOT in $SOURCE_ROOTS; do
    if [[ "$FILE_PATH" == ${ROOT}/* ]]; then
        DIR=$(dirname "$FILE_PATH")
        FOUND_CLAUDE=false
        CHECK_DIR="$DIR"
        while [ "$CHECK_DIR" != "$ROOT" ] && [ "$CHECK_DIR" != "." ]; do
            if [ -f "$CHECK_DIR/CLAUDE.md" ]; then
                FOUND_CLAUDE=true
                break
            fi
            CHECK_DIR=$(dirname "$CHECK_DIR")
        done
        if ! $FOUND_CLAUDE && [ "$DIR" != "$ROOT" ]; then
            echo "[doc-sync] $DIR/CLAUDE.md is missing. Create module documentation."
        fi
        break
    fi
done

# Alert if no ADRs exist when source or architecture files change
IS_SOURCE=false
for ROOT in $SOURCE_ROOTS; do
    [[ "$FILE_PATH" == ${ROOT}/* ]] && IS_SOURCE=true && break
done
if $IS_SOURCE || [[ "$FILE_PATH" == docs/architecture.md ]]; then
    ADR_COUNT=$(find docs/decisions -name 'ADR-*.md' -not -name '.template.md' 2>/dev/null | wc -l)
    if [ "$ADR_COUNT" -eq 0 ]; then
        echo "[doc-sync] No ADRs found. Record architectural decisions."
    fi
fi

# Alert if no runbooks exist when infrastructure files change
if [[ "$FILE_PATH" == Dockerfile* ]] || [[ "$FILE_PATH" == *terraform* ]] || [[ "$FILE_PATH" == *cdk* ]] || [[ "$FILE_PATH" == template.yaml ]]; then
    RUNBOOK_COUNT=$(find docs/runbooks -name '*.md' -not -name '.template.md' 2>/dev/null | wc -l)
    if [ "$RUNBOOK_COUNT" -eq 0 ]; then
        echo "[doc-sync] No runbooks found. Create operational runbooks for deployment/recovery."
    fi
fi
