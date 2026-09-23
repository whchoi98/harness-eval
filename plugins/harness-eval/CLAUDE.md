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
agents/               - Subagents for Full mode (collector, 3 evaluators, synthesizer)
commands/             - Slash commands (harness-eval, quick, standard, full, compare)
docs/                 - Architecture docs, ADRs, runbooks
  decisions/          - Architecture Decision Records (ADR-001 .. ADR-003)
  runbooks/           - Operational runbooks (release.md, model-change.md)
hooks/                - Plugin hooks
  hooks.json          - Hook event registration (Stop)
  post-eval-badge.sh  - Opt-in README badge update on Stop
scripts/              - Bash scripts (scoring, static-analysis, aggregate, history, badge, setup)
  aggregate.sh        - Full-mode 12-dimension aggregation (stdin JSON -> history record)
  lib/grade.sh        - Sourced helper: the single definition of the grade thresholds
skills/               - Evaluation skills (subdirectory/SKILL.md convention)
  quick/SKILL.md      - Fast checklist evaluation
  standard/SKILL.md   - Static + dynamic analysis evaluation
  full/SKILL.md       - Multi-agent orchestrator
  compare/SKILL.md    - Evaluation history comparison
templates/            - checklist.json (scoring input) + reference report templates (not read at runtime)
tests/                - Test suite
  test-scoring.sh     - Scoring script tests (24 tests)
  test-static-analysis.sh - Static analysis tests (107 tests)
  test-history.sh     - History management tests (38 tests)
  test-aggregate.sh   - Aggregation and grade-parity tests (74 tests)
  harness-run-all.sh  - Harness validation runner (447 total: 204 harness-validation checks + re-runs the 4 suites above, 243 tests)
  hooks/              - Dev hook, secret-pattern, and plugin Stop hook tests
  structure/          - Plugin structure and Full-mode contract tests
  fixtures/           - 4 frozen maturity projects + nested-hooks-project + model-era-project
```

Note: This plugin lives inside a monorepo at `plugins/harness-eval/`. The repo root contains `.claude-plugin/marketplace.json` and dev tools in `.claude/`.

## Conventions
- All scripts: `$1` = target project root, except `aggregate.sh`, which reads its input from stdin and takes no arguments. `scoring.sh`/`static-analysis.sh` use `HARNESS_EVAL_ROOT` (plugin root) if set, otherwise auto-detect it from the script location; `history.sh`/`badge.sh`/`aggregate.sh` do not read it
- Script output: JSON to stdout, human logs to stderr
- Exit codes: 0 = success, 1 = issues found, 2 = script error (`aggregate.sh` uses only 0 and 2)
- All scripts check for `jq` dependency at startup
- Grade thresholds exist once, in `scripts/lib/grade.sh` (`score_to_grade`), sourced by `scoring.sh` and `aggregate.sh`; change them only there
- Skills use `skills/<name>/SKILL.md` directory convention (auto-discovered by Claude Code)
- Hooks registered via `hooks/hooks.json` (not in plugin.json)
- plugin.json contains metadata only — no skills/agents/commands/hooks arrays
- Reports saved to `.harness-eval/reports/` in target project as separate en/ko files
- Intermediate files go to `.harness-eval/run/` in the target project: Full hands `static.json`, `score.json`, `artifact.md`, and `record.json` between phases by absolute path, and Standard tees its scoring output to `standard-score.json`. Each run rewrites them, so nothing from an earlier run is reused. The three evaluator results are the exception: the orchestrator passes them to the synthesizer inline, verbatim
- `.harness-eval/` ignores itself in git: Full Step 1.1, Standard Phase 3, and `history.sh save` create `.harness-eval/.gitignore` containing `*` when there is none, and leave an existing file or symlink of that name alone. Quick does not create it
- No evaluation mode runs `badge.sh`; the README badge changes only through the opt-in Stop hook or when the user runs `badge.sh`
- Bilingual: all reports generate English + Korean output

## Key Commands
```bash
# Run evaluation script tests (from plugin directory)
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-static-analysis.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-history.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-aggregate.sh

# Run harness validation tests (from plugin directory, resolves to repo root)
bash tests/harness-run-all.sh
bash tests/harness-run-all.sh hooks       # Hook tests only
bash tests/harness-run-all.sh structure   # Structure tests only

# Run evaluation scripts
HARNESS_EVAL_ROOT=$(pwd) bash scripts/scoring.sh <target>
HARNESS_EVAL_ROOT=$(pwd) bash scripts/static-analysis.sh <target>
bash scripts/aggregate.sh < dimensions.json   # {"dimensions": {<12 keys>: 0-10 | null}}
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
- `harness-eval.md` — Router with `argument-hint: "[quick|standard|full|compare] [--static-only]"`; the first argument picks the mode (default `quick`) and the rest pass through
- `quick.md` — Direct quick evaluation command (`effort: low`)
- `standard.md` — Direct standard evaluation command (`argument-hint: "[--static-only]"`)
- `full.md` — Direct full evaluation command
- `compare.md` — Direct compare evaluation command (`effort: low`)

Rules:
- Commands are auto-discovered from `commands/` (not registered in `plugin.json`).
- Must include frontmatter with `description` and `allowed-tools` fields. Quote `argument-hint` values: an unquoted `[a|b]` parses as a YAML list.
- `argument-hint` in frontmatter makes options visible in the Claude Code UI.
- Each mode command shares its `harness-eval:<mode>` name with a skill, and Claude Code shows the command's description for that name, so routing text belongs in the command's `description`. The command body reads `${CLAUDE_PLUGIN_ROOT}/skills/<mode>/SKILL.md` and follows it, and tells the model the plugin path, to use in the commands it runs and in any command it shows the user, because `${CLAUDE_PLUGIN_ROOT}` is not substituted inside a file read with the Read tool.
- `quick` and `compare` set `effort: low` in the command. Their skills carry the same value, but it does not apply on the plugin's entry points: each command reads SKILL.md with the Read tool, so only the command's `effort` counts. Keep the skill value in sync as a record of intent. `standard`, `full`, and the router set no effort, so they run at the session effort, and the router runs every mode that way, including its default quick; it tells the model to follow the quick and compare steps without extra investigation.
- `Task` in `allowed-tools` is the legacy alias of the Agent tool and still pre-approves subagent dispatch.

### Agents module notes

Role: Subagents for Full mode evaluation, dispatched by `skills/full/SKILL.md` with the
Agent tool. Each returns only its final message; larger results travel as files under the
target's `.harness-eval/run/`.

Key files:
- `collector.md` — Inventories the target's harness (settings, hooks, skills, agents, commands, CLAUDE.md files, tests, plugin manifests), writes `artifact.md`, and returns `ARTIFACT_WRITTEN: <path>` plus the Raw Summary JSON. It counts as skills only `<skills dir>/<name>/SKILL.md`, the file Claude Code loads, and lists other `.md` files under a skills directory below the table as `Supporting file:` or `Not loaded:` lines with no model or effort, so its skill count means loaded skills
- `safety-evaluator.md` — Safety (qualitative supplement to the static score) + Cost Efficiency (model/effort fit, tool lists, redundancy, token and delegation spend)
- `completeness-evaluator.md` — Actionability, Testability, Contract-Based Testing
- `design-evaluator.md` — Agent Communication, Context Management, Feedback Loop Maturity, Evolvability
- `synthesizer.md` — Scores the 12 dimensions with `scripts/aggregate.sh`, saves the evaluation to history, and writes `<EVAL_ID>-full-en.md` and `<EVAL_ID>-full-ko.md`

Model and effort (frontmatter is the single source; the Full skill passes neither):

| Agent | model / effort | Reason |
|---|---|---|
| collector | opus / low | Mechanical, tool-heavy inventory with little judgment |
| completeness-evaluator | opus / medium | Rubric judgment; depth pinned so it does not follow the caller's session effort |
| design-evaluator | opus / medium | Architecture judgment; pinned for the same reason |
| safety-evaluator | opus / high | Safety and cost findings carry the most risk when missed, so one level more depth |
| synthesizer | opus / medium | Reconciles three evaluator outputs and writes two long reports; the arithmetic is in `aggregate.sh` |
| code-reviewer, security-auditor (repo-root `.claude/agents/`) | opus / medium | Review depth pinned instead of inherited; try `low` only after comparing results on a known diff |

A pinned `effort` keeps the depth independent of `/effort` and the settings `effortLevel`, but `CLAUDE_CODE_EFFORT_LEVEL` (including `auto` and `unset`) takes precedence over it, and an effort cap (`maxEffortLevel` in settings, or an organization cap) lowers an agent above the cap. The README "Models and effort" section tells users that such runs are not comparable with default runs.

Rules:
- Model and effort are set per agent in frontmatter (`model`, `effort`). When changing them, record the pair and a one-line reason in the table above. Lower effort before changing the model, and compare on the fixtures before adopting; `docs/runbooks/model-change.md` has the live-run recipe and the other checks to repeat when Claude's model line changes. `tests/structure/test-plugin-structure.sh` fails any agent without `name`, `description`, `model`, and `effort`, any agent whose `model` is neither an alias nor a served ID or whose `effort` is neither an accepted level nor an integer (both read from `scripts/static-analysis.sh`'s tables), and a `model-config` or `agent-format` result other than PASS when `static-analysis.sh` runs on this repository (results for the gitignored, per-developer `.claude/settings.local.json` are left out).
- Use model aliases, not version-pinned IDs. How `opus` resolves differs by provider, and users can remap or force subagent models through environment variables; the README "Models and effort" section explains this to users, so update it whenever this table changes. See ADR-003.
- Only the collector and synthesizer can write (both have `Bash` and `Write`, and write only under the target's `.harness-eval/`). The three evaluators stay read-only (`Read, Glob, Grep`) because they read untrusted target content, and they leave `.harness-eval/`, `.git/`, and `node_modules/` out of their own scans. A subagent `tools` list grants whole tools, so a Bash restriction lives in the agent's prompt, with the session's permission rules as enforcement: the collector keeps Bash read-only apart from creating the artifact's directory, and the synthesizer names the exact commands of its Steps 1-5. When a synthesizer step gains or loses a command, update that list and the one in `SECURITY.md`; no test compares them.
- The collector's artifact is saved in the target project, so it lists settings `env` keys with the values redacted except for model, provider, effort, thinking, and output-limit settings, and it redacts credential-shaped strings elsewhere.
- Evaluators receive absolute paths to `artifact.md`, `static.json`, and `score.json` (or a `SCRIPT_FAILED: <script> produced no output` line in place of a path) and return the Agent Communication Protocol format. Their `## Scores` table and dimension names are what the synthesizer parses; keep them stable. `tests/structure/test-plugin-structure.sh` checks both sides of these strings, and of the markers and final-message lines below.
- Evaluator recommendations use `— Dimension: <name>; expected gain: +<N> (moves the score into the <band> band) | not estimated`, and the synthesizer's roadmap copies that gain verbatim without overall-score arithmetic. A safety-evaluator Safety item is labelled as its supplementary score.
- The synthesizer is the only component that saves Full history and writes the Full report files on the normal path; when the collector fails, the Full skill itself saves the Standard checklist score and writes the `full-fallback` reports. The synthesizer writes `record.json` by redirect, so `aggregate.sh`'s exit status reaches it, and it reads history as the last five Full runs (for the trend) plus the last five runs of any mode. It does not run `badge.sh`. Its final message is the `EVAL_ID` / `REPORT_EN` / `REPORT_KO` / `SCORE` / `MISSING` lines that the Full skill parses, plus at most one `NOTE:` line (with `SCORE: none` when nothing could be scored).
- Scoring lives in `scripts/aggregate.sh` and the report format in `agents/synthesizer.md`. `harness-evaluation-framework.md` restates the scoring formula (§3.2) for readers, and its §5 report layout is illustrative; `templates/report-*.md` are not read at runtime.
- Agent bodies hold no maintainer rationale and no model-version pins; that rationale goes here.

---

## Auto-Sync Rules

When a change adds or alters a component listed below, update its doc in the same change. Write an ADR (`plugins/harness-eval/docs/decisions/`) or a runbook (`plugins/harness-eval/docs/runbooks/`) only when the change records a real architectural decision or operational procedure, or the user asks for one.

### Code Change Sync Rules
- New top-level directory under plugin root -> Create `CLAUDE.md` alongside, **except** in directories
  Claude Code auto-discovers `.md` files from (`commands/`, `agents/`). Those must not contain
  a `CLAUDE.md` — document them in the "Module Notes" section of this file instead.
  Subdirectories (e.g. `scripts/lib/`) are documented in their parent module's `CLAUDE.md`.
- Script added/changed in `scripts/` (including `scripts/lib/`) -> Update `scripts/CLAUDE.md`
- Agent added/changed in `agents/` -> Update the "Agents module notes" subsection above
  (do **not** create `agents/CLAUDE.md`)
- Skill added/changed in `skills/` -> Update `skills/CLAUDE.md`
- Template changed in `templates/` -> Update `templates/CLAUDE.md`
- Hook added/changed -> Update `hooks/CLAUDE.md` and `hooks/hooks.json`
- Command added/changed -> Update the "Commands module notes" subsection above
  (do **not** create `commands/CLAUDE.md`)
- Tests added or removed -> Update the counts in this file, `tests/CLAUDE.md`, `README.md`
  (both halves), and `docs/onboarding.md` at the repo root, taken from an actual
  `bash tests/harness-run-all.sh` run

### ADR Numbering
Find the highest number in `plugins/harness-eval/docs/decisions/ADR-*.md` and increment by 1
(the repo-root `docs/decisions/` holds only a template).
Format: `ADR-NNN-concise-title.md`
