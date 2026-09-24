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
│   ├── templates/             # Scoring checklist + reference report templates
│   ├── hooks/                 # Plugin hooks
│   └── tests/                 # Test suite (447 checks via harness-run-all.sh)
├── docs/                      # Monorepo-level documentation
└── scripts/                   # Monorepo-level scripts
```

## Key Concepts

1. **Monorepo layout** — Root contains marketplace packaging and dev tools. Plugin code lives in `plugins/harness-eval/`.
2. **Auto-discovery** — Skills, agents, and commands are discovered by directory convention, not explicit registration.
3. **CLAUDE.md** — Each plugin module directory (`scripts/`, `skills/`, `hooks/`, `templates/`, `tests/`) has a `CLAUDE.md` describing its role and conventions. `commands/` and `agents/` must not have one (Claude Code would load it as a component); their notes live in `plugins/harness-eval/CLAUDE.md`.
4. **3-tier evaluation** — Quick (checklist), Standard (static+dynamic), Full (multi-agent, with phase outputs passed as files under the target's `.harness-eval/run/`).
5. **Models and effort** — Full-mode agents set `model` and `effort` in frontmatter; the reasons are recorded in the Agents module notes of `plugins/harness-eval/CLAUDE.md` and in ADR-003.

## Running Tests

```bash
cd plugins/harness-eval

# All tests
bash tests/harness-run-all.sh

# Specific test suites
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-static-analysis.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-history.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-aggregate.sh

# Subset by category
bash tests/harness-run-all.sh hooks
bash tests/harness-run-all.sh structure
```

## Making Changes

1. Read the relevant `CLAUDE.md` files before modifying any directory
2. Follow the conventions documented in `plugins/harness-eval/CLAUDE.md`
3. Run relevant tests after changes
4. If adding a new top-level directory under the plugin, create a `CLAUDE.md` in it, except in `commands/` and `agents/`; document subdirectories (e.g. `scripts/lib/`) in the parent module's `CLAUDE.md`
5. If making an architectural decision, create an ADR in `plugins/harness-eval/docs/decisions/`

## Installing the Plugin

```bash
# From marketplace
claude plugin marketplace add https://github.com/whchoi98/harness-eval
claude plugin install harness-eval@harness-eval

# For local development, add this checkout as a local marketplace, then install
# (run from the repo root, where .claude-plugin/marketplace.json lives)
claude plugin marketplace add .
claude plugin install harness-eval@harness-eval
```
