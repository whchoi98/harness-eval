# Developer Onboarding

## Quick Start

### 1. Prerequisites
- [ ] Bash 4+ installed
- [ ] jq installed (`jq --version`)
- [ ] Python 3 installed (`python3 --version`)
- [ ] Git installed
- [ ] Repository access granted

### 2. Setup
```bash
git clone https://github.com/whchoi98/harness-eval.git
cd harness-eval/plugins/harness-eval
bash scripts/setup.sh
```

### 3. Verify
```bash
# Run evaluation script tests
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh

# Run harness validation tests (resolves to repo root automatically)
bash tests/harness-run-all.sh

# Validate JSON
python3 -m json.tool .claude-plugin/plugin.json
python3 -m json.tool templates/checklist.json

# Check bash syntax
find . -name "*.sh" -not -path "./.git/*" -exec bash -n {} \;
```

## Project Overview
- Read `CLAUDE.md` for project context and conventions
- Read `docs/architecture.md` for system design
- Review `docs/decisions/` for architectural decisions
- Review `harness-evaluation-framework.md` for the evaluation framework specification

## Development Workflow
- Branch naming: `feat/`, `fix/`, `docs/`, `refactor/`
- Commit convention: Conventional Commits
- All scripts must accept `$1` as target project root
- All scripts must output JSON to stdout, logs to stderr
- Exit codes: 0 = success, 1 = issues found, 2 = script error

## Key Concepts

### 3-Tier Evaluation
- **Quick**: Checklist-based, < 30 seconds, runs `scoring.sh`
- **Standard**: Static + dynamic analysis, runs `scoring.sh` + `static-analysis.sh`
- **Full**: Multi-agent parallel evaluation with collector, 3 evaluators, and synthesizer

### Test Fixtures
Mock projects at 4 maturity levels in `tests/fixtures/`:
- `minimal-project` — CLAUDE.md + basic settings only
- `functional-project` — hooks, skills, agents, commands present
- `robust-project` — tests, deny list, module docs
- `production-project` — CI/CD, changelog, comprehensive docs

### Monorepo Structure
This plugin lives in a monorepo: `plugins/harness-eval/` is the plugin root, the repo root contains the marketplace manifest (`.claude-plugin/marketplace.json`).

### Plugin Convention
- `.claude-plugin/plugin.json` — Metadata only (name, version, author)
- Skills: `skills/<name>/SKILL.md` — auto-discovered by Claude Code
- Agents: `agents/<name>.md` — auto-discovered
- Commands: `commands/<name>.md` — auto-discovered
- Hooks: `hooks/hooks.json` — registered via JSON file

## Troubleshooting

### Tests fail with "jq: command not found"
Install jq: `sudo yum install jq` (AL2023) or `brew install jq` (macOS)

### Scripts output nothing
Ensure `HARNESS_EVAL_ROOT` is set: `HARNESS_EVAL_ROOT=$(pwd) bash scripts/scoring.sh <target>`

### Permission denied on scripts
Run: `chmod +x scripts/*.sh hooks/*.sh tests/*.sh`
