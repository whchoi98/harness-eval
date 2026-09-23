# Runbook: Re-check harness-eval When Claude's Model Line Changes

## Overview
harness-eval depends on the current Claude models in three places, and none of them fails a
test when a model changes:

- **Its own prompts.** The agent, skill, and command bodies are written for how the current
  model follows instructions.
- **Its agents' model and effort.** Each Full-mode agent pins the `opus` alias and an
  `effort` level in frontmatter (ADR-003). What the alias resolves to, and what each effort
  level costs, change with the model and the Claude Code version.
- **What it checks in other projects.** The `model-config` check in
  `scripts/static-analysis.sh` scores model IDs, effort values, and thinking settings against
  tables of served, deprecated, and retired models, and the evaluator rubrics name dated
  prompt patterns and thinking behavior of specific models.

This runbook re-checks all three, runs the test suite, runs the plugin live on a fixture, and
records the measured time and cost.

## When to Use
- A Claude model is released, deprecated, or retired (the claude-api skill's
  `shared/models.md` changes).
- A Claude Code release changes what `opus`, `sonnet`, or `haiku` resolves to on a provider,
  or how `effort` and the thinking settings are read.
- Before changing any agent's `model` or `effort`.

## Prerequisites
- Claude Code signed in to an account that can run the target model (`claude --version`),
  plus Bash 4+, `jq`, and `git`.
- `shellcheck` on `PATH`, so the runner's shellcheck stage runs instead of being skipped.
- The claude-api skill that ships with Claude Code: `shared/models.md` (model IDs and status),
  `shared/model-migration.md` (per-model migration notes), and `shared/prompt-audit.md` (the
  prompt audit).
- Budget for the live run. One Quick, Standard `--static-only`, Full, and Compare pass on the
  production fixture cost about $5 on Claude Opus 5.5 (ADR-003, "Measured run time and cost").

## Procedure

### 1. Re-run the prompt audit on the plugin's prompts
Run the claude-api skill's prompt audit (`/claude-api prompt-audit`) with the new model as the
target, scoped to `plugins/harness-eval/agents/`, `plugins/harness-eval/skills/`,
`plugins/harness-eval/commands/`, and the dev harness under `.claude/`. Read the new model's
section of `shared/model-migration.md` alongside it, because each migration checklist also
lists text to remove. Apply the findings you can tie to a named pattern and to documented
behavior of the new model, and write prompts as plain statements with their reasons.

Keep the strings other components parse: `ARTIFACT_WRITTEN`, `SCRIPT_FAILED`,
`AGENT_FAILED`, the evaluators' `## Scores` tables and dimension names, the synthesizer's
`EVAL_ID` / `REPORT_EN` / `REPORT_KO` / `SCORE` / `MISSING` lines, and its heredoc keys.
`tests/structure/test-plugin-structure.sh` checks both sides of each.

The plugin also judges other projects against the current model. When the migration notes
name a new dated pattern, or change what an effort level or thinking setting does, update
these together:
- design-evaluator §2.5 "Instruction Fit for Current Models" and its grep list
- safety-evaluator §2.1 "Model and Effort Selection" (Cost Efficiency)
- `harness-evaluation-framework.md` §2.1, §2.7, and §2.10

### 2. Review each agent's model and effort
List what is pinned now:

```bash
grep -H -E '^(model|effort):' plugins/harness-eval/agents/*.md .claude/agents/*.md
grep -H -E '^effort:' plugins/harness-eval/commands/*.md plugins/harness-eval/skills/*/SKILL.md
```

- For each agent, decide from the new model's effort guidance whether the pinned level still
  fits the job in the Agents module notes table of `plugins/harness-eval/CLAUDE.md`. Lower
  effort before changing the model, and measure before adopting a change (step 5).
- Check what `opus` resolves to on each provider in the Claude Code version you release
  against (its model-configuration docs and release notes): the Anthropic API, Claude
  Platform on AWS, Amazon Bedrock, Google Vertex AI, Microsoft Foundry, and LLM gateways. If a
  provider maps the alias to an older model, update the provider notes in the README "Models
  and Effort" section (both halves) and the Negative consequences in the ADR. If the alias no
  longer selects the intended model on the main providers, revisit ADR-003 instead of pinning
  an ID in frontmatter (ADR-003, Option 1).
- Record any change, with its reason, in the Agents module notes table, the README "Models and
  Effort" section (both halves), both architecture docs, and an ADR.

### 3. Update the model tables, the model-era fixture, and the test expectations
Update these in `plugins/harness-eval/scripts/static-analysis.sh` from the tables in
`shared/models.md`:
- `MODEL_ALIASES`: the Claude Code model aliases.
- `RETIRED_MODEL_PATTERNS`: models no longer served (FAIL).
- `DEPRECATED_MODEL_PATTERNS`: models still served with a retirement date (WARN).
- `KNOWN_MODEL_ID_PATTERN`: every served undated ID, listed one by one. Add the new model and
  drop the IDs that moved to the retired or deprecated tables.
- `FRONTMATTER_EFFORT_LEVELS`, `SETTINGS_EFFORT_LEVELS`, and `ENV_EFFORT_LEVELS`, if Claude
  Code accepts different effort values.
- The thinking-cap exemption in the `model-config` check (`case "$MC_BASE" in ...`), which
  lists the models that accept disabled thinking, and the `thinking_note` / `thinking_fix`
  wording, which names the models where thinking is always on. A new model where thinking is
  always on stays out of the exemption.

Keep `MODEL_ALIASES`, `FRONTMATTER_EFFORT_LEVELS`, and `KNOWN_MODEL_ID_PATTERN` each on one
line in their current form, because the structure test reads them by name.

Then update, in the same change:
- `tests/fixtures/model-era-project/`: its agents, settings, and the table in its `CLAUDE.md`
- `tests/test-static-analysis.sh`: the model-era expectations, the served-ID list, and the
  provider-form cases
- `tests/fixtures/README.md`, `scripts/CLAUDE.md`, and framework §2.1

The four maturity fixtures and `nested-hooks-project/` are frozen. If a table change moves
their results, update the test expectations, not the fixtures.

### 4. Run the full test suite
```bash
cd plugins/harness-eval
bash tests/harness-run-all.sh
HARNESS_EVAL_ROOT="$(pwd)" bash tests/test-scoring.sh
HARNESS_EVAL_ROOT="$(pwd)" bash tests/test-static-analysis.sh
HARNESS_EVAL_ROOT="$(pwd)" bash tests/test-history.sh
HARNESS_EVAL_ROOT="$(pwd)" bash tests/test-aggregate.sh
cd -
```
The runner must report 0 failed and 0 skipped. Its structure suite also runs
`static-analysis.sh` on this repository and fails unless `model-config` and `agent-format`
pass, so a pin that the new tables no longer accept shows up here. If tests were added or
removed, update the counts listed in the plugin `CLAUDE.md` Auto-Sync Rules.

### 5. Run the plugin live on a fixture
Run each mode non-interactively on a git-initialized copy of the production fixture, loading
this checkout's plugin with `--plugin-dir`:

```bash
REPO="$(git rev-parse --show-toplevel)"
WORK="$(mktemp -d)"
cp -R "$REPO/plugins/harness-eval/tests/fixtures/production-project" "$WORK/prod"
cd "$WORK/prod"
git init -q && git add -A
git -c user.name=smoke -c user.email=smoke@localhost commit -qm fixture
unset HARNESS_EVAL_AUTO_BADGE    # the README check below assumes no badge opt-in

run() {  # $1 = log name, $2 = prompt; logs go to $WORK, outside the fixture's git tree
  local start=$SECONDS
  claude -p "$2" --plugin-dir "$REPO/plugins/harness-eval" --model opus \
    --permission-mode acceptEdits --allowedTools "Bash Read Write Edit Glob Grep Agent Task" \
    --output-format stream-json --verbose --no-session-persistence --max-budget-usd 25 \
    > "$WORK/$1.jsonl" 2> "$WORK/$1.err"
  echo "$1 exit=$? seconds=$(( SECONDS - start ))" >> "$WORK/timings.txt"
}
run quick "/harness-eval:quick"
run standard "/harness-eval:standard --static-only"
run full "/harness-eval:full"
run compare "/harness-eval:compare"
```

- Standard runs with `--static-only` because its dynamic phase asks in chat before running
  the target's code, and a `-p` session has no one to answer.
- `--permission-mode acceptEdits` and `--allowedTools` keep permission prompts from stalling
  the session and its subagents.
- `--max-budget-usd` bounds the spend.
- A Stop hook in your user settings that re-prompts after each response (a review gate, for
  example) adds turns, time, and cost to every run. Either leave user settings out with
  `--setting-sources project,local` (your provider configuration must then come from the
  environment), or name the hook next to the figures you record, as ADR-003 does.

Check the results:

```bash
cd "$WORK"
# Every call, in the main session and in each subagent, ran on the intended model
for f in quick standard full compare; do
  printf '%s: ' "$f"; jq -r 'select(.type=="result") | .modelUsage | keys[]' "$f.jsonl" | sort -u | paste -sd' ' -
done
jq -r 'select(.type=="assistant") | .message.model' full.jsonl | sort | uniq -c

# Full dispatched all five subagents
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Agent") | .input.subagent_type' full.jsonl

# One history entry per saved run: Standard and Full save, Quick and Compare do not
bash "$REPO/plugins/harness-eval/scripts/history.sh" "$WORK/prod" list | jq -r '.[] | "\(.id) \(.mode) \(.overall)"'

# An English and a Korean report per run
ls "$WORK/prod/.harness-eval/reports/"

# .harness-eval/ ignores itself, README.md is unchanged, and nothing else changed
cat "$WORK/prod/.harness-eval/.gitignore"
git -C "$WORK/prod" status --porcelain

# Wall-clock per run, and the session cost from the last result event
cat timings.txt
for f in quick standard full compare; do
  printf '%s: $' "$f"; jq -r 'select(.type=="result") | .total_cost_usd' "$f.jsonl" | tail -1
done
```

Expected:
- only the target model under `modelUsage` and `.message.model`
- `harness-eval:collector`, `harness-eval:safety-evaluator`, `harness-eval:completeness-evaluator`,
  `harness-eval:design-evaluator`, and `harness-eval:synthesizer`
- two history entries (`standard`, then `full`)
- `-en.md` and `-ko.md` reports for quick, standard, full, and compare
- a `.gitignore` containing `*`
- empty `git status --porcelain`. The production fixture has no README.md, so a badge write
  would show up as an untracked `README.md`

### 6. Record the timings and cost
Add the figures to the ADR that records the model change (ADR-003 "Measured run time and
cost" shows the format) or to its CHANGELOG entry. Include the command line, the fixture, the
model every call ran on, and anything that inflated wall-clock time. If the durations the plugin
states no longer hold, update them where they appear:

```bash
grep -rn -E '~30s|30 seconds|30초|2-3 ?min|2-3분|5-10 ?min|5-10 minutes|5-10분' \
  README.md docs plugins/harness-eval --include='*.md' | grep -v '/superpowers/'
```

## Verification
- [ ] The prompt audit's findings are applied, or kept with a stated reason.
- [ ] Each agent's `model` / `effort` matches the Agents module notes table, the README "Models
      and Effort" section (both halves), and the ADR.
- [ ] The model tables name the new model, and the model-era fixture and its expectations are
      updated.
- [ ] `bash tests/harness-run-all.sh` reports 0 failed and 0 skipped, and the four
      evaluation suites pass on their own.
- [ ] The live run meets every expectation in step 5.
- [ ] Timings and cost are recorded in an ADR or the CHANGELOG, and stated durations still hold.

## Rollback
Each step lands as ordinary commits, so revert the ones that regress (`git revert <commit>`)
and re-run steps 4 and 5. While a problem with the new model is investigated, a user can keep
the agents on the previous model by setting `ANTHROPIC_DEFAULT_OPUS_MODEL` to its ID (README
"Models and Effort"). Do not pin a model ID in agent frontmatter as a workaround (ADR-003,
Option 1).

## Notes
- `tests/fixtures/model-era-project/` is the only fixture that changes with the model line.
- A change to what the plugin checks in other projects (step 3) moves the Correctness scores
  of evaluated projects, so say so in the CHANGELOG.
- Last verified: 2026-09-23 (Claude Opus 5.5, Claude Code 2.1.280; see ADR-003)
