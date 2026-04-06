#!/bin/bash
# Detect documentation sync needs after file changes.
# Triggered by PostToolUse (Write|Edit) events.
# Walks parent directories to find CLAUDE.md before warning.

FILE_PATH="${1:-}"
[ -z "$FILE_PATH" ] && exit 0

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
