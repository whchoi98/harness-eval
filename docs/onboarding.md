# Onboarding Guide

## Prerequisites

- Git
- Bash 4+
- jq (`brew install jq` / `sudo apt install jq`)
- Python 3 (for JSON validation)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)

## Setup

```bash
# Clone the repository
git clone https://github.com/whchoi98/harness-eval.git
cd harness-eval

# Install git hooks (Co-Authored-By removal)
bash scripts/install-hooks.sh

# Verify the setup
cd plugins/harness-eval
bash tests/harness-run-all.sh
```

## Project Structure

```
harness-eval/                  # Monorepo root
├── .claude-plugin/            # Marketplace manifest
├── .claude/                   # Dev-time hooks, skills, commands, agents
├── plugins/harness-eval/      # Plugin source (main codebase)
│   ├── agents/                # Multi-agent evaluators (Full mode)
│   ├── commands/              # Slash commands
│   ├── scripts/               # Bash scripts (scoring, analysis, history)
│   ├── skills/                # Evaluation skills (quick, standard, full, compare)
│   ├── templates/             # Report templates (bilingual)
│   ├── hooks/                 # Plugin hooks
│   └── tests/                 # Test suite (160+ tests)
├── docs/                      # Monorepo-level documentation
└── scripts/                   # Monorepo-level scripts
```

## Key Concepts

1. **Monorepo layout** — Root contains marketplace packaging and dev tools. Plugin code lives in `plugins/harness-eval/`.
2. **Auto-discovery** — Skills, agents, and commands are discovered by directory convention, not explicit registration.
3. **CLAUDE.md** — Every directory with meaningful content has a `CLAUDE.md` describing its role and conventions.
4. **3-tier evaluation** — Quick (checklist), Standard (static+dynamic), Full (multi-agent).

## Running Tests

```bash
cd plugins/harness-eval

# All tests
bash tests/harness-run-all.sh

# Specific test suites
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-static-analysis.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-history.sh

# Subset by category
bash tests/harness-run-all.sh hooks
bash tests/harness-run-all.sh structure
```

## Making Changes

1. Read the relevant `CLAUDE.md` files before modifying any directory
2. Follow the conventions documented in `plugins/harness-eval/CLAUDE.md`
3. Run relevant tests after changes
4. If adding a new directory under the plugin, create a `CLAUDE.md` in it
5. If making an architectural decision, create an ADR in `plugins/harness-eval/docs/decisions/`

## Installing the Plugin

```bash
# From marketplace
claude plugin marketplace add https://github.com/whchoi98/harness-eval
claude plugin install harness-eval@harness-eval

# For development (symlink)
claude plugin install --path plugins/harness-eval
```
