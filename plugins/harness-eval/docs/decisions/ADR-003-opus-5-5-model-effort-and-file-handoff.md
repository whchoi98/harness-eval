# ADR-003: Per-Agent Model and Effort for Claude Opus 5.5, and File Handoff in Full Mode

## Status
Accepted (v0.3.0, 2026-09-23)

## Context
Full mode runs five subagents (collector, safety-evaluator, completeness-evaluator,
design-evaluator, synthesizer). Before v0.3.0 three of them ran on `sonnet` and two on
`opus`, and none set `effort`. Four platform facts, checked against Claude Code 2.1.280 and
the Claude Opus 5.5 migration notes, made that setup a poor fit:

- **Effort is the cost lever.** Claude Opus 5.5 always thinks, and `effort` is the only
  control over how much. Its API default is `medium` (Claude Opus 5 defaults to `high`). In
  Anthropic's testing, Opus 5.5 at `medium` exceeds Claude Opus 5 at `high` on coding and
  knowledge-work evaluations, at $4 / $20 per MTok, so cost per completed task depends more
  on the effort level than on the model tier.
- **Subagents inherit the session effort.** An agent with no `effort` in its frontmatter
  runs at the caller's session effort. The depth and cost of a Full evaluation therefore
  varied with each user's setting, anywhere from `low` to `max`, and scores were not
  comparable between users.
- **Only the final message comes back.** A subagent returns only its last message to the
  orchestrator; text written before a tool call is lost. The old flow inlined the script
  JSON and the collector artifact into each prompt and had the model re-type JSON
  (`echo '<scoring-json>' | history.sh save`), so every large payload went through model
  output at least once.
- **Arithmetic and ownership were in prose.** The synthesizer computed the 12-dimension
  weighted average itself, both the synthesizer and the orchestrator had steps for saving
  history and running `badge.sh` ("if not already done"), and Full ran `badge.sh`
  unconditionally, rewriting README.md even though v0.2.0 had made the Stop-hook badge
  opt-in.

## Options Considered

### Option 1: Pin exact model IDs (e.g. `model: claude-opus-5-5`)
- **Pros**: The same model on every provider, including Microsoft Foundry, where the
  `opus` alias resolves to Claude Opus 4.6 in Claude Code 2.1.280.
- **Cons**: A pinned ID goes stale at the next release and silently keeps an old model,
  and it fails where that ID is not offered. The plugin's own design rubric (Evolvability,
  "Model-Change Resilience") tells users to prefer aliases for this reason, so the plugin
  should follow it.

### Option 2: Sonnet for the mechanical agents (collector, synthesizer)
- **Pros**: Lower per-token price.
- **Cons**: On Opus 5.5 the first lever is effort, not the tier. A low-effort Opus run is
  the cheaper-per-task candidate for tool-heavy collection, and mixing families adds a
  second variable to every score comparison. Where Claude Code maps `sonnet` to an older
  model on third-party providers, it would also change behavior by platform.

### Option 3: Keep inline handoff and fix only the prompts
- **Pros**: No new files in the target project and no new script.
- **Cons**: Large payloads still pass through model output. The weighted-average
  arithmetic stays in prose, and the ambiguous history and badge ownership remains.

### Option 4: Replace the collector with a script (deferred)
- **Pros**: The inventory is largely determined by its inputs, so a script could produce
  it with no model call.
- **Cons**: It needs a new script that reproduces every artifact section (frontmatter
  fields, settings keys, hook registrations in both hook schemas, plugin roots) plus its
  own tests, which is larger than this release. Deferred as a follow-up; the collector runs
  at `effort: low` in the meantime.

### Option 5: Merge the three evaluators into one agent (deferred)
- **Pros**: Fewer model calls and one read of the artifact instead of three.
- **Cons**: The three rubrics are large, and merging them trades the independence of the
  evaluations and their parallelism for one very long prompt. Deferred until the cost and
  score variance of the current split have been measured on the fixtures.

## Decision

**Models and effort.** Every Full-mode agent uses the `opus` alias with an explicit effort
in its frontmatter: collector `low`, completeness-evaluator `medium`, design-evaluator
`medium`, safety-evaluator `high`, synthesizer `medium`. The Full skill passes neither model
nor effort, so frontmatter is the single source. The Quick and Compare commands run at
`effort: low` (their skills carry the same value as a record of intent; it does not apply on
the plugin's entry points, which read SKILL.md with the Read tool). Standard, Full's orchestrator,
and the router keep the session effort, so the router runs even its default quick at the
session effort.
The per-agent reasons are recorded in the plugin `CLAUDE.md` (Agents module notes), and
agent bodies contain no maintainer rationale or version pins. The repo's dev agents
(`.claude/agents/code-reviewer.md`, `security-auditor.md`) follow the same rule at
`opus` / `medium`.

**File handoff.** Full mode keeps its intermediate data in `<project>/.harness-eval/run/`
and passes absolute paths between phases. The one exception is the three evaluator results:
the evaluators are read-only and cannot write files, so the orchestrator relays their final
messages to the synthesizer inline, verbatim.

1. The orchestrator runs `static-analysis.sh` and `scoring.sh --mode standard` in parallel
   into `static.json` and `score.json`. A script that exits 2 or leaves an empty file is
   replaced by the line `SCRIPT_FAILED: <script> produced no output`.
2. The collector writes `artifact.md` and returns `ARTIFACT_WRITTEN: <path>` plus its Raw
   Summary. Without that line and a non-empty file, Full falls back to a Standard-format
   report from the script results: the orchestrator saves `score.json` to history (mode
   `standard`, since it is the checklist score) and writes
   `<EVAL_ID>-full-fallback-{en,ko}.md`.
3. The three evaluators run in parallel and read the three files by path. They stay
   read-only (`Read, Glob, Grep`) because they read untrusted target content.
4. The synthesizer takes the four Basic Quality scores from `static.json` and the other
   eight from the evaluators' `## Scores` tables. It passes them to `scripts/aggregate.sh`
   in a heredoc and writes the record to `record.json` by redirect (no pipe, so
   `aggregate.sh`'s exit status reaches the model), reads earlier history (the trend comes
   from the last five Full runs), and saves the record. On the normal path it is the only
   component that saves Full history or writes the Full report files
   (`<EVAL_ID>-full-en.md`, `<EVAL_ID>-full-ko.md`), and it ends with the `EVAL_ID`,
   `REPORT_EN`, `REPORT_KO`, `SCORE`, and `MISSING` lines.
5. The orchestrator reads both report files and presents them in full.

**Deterministic aggregation.** `scripts/aggregate.sh` averages each category's non-null
dimensions, applies the 0.50 / 0.25 / 0.25 weights renormalized over the categories that
have scores, rounds with `printf "%.1f"`, and emits the canonical history record with
per-dimension `status` and `missing`. The grade thresholds exist once, in
`scripts/lib/grade.sh`, and both `scoring.sh` and `aggregate.sh` source it; `scoring.sh`
output is unchanged.

**Badge.** No mode runs `badge.sh`. The README badge changes only through the opt-in Stop
hook, which acts once per saved evaluation (a `latest.json` newer than its
`.harness-eval/.badge-seen` marker), or through the command the orchestrator prints.

## Consequences

### Positive
- Evaluation depth and cost no longer follow the user's `/effort` or `effortLevel` setting,
  so default runs are comparable across users.
- Script output and the collector artifact pass by path, so the model never re-types them;
  a failed step is visible as a missing file or marker, and stale files from an earlier run
  cannot be reused.
- The overall score and grade are computed by code that `tests/test-aggregate.sh` covers,
  including grade parity with `scoring.sh`.
- History is saved exactly once per Full run, and README.md is never modified without
  opt-in.

### Negative
- On Microsoft Foundry, Claude Code 2.1.280 resolves `opus` to Claude Opus 4.6 (and an LLM
  gateway resolves it to Claude Opus 4.7). Users there have to set
  `ANTHROPIC_DEFAULT_OPUS_MODEL` to get Claude Opus 5.5; the README documents this.
- `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` replaces every agent's model, and scores produced that
  way are not comparable with default runs.
- `CLAUDE_CODE_EFFORT_LEVEL` (including `auto` and `unset`, which fall back to the model
  default) takes precedence over the agents' `effort`, and an effort cap (`maxEffortLevel`
  in settings, or an organization cap) lowers any agent above it; such runs are not
  comparable with default runs. The README documents this.
- Two payloads still pass through the orchestrator's output, at the session's model and
  effort: the three evaluator results, which it relays into the synthesizer's prompt, and
  both reports, which it presents in full in Phase 4.
- Full now writes files into the target's `.harness-eval/run/` (and a self-ignoring
  `.harness-eval/.gitignore`), and the collector and synthesizer hold `Bash` and `Write`. A
  subagent `tools` list grants whole tools, so the prompts limit what they run (the
  collector keeps Bash read-only; the synthesizer names its exact commands) and the
  session's permission rules enforce it. `/harness-eval:full` pre-approves the
  orchestrator's own Bash commands through `allowed-tools` (see `SECURITY.md`).
- Full history records gain `categories`, `status`, and `missing`, and the new static checks
  add Correctness entries to every run, so score trends step at v0.3.0. `history.sh compare`
  compares the last two records whatever their mode, so a Full record next to a Standard one
  compares different scales; the compare skill warns about mixed modes.

### Measured run time and cost
Measured on 2026-09-23 with the modified plugin, running
`claude -p "/harness-eval:<mode>" --plugin-dir plugins/harness-eval --model opus` on a copy
of `tests/fixtures/production-project`. Every model call, in the main session and in all
five subagents, ran on `claude-opus-5-5`. Run 1 was taken before the v0.3.0 review fixes and
run 2 after them.

| Mode | Run 1 | Run 2 |
|------|-------|-------|
| Quick | ~28 s of a 98 s session ($0.49) | ~28 s ($0.64 for the session, including an external Stop-hook review loop) |
| Standard `--static-only` | 117 s ($0.81) | 60 s ($0.62) |
| Full | 7 min 4 s from start to report presentation ($3.25 for the session) | 5 min 11 s ($3.27) |
| Compare | 164 s ($0.57) | not measured |

In run 1, Full dispatched all five agents, saved history once, and wrote the English and
Korean reports, and README.md was left untouched. The raw logs show more wall-clock time than
these figures; the difference came from an unrelated user-level Stop hook (a third-party
review gate) that re-prompted after each response. The documented "~30s" for Quick and
"~5-10min" for Full therefore hold at the new effort levels. Standard was measured only with
`--static-only`, so its dynamic-analysis phase is not covered. These runs measure the chosen
effort levels on one fixture; they do not compare them with other levels.
`docs/runbooks/model-change.md` repeats this measurement when the model changes.
