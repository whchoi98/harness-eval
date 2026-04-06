#!/bin/bash
# Install Git hooks.
# Usage: bash scripts/install-hooks.sh

set -e

HOOKS_DIR=".git/hooks"

if [ ! -d "$HOOKS_DIR" ]; then
    echo "ERROR: .git/hooks directory not found. Is this a git repository?"
    exit 1
fi

# Install commit-msg hook (removes Co-Authored-By lines)
cat > "$HOOKS_DIR/commit-msg" << 'HOOK'
#!/bin/bash
# Remove Co-Authored-By lines from commit messages.
# Prevents Claude and other AI assistants from appearing as contributors.
sed -i '/^[Cc]o-[Aa]uthored-[Bb]y:.*/d' "$1"
sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$1"
HOOK
chmod +x "$HOOKS_DIR/commit-msg"
echo "Installed commit-msg hook (AI co-author removal)"

echo "=== Git hooks installed ==="
