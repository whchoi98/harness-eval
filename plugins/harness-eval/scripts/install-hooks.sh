#!/bin/bash
# Install Git hooks.
# Usage: bash scripts/install-hooks.sh

set -e

# Resolve the hooks directory robustly. This plugin lives inside a monorepo
# (plugins/harness-eval/) and has no .git of its own, so a hard-coded relative
# ".git/hooks" path fails here. It also breaks under git worktrees (where .git
# is a file). "git rev-parse" walks up to the real git dir and --git-path
# resolves the shared hooks directory relative to the current directory.
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
echo "Installed commit-msg hook (AI co-author removal)"

echo "=== Git hooks installed ==="
