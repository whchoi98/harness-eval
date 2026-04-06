#!/bin/bash
# Install git hooks for the harness-eval monorepo.
# Usage: bash scripts/install-hooks.sh

set -euo pipefail

HOOKS_DIR="$(git rev-parse --git-dir)/hooks"

# Install commit-msg hook (removes Co-Authored-By lines)
cat > "$HOOKS_DIR/commit-msg" << 'HOOK'
#!/bin/bash
# Remove Co-Authored-By lines from commit messages.
# Prevents Claude and other AI assistants from appearing as contributors.
sed -i '/^[Cc]o-[Aa]uthored-[Bb]y:.*/d' "$1"
sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$1"
HOOK
chmod +x "$HOOKS_DIR/commit-msg"

echo "Git hooks installed:"
echo "  - commit-msg (Co-Authored-By removal)"
