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
# Run evaluation script tests (the four suites: 24 + 107 + 38 + 74 = 243 tests)
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-static-analysis.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-history.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-aggregate.sh

# Run harness validation tests (resolves to repo root automatically; 447 checks, including the four suites above)
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
- All scripts accept `$1` as the target project root, except `aggregate.sh`, which reads JSON on stdin and takes no arguments
- All scripts must output JSON to stdout, logs to stderr
- Exit codes: 0 = success, 1 = issues found, 2 = script error (`aggregate.sh` uses only 0 and 2)

## Key Concepts

### 3-Tier Evaluation
- **Quick**: Checklist-based, < 30 seconds, runs `scoring.sh`; not saved to history
- **Standard**: Static + dynamic analysis, runs `scoring.sh` + `static-analysis.sh`, then the target's hooks and tests after the user confirms (`--static-only` skips them); saves history before writing its reports
- **Full**: Multi-agent parallel evaluation with collector, 3 evaluators, and synthesizer. The phases pass script output and the collector's inventory as files under the target's `.harness-eval/run/` by path (the three evaluator results travel inline to the synthesizer), `scripts/aggregate.sh` computes the score, and the synthesizer alone saves history and writes the two report files (the collector-failure fallback saves the Standard score instead)
- No mode runs `badge.sh`; the Stop hook updates the README badge only when the user opted in, once per saved evaluation

### Test Fixtures
Mock projects at 4 maturity levels in `tests/fixtures/` (frozen — update test expectations instead of editing them):
- `minimal-project` — CLAUDE.md + basic settings only
- `functional-project` — hooks, skills, agents, commands present
- `robust-project` — tests, deny list, module docs
- `production-project` — CI/CD, changelog, comprehensive docs

Regression fixtures: `nested-hooks-project` (nested hook schema, also frozen) and `model-era-project` (model pins, effort values, and non-`.md` agent files for `model-config` / `agent-format`). See `tests/fixtures/README.md`.

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
Check stderr: scripts report failures there as a JSON `error` (exit 2). Common causes are a missing `jq` or a wrong target path. `HARNESS_EVAL_ROOT` is optional; `scoring.sh` and `static-analysis.sh` detect the plugin root themselves.

### Permission denied on scripts
Run: `chmod +x scripts/*.sh hooks/*.sh tests/*.sh`
