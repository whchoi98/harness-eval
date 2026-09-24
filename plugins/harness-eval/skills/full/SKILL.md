---
name: full
description: Full harness evaluation — multi-agent deep analysis across 12 dimensions (safety, completeness, design quality) with parallel evaluators and a synthesized report. Takes 5-10 minutes. Produces a scored report in English and Korean with an executive summary and improvement roadmap. Use when the user explicitly asks for a full, deep, or multi-agent harness evaluation. For a quick score use quick; for static plus dynamic checks use standard.
---

You are orchestrating a Full harness evaluation of the current project in four phases: collection (two scripts, then the collector agent), parallel evaluation (three evaluator agents), synthesis (the synthesizer agent, which scores the run, saves it to history, and writes the report files), and presentation. The result is a 12-dimension scored report in two files, one English and one Korean.

The bash commands, the subagent dispatch parameters, the failure markers (`SCRIPT_FAILED`, `AGENT_FAILED`), the files under `.harness-eval/run/`, and the `ARTIFACT_WRITTEN` / `EVAL_ID` / `REPORT_EN` / `REPORT_KO` lines are contracts between the components, so use them as written. How you word progress notes, warnings, and summaries for the user is up to you.

Phases 1-3 spend minutes waiting on scripts and subagents, and the user sees nothing of that work unless you say it. So when each of those phases starts, tell the user in one line what it runs, and when it ends, tell them in one line what it produced, including a failure marker or a fallback. Phase 4 is the presentation itself and needs no such lines.

Dispatch each subagent with the Agent tool (`Task` is its legacy name) using the `subagent_type`, `description`, and `prompt` given below. Leave the model and effort unset: each agent's definition sets its own. A subagent returns only its final message, and the phases hand files to each other by path, so every prompt gives absolute paths — `<project>` below stands for the absolute path of the current working directory. Every file in `.harness-eval/run/` is rewritten on each run, so nothing from an earlier run is reused.

---

## Phase 1: Collection

### Step 1.1: Prepare the run directory

```bash
mkdir -p .harness-eval/run && rm -f .harness-eval/run/artifact.md .harness-eval/run/record.json && { test -e .harness-eval/.gitignore || test -L .harness-eval/.gitignore || printf '*\n' > .harness-eval/.gitignore; }
```

This removes the agent-written files from any earlier run, so a stale artifact or record can never stand in for this run's. When `.harness-eval/` has no `.gitignore`, it also creates one containing `*`, so git ignores the whole directory: the collector artifact records the project's local settings, which should not reach a commit. An existing `.gitignore` (or a symlink by that name) is left untouched.

### Step 1.2: Run the scripts (in parallel)

The two scripts are independent: run both commands in parallel (two Bash calls in one message).

```bash
HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/static-analysis.sh" "$(pwd)" > .harness-eval/run/static.json 2> .harness-eval/run/static.err
```

```bash
HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/scoring.sh" --mode standard "$(pwd)" > .harness-eval/run/score.json 2> .harness-eval/run/score.err
```

A script succeeded when it exits 0 or 1 (1 means it found issues in the project) and its output file is non-empty. Exit 2, or an empty output file, means it failed: note the error from its `.err` file (the last lines hold a JSON `error`) and continue. Wherever a later prompt would give that file's path, give this line instead:

- `SCRIPT_FAILED: static-analysis.sh produced no output`
- `SCRIPT_FAILED: scoring.sh produced no output`

The evaluators and the synthesizer handle these markers. A script failure never stops the run.

### Step 1.3: Collector agent

- **subagent_type**: `harness-eval:collector`
- **description**: `Collect project artifacts for harness evaluation`
- **prompt**:

```
Scan the project below and write the structured project artifact described in your agent definition.

Project path: <project>
Artifact output path: <project>/.harness-eval/run/artifact.md

Write the complete artifact to the output path with the Write tool, then end with the ARTIFACT_WRITTEN line and the Raw Summary JSON block, as your agent definition specifies.
```

The collector succeeded when its final message contains `ARTIFACT_WRITTEN: <project>/.harness-eval/run/artifact.md` and that file is non-empty:

```bash
test -s .harness-eval/run/artifact.md && echo ARTIFACT_OK
```

### If the collector fails

If the collector fails, its final message has no `ARTIFACT_WRITTEN:` line, or the artifact file is missing or empty, Phases 2 and 3 cannot run, because every evaluator works from the artifact. Tell the user, in English and Korean, that Full mode fell back to the Phase 1 script results and why. Then:

1. If both scripts also failed, say that no results are available and stop.
2. Save history from the scoring result, if scoring.sh succeeded:
   ```bash
   HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/history.sh" "$(pwd)" save < .harness-eval/run/score.json
   ```
   It prints `{"id":"eval-YYYY-MM-DD-NNN","saved":true}`; that id is the EVAL_ID. The saved record keeps `mode: "standard"`, because its score is the Standard checklist score. If scoring.sh failed or the save fails, there is no EVAL_ID and nothing is saved; say so.
3. Read `.harness-eval/run/static.json` and `.harness-eval/run/score.json` (whichever succeeded) and build the report in the Phase 4 format of `${CLAUDE_PLUGIN_ROOT}/skills/standard/SKILL.md` (read that file for the format only; do not run the Standard evaluation). Mark each Dynamic Analysis subsection `Not run (Full-mode fallback)`, and add a note under the title that this Full run fell back to Standard results because the collector failed.
4. `mkdir -p .harness-eval/reports`, then write the format's English section to `.harness-eval/reports/<EVAL_ID>-full-fallback-en.md` and its Korean section to `.harness-eval/reports/<EVAL_ID>-full-fallback-ko.md` with the Write tool, so each file is entirely in its own language. Without an EVAL_ID, use `eval-<YYYY-MM-DD>-unsaved-full-fallback-{en|ko}.md` with today's UTC date. An unsaved file of that name can already exist from an earlier run today, and the Write tool refuses to overwrite a file it has not read, so Read an existing one first and then overwrite it.
5. Present both reports (English, then Korean), give the user the EVAL_ID (or say it was not saved) and both paths, add the badge note from Phase 4, and stop.

---

## Phase 2: Parallel Evaluation

Phase 2 needs only the collector's artifact; a missing script result is passed as its `SCRIPT_FAILED` line. Dispatch all three evaluators in parallel: three Agent calls in a single message.

### 2.1: Safety Evaluator

- **subagent_type**: `harness-eval:safety-evaluator`
- **description**: `Evaluate safety posture and cost efficiency`
- **prompt**:

```
Evaluate the Safety and Cost Efficiency dimensions for the project below, as your agent definition describes.

Project path: <project>
Project artifact: <project>/.harness-eval/run/artifact.md
Static analysis results: <project>/.harness-eval/run/static.json   (or its SCRIPT_FAILED line)
Scoring results: <project>/.harness-eval/run/score.json   (or its SCRIPT_FAILED line)

Read them as needed. End with your complete output in the Agent Communication Protocol format, with scores for Safety and Cost Efficiency.
```

Store the final message verbatim as `safety_eval_output`.

### 2.2: Completeness Evaluator

- **subagent_type**: `harness-eval:completeness-evaluator`
- **description**: `Evaluate actionability, testability, and contract-based testing`
- **prompt**:

```
Evaluate the Actionability, Testability, and Contract-Based Testing dimensions for the project below, as your agent definition describes.

Project path: <project>
Project artifact: <project>/.harness-eval/run/artifact.md
Static analysis results: <project>/.harness-eval/run/static.json   (or its SCRIPT_FAILED line)
Scoring results: <project>/.harness-eval/run/score.json   (or its SCRIPT_FAILED line)

Read them as needed. End with your complete output in the Agent Communication Protocol format, with scores for Actionability, Testability, and Contract-Based Testing.
```

Store the final message verbatim as `completeness_eval_output`.

### 2.3: Design Evaluator

- **subagent_type**: `harness-eval:design-evaluator`
- **description**: `Evaluate architecture quality and design patterns`
- **prompt**:

```
Evaluate the Agent Communication, Context Management, Feedback Loop Maturity, and Evolvability dimensions for the project below, as your agent definition describes.

Project path: <project>
Project artifact: <project>/.harness-eval/run/artifact.md
Static analysis results: <project>/.harness-eval/run/static.json   (or its SCRIPT_FAILED line)
Scoring results: <project>/.harness-eval/run/score.json   (or its SCRIPT_FAILED line)

Read them as needed. End with your complete output in the Agent Communication Protocol format, with scores for Agent Communication, Context Management, Feedback Loop Maturity, and Evolvability.
```

Store the final message verbatim as `design_eval_output`.

### Phase 2 Error Handling

After all three agents finish, replace the output of any evaluator that failed or returned nothing with its marker:

- **safety-evaluator**: `AGENT_FAILED: safety-evaluator did not produce output. Safety and Cost Efficiency dimensions will be null.`
- **completeness-evaluator**: `AGENT_FAILED: completeness-evaluator did not produce output. Actionability, Testability, and Contract-Based Testing dimensions will be null.`
- **design-evaluator**: `AGENT_FAILED: design-evaluator did not produce output. Agent Communication, Context Management, Feedback Loop Maturity, and Evolvability dimensions will be null.`

Continue to Phase 3 even if every evaluator failed: the synthesizer reports the missing dimensions, and the Basic Quality dimensions still come from static analysis.

---

## Phase 3: Synthesis

### Step 3.1: Dispatch the synthesizer

- **subagent_type**: `harness-eval:synthesizer`
- **description**: `Synthesize all evaluation results into final 12-dimension report`
- **prompt**:

```
Produce the final Full evaluation for the project below, as your agent definition describes: score it with aggregate.sh, save it to history, write the English and Korean report files, and end with the EVAL_ID, REPORT_EN, REPORT_KO, SCORE, and MISSING lines.

Project path: <project>
Static analysis JSON: <project>/.harness-eval/run/static.json   (or its SCRIPT_FAILED line)
Scoring JSON: <project>/.harness-eval/run/score.json   (or its SCRIPT_FAILED line)
Collector artifact: <project>/.harness-eval/run/artifact.md

## Safety Evaluator Output
<safety_eval_output>

## Completeness Evaluator Output
<completeness_eval_output>

## Design Evaluator Output
<design_eval_output>
```

Paste each evaluator's final message verbatim in place of its placeholder, or its `AGENT_FAILED` marker if it failed. The synthesizer parses each output's `## Scores` table, so a summary or excerpt can lose dimension scores.

The synthesizer is the only component that saves this evaluation to history and writes its report files; do not repeat either step. Its final message ends with these lines:

```
EVAL_ID: <eval id, or none>
REPORT_EN: <absolute path>
REPORT_KO: <absolute path>
SCORE: <overall> (<grade>)
MISSING: <comma-separated dimension keys, or none>
```

and possibly one `NOTE:` line explaining a failed save or write.

### Step 3.2: Raw-output fallback

If the synthesizer fails, its final message has no `REPORT_EN:` or `REPORT_KO:` line, or either file is missing or empty (`test -s <path>`), warn the user in English and Korean that the synthesized report is unavailable, and present the raw results in this format. Keep each agent's output exactly as returned; only the headings and notes are written in both languages.

```
# Harness Full Evaluation — Raw Results (Synthesizer Unavailable)
# 하네스 Full 평가 — 원본 결과 (종합 보고서 없음)

**Date / 날짜: <YYYY-MM-DD>**
**Note:** The synthesizer did not produce the report, so these are the agent outputs without aggregation. <History: saved as <EVAL_ID> | not saved>
**참고:** 종합 에이전트가 보고서를 만들지 못해 집계 전 원본 출력을 그대로 보여 줍니다. <히스토리: <EVAL_ID>로 저장됨 | 저장되지 않음>

---

## Script Results / 스크립트 결과

- Static analysis / 정적 분석: <project>/.harness-eval/run/static.json (or its SCRIPT_FAILED line)
- Scoring / 채점: <project>/.harness-eval/run/score.json (or its SCRIPT_FAILED line)
- Collector artifact / 수집 산출물: <project>/.harness-eval/run/artifact.md

---

## Safety Evaluator / 안전성 평가
<safety_eval_output>

---

## Completeness Evaluator / 완전성 평가
<completeness_eval_output>

---

## Design Evaluator / 설계 평가
<design_eval_output>

---

*To get a synthesized report, run `/harness-eval:full` again. / 종합 보고서를 받으려면 `/harness-eval:full`을 다시 실행하세요.*
```

The history line reflects the synthesizer's `EVAL_ID` line: an id other than `none` means the evaluation was saved under that id, and `none` means it was not saved. If the message has no `EVAL_ID` line, check whether the synthesizer saved before it stopped, since it saves before writing the reports. Step 1.1 removed any earlier `record.json`, so a non-empty one belongs to this run:

```bash
test -s .harness-eval/run/record.json && jq -r .timestamp .harness-eval/run/record.json
```

```bash
HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/history.sh" "$(pwd)" list --last 1
```

If the listed entry has `mode` `full` and the same `timestamp` as `record.json`, this run was saved under that entry's `id`. Otherwise, or if `record.json` is missing or empty, it was not saved. When it was saved, add to the closing line, in both languages, that running Full again adds another history entry.

---

## Phase 4: Present Results

Take `EVAL_ID`, `REPORT_EN`, `REPORT_KO`, `SCORE`, and `MISSING` from the synthesizer's final message. Read both report files and present them to the user, the English report first, then the Korean one. Then give the user:

- the evaluation ID and the two report paths;
- if `SCORE` is `none`, that nothing could be scored, so the reports carry no score and nothing was saved to history, and which inputs failed (the static analysis and the evaluators; the `NOTE:` line may give the reason). Leave out the history-save warning here, because no save was attempted;
- otherwise, if `EVAL_ID` is `none`, a warning that the history save failed (with the `NOTE:` reason if given) — the reports are still complete;
- if there is a score and `MISSING` is not `none`, which dimensions are missing and why.

The README badge is not updated by this run. End by telling the user that, if they have opted in (`HARNESS_EVAL_AUTO_BADGE=1`, or `{"autoBadge": true}` in an untracked `.harness-eval/config.json`; a copy tracked by git does not count), the plugin's Stop hook refreshes it when this response finishes, and that otherwise, or if the badge does not change, they can update it with:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/badge.sh" "$(pwd)"
```

Show this command with the plugin's path in place of CLAUDE_PLUGIN_ROOT and the project's absolute path in place of `$(pwd)`, because the user's shell does not define CLAUDE_PLUGIN_ROOT and may be in another directory. (`badge.sh` rewrites or creates the project's README.md, which is why it runs only on the user's opt-in or request.) When `EVAL_ID` is `none`, leave the badge note out: the badge shows the latest saved evaluation, and this run is not one.

---

## Error Handling Summary

| Failure point | Behavior |
|---------------|----------|
| static-analysis.sh fails (exit 2 or empty output) | Continue; later prompts get `SCRIPT_FAILED: static-analysis.sh produced no output`, and the four Basic Quality dimensions are missing |
| scoring.sh fails (exit 2 or empty output) | Continue; later prompts get `SCRIPT_FAILED: scoring.sh produced no output`; no dimension depends on it |
| Collector fails (no `ARTIFACT_WRITTEN` line, or artifact missing or empty) | Skip Phases 2 and 3; build the Standard-format fallback report from the script results, save history from `score.json`, write `<EVAL_ID>-full-fallback-{en,ko}.md` |
| Collector and both scripts fail | Report that no results are available and stop |
| An evaluator fails | Its `AGENT_FAILED` marker replaces its output; its dimensions are missing; synthesis continues |
| All evaluators fail | Synthesis continues with the Basic Quality dimensions only |
| Every dimension missing (static analysis and all evaluators failed) | The synthesizer writes reports without a score, saves nothing, and returns `SCORE: none`; Phase 4 reports that nothing could be scored, not a failed save |
| Synthesizer fails, or `REPORT_EN` / `REPORT_KO` missing | Raw-output fallback (Step 3.2); without an `EVAL_ID` line, `record.json` and `history.sh list --last 1` show whether it saved first |
| History save fails (`EVAL_ID: none`) | Reports are still written as `eval-<date>-unsaved-full-{en,ko}.md` and presented; warn the user |

A partial failure never stops the evaluation: the user always gets the best report the available data supports.

---

## Data Flow Diagram

```
Phase 1 (scripts in parallel, then collector):
  static-analysis.sh ──→ .harness-eval/run/static.json   (or SCRIPT_FAILED marker)
  scoring.sh         ──→ .harness-eval/run/score.json    (or SCRIPT_FAILED marker)
  collector agent    ──→ .harness-eval/run/artifact.md   final message: ARTIFACT_WRITTEN: <path>
                              │  paths, not contents
                              ▼
Phase 2 (parallel):
  safety-evaluator     ┐  each reads artifact.md, static.json, score.json
  completeness-eval    ├──→ 3 evaluator outputs, returned as final messages
  design-evaluator     ┘     (or AGENT_FAILED markers)
                              │  paths + the 3 outputs inline
                              ▼
Phase 3 (synthesizer):
  12 dimension scores ──→ aggregate.sh ──→ .harness-eval/run/record.json
  history.sh list (earlier runs), then history.sh save < record.json ──→ EVAL_ID
  Write ──→ .harness-eval/reports/<EVAL_ID>-full-en.md, <EVAL_ID>-full-ko.md
  final message: EVAL_ID / REPORT_EN / REPORT_KO / SCORE / MISSING
                              │
                              ▼
Phase 4 (orchestrator):
  Read and present both reports, report EVAL_ID and paths, badge note (opt-in)
```

---

## Tone

If any phase had failures, say clearly what was affected and which data is missing, so the user knows how complete the report is and how far to trust it.

## Language

The Full report is two files, each entirely in one language: `<EVAL_ID>-full-en.md` in English and `<EVAL_ID>-full-ko.md` in Korean. Scores, grades, weights, status markers, file paths, and code blocks are identical in both; the Korean file translates the prose and, in the Dimension Scores table, the column headers and the Category and Dimension labels. The synthesizer writes both files directly, and the collector-failure fallback follows the same two-file rule. Write your own messages to the user (progress lines, warnings, the evaluation ID and paths, the badge note) in both English and Korean; a progress line can carry both languages on one line. In the raw-output fallback (Step 3.2), keep each agent's output as returned and write only the headings and notes in both languages.
