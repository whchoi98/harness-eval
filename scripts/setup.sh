#!/bin/bash
# Project setup script for new developers.
# Usage: bash scripts/setup.sh

set -e

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

# Setup environment
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "IMPORTANT: Edit .env with your actual values"
fi

# Make all scripts executable
echo "Setting script permissions..."
find . -name "*.sh" -not -path "./.git/*" -exec chmod +x {} \;

# Setup Git hooks
if [ -d ".git" ]; then
    if [ -f "scripts/install-hooks.sh" ]; then
        bash scripts/install-hooks.sh
    fi
fi

# Validate JSON files
echo "Validating JSON files..."
python3 -m json.tool plugin.json > /dev/null && echo "  plugin.json: OK" || echo "  plugin.json: INVALID"
python3 -m json.tool templates/checklist.json > /dev/null && echo "  templates/checklist.json: OK" || echo "  templates/checklist.json: INVALID"

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "  1. Read CLAUDE.md for project conventions"
echo "  2. Read docs/onboarding.md for development workflow"
echo "  3. Run tests: bash tests/run-all.sh"
