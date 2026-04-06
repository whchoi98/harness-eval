#!/bin/bash
# Load project context at Claude Code session start.
# Outputs key project information for immediate context.

echo "=== Project Context ==="

# Plugin detection
if [ -f ".claude-plugin/plugin.json" ]; then
    NAME=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json')).get('name',''))" 2>/dev/null)
    VERSION=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json')).get('version',''))" 2>/dev/null)
    echo "Project: $NAME v$VERSION (Claude Code Plugin)"
elif [ -f "package.json" ]; then
    NAME=$(python3 -c "import json; print(json.load(open('package.json')).get('name',''))" 2>/dev/null)
    echo "Project: $NAME (Node.js)"
elif [ -f "pyproject.toml" ]; then
    echo "Project: $(basename $(pwd)) (Python)"
elif [ -f "go.mod" ]; then
    MODULE=$(head -1 go.mod | awk '{print $2}')
    echo "Project: $MODULE (Go)"
else
    echo "Project: $(basename $(pwd))"
fi

# Recent activity
LAST_COMMIT=$(git log -1 --format="%h %s (%cr)" 2>/dev/null)
[ -n "$LAST_COMMIT" ] && echo "Last commit: $LAST_COMMIT"

# Branch info
BRANCH=$(git branch --show-current 2>/dev/null)
[ -n "$BRANCH" ] && echo "Branch: $BRANCH"

# Uncommitted changes
CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
[ "$CHANGES" -gt 0 ] && echo "Uncommitted changes: $CHANGES file(s)"

# Documentation status
CLAUDE_COUNT=$(find . -name "CLAUDE.md" -not -path "./.git/*" -not -path "./tests/fixtures/*" 2>/dev/null | wc -l | tr -d ' ')
echo "CLAUDE.md files: $CLAUDE_COUNT"

echo "======================"
