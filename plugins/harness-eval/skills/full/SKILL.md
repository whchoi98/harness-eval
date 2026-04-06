---
name: full
description: Full harness evaluation — multi-agent deep analysis across 12 dimensions (safety, completeness, design quality) with parallel evaluators and synthesized report. Takes 5-10 minutes. Produces a comprehensive scored report with executive summary and improvement roadmap.
---

You are performing a Full harness evaluation. This is the most comprehensive evaluation mode. It uses a multi-agent architecture with 3 phases: Collection, Parallel Evaluation, and Synthesis. The result is a 12-dimension scored report.

**Important**: You are the orchestrator. You coordinate scripts and agents, pass data between phases, and handle failures gracefully. Follow each step exactly.

---

## Phase 1: Collection (Sequential)

Run these steps in order. Each step depends on the previous one.

### Step 1.1: Static Analysis

Run the static analysis script and capture its output:

```bash
HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/static-analysis.sh" "$(pwd)"
```

Store the entire output as `static_results`. This JSON contains scores for Correctness, Safety, Completeness, and Consistency.

**If this fails** (exit code 2): Log the error. You may still continue — scoring in Step 1.2 can work independently.

### Step 1.2: Scoring

Run the scoring engine in standard mode:

```bash
HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/scoring.sh" --mode standard "$(pwd)"
```

Store the entire output as `score_results`. This JSON contains checklist pass/fail results and tier scores.

**If this fails** (exit code 2): Log the error. Continue if static_results succeeded — you have partial Standard results.

### Step 1.3: Collector Agent

Dispatch the collector agent using the Agent tool. This agent scans the project and produces a structured inventory artifact.

Use the **Agent tool** with these parameters:
- **description**: `Collect project artifacts for harness evaluation`
- **prompt**: Construct the prompt as follows (include the actual values of `static_results` and `score_results` inline):

```
You are the collector agent for harness-eval. Scan the project at the following path and produce a structured project artifact.

Project path: <INSERT_CURRENT_WORKING_DIRECTORY>

For reference, here are the Standard evaluation results already collected:

## Static Analysis Results
<INSERT static_results HERE>

## Scoring Results
<INSERT score_results HERE>

Follow all instructions in your agent definition. Produce the full structured artifact in the Agent Communication Protocol format.
```

Store the collector's complete output as `project_artifact`.

### Step 1.3 Error Handling — CRITICAL

**If the collector agent fails or produces no output**:
1. Warn the user: "Collector agent failed. Falling back to Standard evaluation results only. The 12-dimension deep analysis (Phase 2 and Phase 3) will be skipped."
2. **Skip Phase 2 and Phase 3 entirely.**
3. Instead, present a Standard-mode report using only `static_results` and `score_results`. Use the Standard report format (see the standard skill for reference).
4. Note in the report that this was a Full evaluation that fell back to Standard due to collector failure.
5. **Stop here** — do not proceed to Phase 2.

---

## Phase 2: Parallel Evaluation

**Prerequisite**: Phase 1 completed successfully (all three outputs are available: `static_results`, `score_results`, `project_artifact`).

Dispatch ALL 3 evaluator agents in parallel. Use the Agent tool 3 times in a **single message** so they run concurrently.

### Agent Dispatch Instructions

For each evaluator agent below, use the **Agent tool** with the specified description and prompt. Each prompt must include all 3 artifacts from Phase 1 inline so the agent has full context.

#### 2.1: Safety Evaluator

- **description**: `Evaluate safety posture and cost efficiency`
- **prompt**:

```
You are the safety-evaluator agent for harness-eval. Evaluate the Safety and Cost Efficiency dimensions for the project described below.

## Project Artifact (from collector)
<INSERT project_artifact HERE>

## Static Analysis Results
<INSERT static_results HERE>

## Scoring Results
<INSERT score_results HERE>

Follow all instructions in your agent definition. Produce your output in the Agent Communication Protocol format with scores for Safety and Cost Efficiency.
```

Store the output as `safety_eval_output`.

#### 2.2: Completeness Evaluator

- **description**: `Evaluate actionability, testability, and contract-based testing`
- **prompt**:

```
You are the completeness-evaluator agent for harness-eval. Evaluate the Actionability, Testability, and Contract-Based Testing dimensions for the project described below.

## Project Artifact (from collector)
<INSERT project_artifact HERE>

## Static Analysis Results
<INSERT static_results HERE>

## Scoring Results
<INSERT score_results HERE>

Follow all instructions in your agent definition. Produce your output in the Agent Communication Protocol format with scores for Actionability, Testability, and Contract-Based Testing.
```

Store the output as `completeness_eval_output`.

#### 2.3: Design Evaluator

- **description**: `Evaluate architecture quality and design patterns`
- **prompt**:

```
You are the design-evaluator agent for harness-eval. Evaluate the Agent Communication, Context Management, Feedback Loop Maturity, and Evolvability dimensions for the project described below.

## Project Artifact (from collector)
<INSERT project_artifact HERE>

## Static Analysis Results
<INSERT static_results HERE>

## Scoring Results
<INSERT score_results HERE>

Follow all instructions in your agent definition. Produce your output in the Agent Communication Protocol format with scores for Agent Communication, Context Management, Feedback Loop Maturity, and Evolvability.
```

Store the output as `design_eval_output`.

### Phase 2 Error Handling

After all 3 agents complete (or fail):

- **If safety-evaluator failed**: Set `safety_eval_output` to the text `AGENT_FAILED: safety-evaluator did not produce output. Safety and Cost Efficiency dimensions will be null.`
- **If completeness-evaluator failed**: Set `completeness_eval_output` to the text `AGENT_FAILED: completeness-evaluator did not produce output. Actionability, Testability, and Contract-Based Testing dimensions will be null.`
- **If design-evaluator failed**: Set `design_eval_output` to the text `AGENT_FAILED: design-evaluator did not produce output. Agent Communication, Context Management, Feedback Loop Maturity, and Evolvability dimensions will be null.`

**Partial failure never stops the evaluation.** Even if 2 of 3 agents fail, proceed to Phase 3 with whatever results you have.

---

## Phase 3: Synthesis

Dispatch the synthesizer agent to aggregate all results into the final 12-dimension report.

### Step 3.1: Dispatch Synthesizer

Use the **Agent tool** with:
- **description**: `Synthesize all evaluation results into final 12-dimension report`
- **prompt**:

```
You are the synthesizer agent for harness-eval. Aggregate all evaluation data below into the final 12-dimension report.

## Static Analysis Results
<INSERT static_results HERE>

## Scoring Results
<INSERT score_results HERE>

## Project Artifact (from collector)
<INSERT project_artifact HERE>

## Safety Evaluator Output
<INSERT safety_eval_output HERE>

## Completeness Evaluator Output
<INSERT completeness_eval_output HERE>

## Design Evaluator Output
<INSERT design_eval_output HERE>

Follow all instructions in your agent definition. Handle any AGENT_FAILED markers by setting those dimensions to null and noting them as missing. Produce the final report in BILINGUAL format (English first, then --- separator, then Korean). Tables, scores, and code are identical in both sections — only prose text differs. After the report, execute the history save and badge update commands.
```

Store the output as `final_report`.

### Step 3.2: Synthesizer Error Handling

**If the synthesizer fails**:
1. Warn the user: "Synthesizer agent failed. Presenting raw evaluator outputs directly."
2. Present the raw outputs in this fallback format:

```
# Harness Full Evaluation — Raw Results (Synthesizer Unavailable)

**Date: <timestamp>**
**Note: The synthesizer agent failed. These are the raw agent outputs without aggregation.**

---

## Standard Results

### Static Analysis
<static_results>

### Scoring
<score_results>

---

## Collector Artifact
<project_artifact>

---

## Safety Evaluator
<safety_eval_output>

---

## Completeness Evaluator
<completeness_eval_output>

---

## Design Evaluator
<design_eval_output>

---

*To get a synthesized report, run `/harness-eval full` again.*
```

---

## Phase 4: Present Results

If Phase 3 succeeded, present `final_report` to the user. The synthesizer's output IS the final report — display it directly.

After presenting the report:

1. **Save history** (if not already done by synthesizer):
   ```bash
   echo '<scoring-json>' | HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/history.sh" "$(pwd)" save
   ```
   Where `<scoring-json>` is the JSON object with the overall score, grade, mode "full", and all 12 dimension scores (use null for any dimensions that failed).

2. **Update badge**:
   ```bash
   HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/badge.sh" "$(pwd)"
   ```

3. Report the evaluation ID from history save to the user.

**If history save or badge update fails**: Warn the user but do NOT suppress the report. The report is the primary output.

---

## Error Handling Summary

| Failure Point | Behavior |
|---------------|----------|
| static-analysis.sh fails | Log error, continue to scoring |
| scoring.sh fails | Log error, continue with available results |
| Collector agent fails | **Abort Full mode**, fall back to Standard report using available script results |
| Any evaluator agent fails | Mark its dimensions as null, continue to synthesis with partial data |
| All evaluator agents fail | Proceed to synthesis — synthesizer will report all dimensions as null |
| Synthesizer fails | Present raw agent outputs in fallback format |
| History save fails | Warn user, report still presented |
| Badge update fails | Warn user, report still presented |

**Core principle**: Partial failure never stops the entire evaluation. Always produce the best report possible with available data.

---

## Data Flow Diagram

```
Phase 1 (Sequential):
  static-analysis.sh  ──→  static_results
  scoring.sh           ──→  score_results
  collector agent      ──→  project_artifact
                              │
                              ▼
Phase 2 (Parallel):    ┌─────────────────┐
  safety-evaluator     │  All 3 receive:  │
  completeness-eval    │  static_results  │──→  3 evaluator outputs
  design-evaluator     │  score_results   │     (or AGENT_FAILED markers)
                       │  project_artifact│
                       └─────────────────┘
                              │
                              ▼
Phase 3 (Sequential):
  synthesizer          ──→  final_report
                              │
                              ▼
Phase 4:
  Present report + save history + update badge
```

---

## Tone

Be thorough and transparent. If any phase had failures, clearly communicate what was affected and what data is missing. The user should always understand the completeness and confidence level of their report.

## Language

Always produce the report in both English and Korean. English section first, then a horizontal rule (---), then the Korean section. Tables, scores, file paths, and code blocks are identical in both sections — only the prose text differs. This applies to the final synthesized report, fallback reports, and all error messages shown to the user.
