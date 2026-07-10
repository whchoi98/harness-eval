#!/bin/bash
# Project setup script for new developers.
# Usage: bash scripts/setup.sh

set -euo pipefail

echo "=== harness-eval Setup ==="

# Check prerequisites
echo ""
echo "Checking prerequisites..."

MISSING=0

check_cmd() {
    if command -v "$1" &>/dev/null; then
        echo "  [OK] $1"
    else
        echo "  [MISSING] $1 — $2"
        MISSING=1
    fi
}

check_cmd git "install from https://git-scm.com"
check_cmd bash "install bash 4+"
check_cmd jq "install with: brew install jq / sudo apt install jq"
check_cmd python3 "install Python 3"

if [ "$MISSING" -eq 1 ]; then
    echo ""
    echo "Install missing prerequisites and re-run this script."
    exit 1
fi

# Install git hooks
echo ""
echo "Installing git hooks..."
bash scripts/install-hooks.sh

# Validate plugin structure
echo ""
echo "Validating plugin structure..."
cd plugins/harness-eval
if [ -f tests/harness-run-all.sh ]; then
    bash tests/harness-run-all.sh structure 2>/dev/null && echo "  [OK] Plugin structure valid" || echo "  [WARN] Some structure checks failed"
fi
cd - > /dev/null

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  cd plugins/harness-eval"
echo "  bash tests/harness-run-all.sh    # Run all tests"
echo ""
