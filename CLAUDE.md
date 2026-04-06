# Project Context

## Overview
harness-eval: Claude Code harness engineering quality evaluator plugin. Provides systematic 3-tier evaluation (Quick/Standard/Full) with multi-agent design review, history tracking, and badge generation.

## Tech Stack
- Bash (scripts, hooks, tests)
- jq (JSON processing)
- Python 3 (JSON validation, scoring helpers)
- Claude Code Plugin System (skills, agents, commands, hooks)

## Project Structure
```
.claude-plugin/     - Plugin manifest (plugin.json with marketplace metadata)
agents/             - Subagents for Full mode (collector, evaluators, synthesizer)
commands/           - User-facing slash command (/harness-eval)
docs/               - Architecture docs, ADRs, runbooks
  decisions/        - Architecture Decision Records
  runbooks/         - Operational runbooks
hooks/              - Plugin hooks (post-eval-badge.sh)
scripts/            - Bash scripts (scoring, static-analysis, history, badge)
skills/             - Evaluation skills (quick, standard, full, compare)
templates/          - Checklist and report templates
tests/              - Test suite with 4-level fixtures
  fixtures/         - Mock projects (minimal, functional, robust, production)
  hooks/            - Hook validation tests
  structure/        - Plugin structure tests
.claude/            - Development-time Claude settings, hooks, skills
  hooks/            - Dev hooks (doc-sync, secret-scan, session-context, notify)
  skills/           - Dev skills (code-review, refactor, release, sync-docs)
  commands/         - Dev commands (review, test-all, deploy)
  agents/           - Dev agents (code-reviewer, security-auditor)
```

## Conventions
- All scripts: `$1` = target project root, `HARNESS_EVAL_ROOT` env var = plugin root
- Script output: JSON to stdout, human logs to stderr
- Exit codes: 0 = success, 1 = issues found, 2 = script error
- All scripts check for `jq` dependency at startup
- Bilingual: Korean primary, English secondary in docs
- Plugin paths in `.claude-plugin/plugin.json` must match actual file locations

## Key Commands
```bash
# Run tests
bash tests/run-all.sh                    # All tests
bash tests/run-all.sh hooks              # Hook tests only
bash tests/run-all.sh structure          # Structure tests only

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
- Hook added/changed -> Update `hooks/CLAUDE.md` and verify `.claude-plugin/plugin.json` registration
- `.claude-plugin/plugin.json` changed -> Verify all referenced paths exist

### ADR Numbering
Find the highest number in `docs/decisions/ADR-*.md` and increment by 1.
Format: `ADR-NNN-concise-title.md`
