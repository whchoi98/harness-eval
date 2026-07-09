#!/bin/bash
# Install git hooks for the harness-eval monorepo.
# Usage: bash scripts/install-hooks.sh

set -euo pipefail

# Resolve the hooks directory robustly (works from any subdirectory and under
# git worktrees). --git-path resolves the shared hooks directory.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "ERROR: not inside a git repository — cannot install git hooks." >&2
    exit 1
fi

HOOKS_DIR="$(git rev-parse --git-path hooks)"
mkdir -p "$HOOKS_DIR"

# Install commit-msg hook (removes Co-Authored-By lines)
cat > "$HOOKS_DIR/commit-msg" << 'HOOK'
#!/bin/bash
# Remove Co-Authored-By lines from commit messages.
# Prevents Claude and other AI assistants from appearing as contributors.
# Portable across GNU and BSD/macOS: rewrite via a temp file with awk instead
# of the GNU-only "sed -i" in-place form (which fails on BSD/macOS sed).
msg_file="$1"
tmp_file="$msg_file.harness-eval.tmp"

awk '
  /^[Cc]o-[Aa]uthored-[Bb]y:/ { next }    # drop Co-Authored-By lines
  { lines[++n] = $0; if (NF) last = n }   # remember last non-blank line
  END { for (i = 1; i <= last; i++) print lines[i] }  # trim trailing blanks
' "$msg_file" > "$tmp_file" && mv "$tmp_file" "$msg_file"
HOOK
chmod +x "$HOOKS_DIR/commit-msg"

echo "Git hooks installed:"
echo "  - commit-msg (Co-Authored-By removal)"
