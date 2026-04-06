# harness-eval Monorepo

## Overview
Marketplace + plugin monorepo for harness-eval — a Claude Code plugin that evaluates harness engineering quality.

## Structure
```
.claude-plugin/           - Marketplace manifest (marketplace.json)
plugins/harness-eval/     - Plugin root (see plugins/harness-eval/CLAUDE.md for details)
.claude/                  - Development-time hooks, skills, commands, agents
docs/                     - Monorepo-level documentation
  architecture.md         - System overview and component diagram
  decisions/              - Architecture Decision Records
  runbooks/               - Operational runbooks
  onboarding.md           - New developer setup guide
scripts/                  - Monorepo-level scripts (setup, hook installation)
```

## Installation
```bash
claude plugin marketplace add https://github.com/whchoi98/harness-eval
claude plugin install harness-eval@harness-eval
```

## Development
```bash
cd plugins/harness-eval
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh
bash tests/harness-run-all.sh
```

For full plugin context, conventions, and commands, see [plugins/harness-eval/CLAUDE.md](plugins/harness-eval/CLAUDE.md).
