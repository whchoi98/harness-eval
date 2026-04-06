# Project Context

## Overview
harness-eval: Claude Code harness engineering quality evaluator plugin. Provides systematic 3-tier evaluation (Quick/Standard/Full) with multi-agent design review, history tracking, badge generation, and bilingual report output (English/Korean).

## Tech Stack
- Bash (scripts, hooks, tests)
- jq (JSON processing)
- Python 3 (JSON validation, scoring helpers)
- Claude Code Plugin System (skills, agents, commands, hooks)

## Project Structure
```
.claude-plugin/       - Plugin manifest (plugin.json — metadata only, auto-discovery)
agents/               - Subagents for Full mode (collector, evaluators, synthesizer)
commands/             - Slash commands (harness-eval, quick, standard, full, compare)
docs/                 - Architecture docs, ADRs, runbooks
  decisions/          - Architecture Decision Records
  runbooks/           - Operational runbooks
hooks/                - Plugin hooks
  hooks.json          - Hook event registration (Stop)
  post-eval-badge.sh  - Badge generation on evaluation completion
scripts/              - Bash scripts (scoring, static-analysis, history, badge, setup)
skills/               - Evaluation skills (subdirectory/SKILL.md convention)
  quick/SKILL.md      - Fast checklist evaluation
  standard/SKILL.md   - Static + dynamic analysis evaluation
  full/SKILL.md       - Multi-agent orchestrator
  compare/SKILL.md    - Evaluation history comparison
templates/            - Checklist and report templates (bilingual)
tests/                - Test suite
  test-scoring.sh     - Scoring script tests (15 tests)
  test-static-analysis.sh - Static analysis tests (23 tests)
  test-history.sh     - History management tests (19 tests)
  harness-run-all.sh  - Harness validation runner (104 tests)
  hooks/              - Hook validation tests
  structure/          - Plugin structure tests
  fixtures/           - 4-level maturity mock projects
```

Note: This plugin lives inside a monorepo at `plugins/harness-eval/`. The repo root contains `.claude-plugin/marketplace.json` and dev tools in `.claude/`.

## Conventions
- All scripts: `$1` = target project root, `HARNESS_EVAL_ROOT` env var = plugin root
- Script output: JSON to stdout, human logs to stderr
- Exit codes: 0 = success, 1 = issues found, 2 = script error
- All scripts check for `jq` dependency at startup
- Skills use `skills/<name>/SKILL.md` directory convention (auto-discovered by Claude Code)
- Hooks registered via `hooks/hooks.json` (not in plugin.json)
- plugin.json contains metadata only — no skills/agents/commands/hooks arrays
- Reports saved to `.harness-eval/reports/` in target project as separate en/ko files
- Bilingual: all reports generate English + Korean output

## Key Commands
```bash
# Run evaluation script tests (from plugin directory)
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-static-analysis.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-history.sh

# Run harness validation tests (from plugin directory, resolves to repo root)
bash tests/harness-run-all.sh
bash tests/harness-run-all.sh hooks       # Hook tests only
bash tests/harness-run-all.sh structure   # Structure tests only

# Run evaluation scripts
HARNESS_EVAL_ROOT=$(pwd) bash scripts/scoring.sh <target>
HARNESS_EVAL_ROOT=$(pwd) bash scripts/static-analysis.sh <target>
HARNESS_EVAL_ROOT=$(pwd) bash scripts/history.sh <target>
bash scripts/badge.sh <target>

# Validate JSON
python3 -m json.tool templates/checklist.json
python3 -m json.tool .claude-plugin/plugin.json

# Check bash syntax
find . -name "*.sh" -not -path "./.git/*" -exec bash -n {} \;
```

---

## Auto-Sync Rules

Rules below are applied automatically after Plan mode exit and on major code changes.

### Post-Plan Mode Actions
After exiting Plan mode (`/plan`), before starting implementation:

1. **Architecture decision made** -> Update `docs/architecture.md`
2. **Technical choice/trade-off made** -> Create `docs/decisions/ADR-NNN-title.md`
3. **New module added** -> Create `CLAUDE.md` in that module directory
4. **Operational procedure defined** -> Create runbook in `docs/runbooks/`
5. **Changes needed in this file** -> Update relevant sections above

### Code Change Sync Rules
- New directory under plugin root -> Must create `CLAUDE.md` alongside
- Script added/changed in `scripts/` -> Update `scripts/CLAUDE.md`
- Agent added/changed in `agents/` -> Update `agents/CLAUDE.md`
- Skill added/changed in `skills/` -> Update `skills/CLAUDE.md`
- Template changed in `templates/` -> Update `templates/CLAUDE.md`
- Hook added/changed -> Update `hooks/CLAUDE.md` and `hooks/hooks.json`
- Command added/changed -> Update `commands/CLAUDE.md`

### ADR Numbering
Find the highest number in `docs/decisions/ADR-*.md` and increment by 1.
Format: `ADR-NNN-concise-title.md`
