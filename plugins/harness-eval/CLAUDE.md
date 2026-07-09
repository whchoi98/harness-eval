# Project Context

> **Development-time context only.** This plugin-root `CLAUDE.md` is **not** loaded as
> project context for installed plugin users (`claude plugin validate` warns about this).
> It documents conventions for developers working in this monorepo. The runtime invocation
> contract that consumers actually need — `$1` = target project root, `HARNESS_EVAL_ROOT`
> env var, exit-code meanings (0/1/2), and the "JSON to stdout, logs to stderr" rule — is
> duplicated inline in each `skills/<name>/SKILL.md`, which *is* delivered to users. Keep
> those SKILL.md contracts in sync when changing script conventions here.

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
  test-scoring.sh     - Scoring script tests (24 tests)
  test-static-analysis.sh - Static analysis tests (26 tests)
  test-history.sh     - History management tests (19 tests)
  harness-run-all.sh  - Harness validation runner (190 total: 121 harness-validation checks + re-runs the 3 suites above)
  hooks/              - Hook validation tests
  structure/          - Plugin structure tests
  fixtures/           - 4-level maturity mock projects
```

Note: This plugin lives inside a monorepo at `plugins/harness-eval/`. The repo root contains `.claude-plugin/marketplace.json` and dev tools in `.claude/`.

## Conventions
- All scripts: `$1` = target project root. `scoring.sh`/`static-analysis.sh` use `HARNESS_EVAL_ROOT` (plugin root) if set, otherwise auto-detect it from the script location; `history.sh`/`badge.sh` do not read it
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
HARNESS_EVAL_ROOT=$(pwd) bash scripts/history.sh <target> list   # <target> first, then save|list|compare
bash scripts/badge.sh <target>

# Validate JSON
python3 -m json.tool templates/checklist.json
python3 -m json.tool .claude-plugin/plugin.json

# Check bash syntax
find . -name "*.sh" -not -path "./.git/*" -exec bash -n {} \;
```

---

## Module Notes

> These notes previously lived in `commands/CLAUDE.md` and `agents/CLAUDE.md`. Claude Code
> auto-discovers **every** `.md` file under `commands/` and `agents/` as a component, so a
> `CLAUDE.md` in either directory would register as a bogus command/agent. Those files were
> removed and their content consolidated here. Do **not** re-create `CLAUDE.md` (or any other
> non-component `.md`) inside `commands/` or `agents/`.

### Commands module notes

Role: User-facing slash commands for evaluation. Each `.md` file under `commands/` is
auto-discovered by Claude Code as a `/harness-eval:<name>` command.

Key files:
- `harness-eval.md` — Main entry point with `argument-hint: [quick|standard|full|compare]`
- `quick.md` — Direct quick evaluation command
- `standard.md` — Direct standard evaluation command
- `full.md` — Direct full evaluation command
- `compare.md` — Direct compare evaluation command

Rules:
- Commands are auto-discovered from `commands/` (not registered in `plugin.json`).
- Must include frontmatter with `description` and `allowed-tools` fields.
- `argument-hint` in frontmatter makes options visible in the Claude Code UI.
- Each mode command activates the corresponding skill from `skills/<mode>/SKILL.md`.

### Agents module notes

Role: Subagents for Full mode evaluation. Spawned in parallel by `skills/full/SKILL.md` to
perform qualitative analysis of target projects.

Key files:
- `collector.md` — Gathers target project information (file structure, settings, scripts)
- `safety-evaluator.md` — Evaluates tool scope, deny lists, secret pattern safety
- `completeness-evaluator.md` — Evaluates event coverage, error recovery, doc completeness
- `design-evaluator.md` — Evaluates architecture quality, modularity, output schemas
- `synthesizer.md` — Aggregates evaluator results into final weighted report

Rules:
- All agents receive collector output as input context.
- Evaluators produce component-level scores (0-10) with structured justification.
- Synthesizer applies weighted averaging per `harness-evaluation-framework.md`.
- Output must follow the report template in `templates/report-component.md`.

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
- New directory under plugin root -> Create `CLAUDE.md` alongside, **except** in directories
  Claude Code auto-discovers `.md` files from (`commands/`, `agents/`). Those must not contain
  a `CLAUDE.md` — document them in the "Module Notes" section of this file instead.
- Script added/changed in `scripts/` -> Update `scripts/CLAUDE.md`
- Agent added/changed in `agents/` -> Update the "Agents module notes" subsection above
  (do **not** create `agents/CLAUDE.md`)
- Skill added/changed in `skills/` -> Update `skills/CLAUDE.md`
- Template changed in `templates/` -> Update `templates/CLAUDE.md`
- Hook added/changed -> Update `hooks/CLAUDE.md` and `hooks/hooks.json`
- Command added/changed -> Update the "Commands module notes" subsection above
  (do **not** create `commands/CLAUDE.md`)

### ADR Numbering
Find the highest number in `docs/decisions/ADR-*.md` and increment by 1.
Format: `ADR-NNN-concise-title.md`
