#!/bin/bash
# Project setup script for new developers.
# Usage: bash scripts/setup.sh   (run from the plugin directory)

set -e

# Resolve paths from the script location so the setup works regardless of the
# current directory. This plugin lives at <repo>/plugins/harness-eval/.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
cd "$PLUGIN_ROOT"

echo "=== harness-eval Plugin Setup ==="

# Check prerequisites
command -v git >/dev/null 2>&1 || { echo "ERROR: git is required"; exit 1; }
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash is required"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required"; exit 1; }

# Check jq (required for evaluation scripts)
if ! command -v jq >/dev/null 2>&1; then
    echo "WARNING: jq is not installed. Evaluation scripts require jq."
    echo "  Install: sudo yum install jq (AL2023) or brew install jq (macOS)"
fi

# Setup environment (.env lives at the monorepo root, next to .claude/ hooks)
if [ -f "$REPO_ROOT/.env.example" ] && [ ! -f "$REPO_ROOT/.env" ]; then
    echo "Creating .env from .env.example..."
    cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
    echo "IMPORTANT: Edit $REPO_ROOT/.env with your actual values"
fi

# Make all scripts executable
echo "Setting script permissions..."
find . -name "*.sh" -not -path "./.git/*" -exec chmod +x {} \;

# Setup Git hooks. git rev-parse walks up to the monorepo .git, so this works
# from the plugin directory even though there is no .git here.
if git rev-parse --git-dir >/dev/null 2>&1; then
    if [ -f "scripts/install-hooks.sh" ]; then
        bash scripts/install-hooks.sh
    fi
else
    echo "SKIPPED: git hook installation (not inside a git repository)."
fi

# Validate JSON files
echo "Validating JSON files..."
python3 -m json.tool .claude-plugin/plugin.json > /dev/null && echo "  .claude-plugin/plugin.json: OK" || echo "  .claude-plugin/plugin.json: INVALID"
python3 -m json.tool templates/checklist.json > /dev/null && echo "  templates/checklist.json: OK" || echo "  templates/checklist.json: INVALID"

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "  1. Read CLAUDE.md for project conventions"
echo "  2. Read docs/onboarding.md for development workflow"
echo "  3. Run tests: bash tests/harness-run-all.sh"
