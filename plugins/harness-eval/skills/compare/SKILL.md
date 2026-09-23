---
name: compare
description: Compare harness evaluation history — shows score trends, per-tier deltas, diminishing returns detection, and next grade projection.
effort: low
---

You are performing a harness evaluation comparison. This analyzes evaluation history to show trends and improvements.

## Steps

1. **Get evaluation history**: Run:
   ```bash
   HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/history.sh" "$(pwd)" list
   ```
   This returns a JSON array of past evaluations, oldest first, each with `id`, `timestamp`, `mode`, `overall`, and `grade`.

2. **Check minimum history**: If fewer than two evaluations exist, show the latest one's score and grade if there is one, then tell the user:
   "Not enough evaluation history to compare. Comparison needs at least two saved Standard or Full runs — run `/harness-eval:standard` or `/harness-eval:full` (Quick runs are not saved to history)."
   Stop there; there is nothing to compare or save.

3. **Get comparison data**: Run:
   ```bash
   HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/history.sh" "$(pwd)" compare
   ```
   This compares the latest entry with the one before it. It returns `current` and `previous` (each with `id`, `overall`, `grade`, `timestamp`), `delta.overall`, `delta.grade_changed`, and `per_tier.<tier>` with `current`, `previous`, and `delta` as checklist pass-rate ratios (0–1). It does not include each entry's mode; take that from the list output.

   If `current` and `previous` have different modes, say so before the tables: Standard (checklist) and Full (12-dimension) overall scores are not directly comparable. Full entries carry no checklist, so omit the per-tier table when either side is a Full run. If the list has an earlier entry with the current run's mode, you can also run compare with `--eval-id <that entry's id>`, which uses it as `previous`, and show that like-for-like comparison as well, labeled with the entry it used.

4. **Present bilingual comparison report** (English first, then `---`, then Korean):

   ```
   # Harness Evaluation Comparison

   ## Current vs Previous

   | Metric | Previous | Current | Delta |
   |--------|----------|---------|-------|
   | Score | {prev_score}/10 | {curr_score}/10 | {delta} |
   | Grade | {prev_grade} | {curr_grade} | {changed?} |

   ## Per-Tier Changes (checklist pass rate)

   | Tier | Previous | Current | Delta |
   |------|----------|---------|-------|
   | Basic | {previous %} | {current %} | {delta, percentage points} ↑/↓/→ |
   | Functional | {previous %} | {current %} | {delta, percentage points} ↑/↓/→ |
   | Robust | {previous %} | {current %} | {delta, percentage points} ↑/↓/→ |
   | Production | {previous %} | {current %} | {delta, percentage points} ↑/↓/→ |

   ---

   # 하네스 평가 비교

   ## 현재 vs 이전

   | 지표 | 이전 | 현재 | 변화 |
   |------|------|------|------|
   | 점수 | {prev_score}/10 | {curr_score}/10 | {delta} |
   | 등급 | {prev_grade} | {curr_grade} | {changed?} |

   ## 단계별 변화 (체크리스트 통과율)

   | 단계 | 이전 | 현재 | 변화 |
   |------|------|------|------|
   | 기본 | {이전 %} | {현재 %} | {변화, %p} ↑/↓/→ |
   | 기능적 | {이전 %} | {현재 %} | {변화, %p} ↑/↓/→ |
   | 견고 | {이전 %} | {현재 %} | {변화, %p} ↑/↓/→ |
   | 프로덕션 | {이전 %} | {현재 %} | {변화, %p} ↑/↓/→ |
   ```

   Per-tier values come from `per_tier.<tier>` in the compare output: ratios 0–1, shown as percentages, with the delta in percentage points.

5. **Score history chart**: If 3+ evaluations exist, show an ASCII bar chart with one line per entry from the list output (illustrative):
   ```
   ## Score History

   eval-2026-04-06-001  standard  ███████░░░  7.2  B
   eval-2026-04-06-002  standard  ████████░░  7.9  B
   eval-2026-04-07-001  full      █████████░  8.5  A-
   ```
   Use █ for filled, ░ for empty, 10 chars total width; the number of filled chars is the score rounded to the nearest whole number.

6. **Trend analysis** (when the history mixes Standard and Full runs, compute trends within one mode):
   - **Diminishing returns**: If the last 3+ deltas show shrinking improvements (e.g., +0.7, +0.6, +0.5), warn: "Score improvements are shrinking — further gains will require infrastructure investments (CI/CD, integration tests, performance benchmarks)."
   - **Grade projection**: Based on current score and trend, estimate when the next grade threshold will be reached.
   - **Stalled areas**: Identify tiers that haven't improved across evaluations.

7. **Recommendations**: Based on the comparison, suggest the highest-impact actions to continue improving.

8. **Save reports to files**: Save the English and Korean comparison reports as separate files:
   ```bash
   mkdir -p .harness-eval/reports
   ```
   - English report: `.harness-eval/reports/{current.id}-compare-en.md`
   - Korean report: `.harness-eval/reports/{current.id}-compare-ko.md`

   `{current.id}` is `current.id` from the compare output. Use the Write tool to create each file. If a file of that name already exists (compare run again without a new evaluation in between), Read it first and then overwrite it, because the Write tool refuses to overwrite a file it has not read. Inform the user of the saved file paths.

## Error Handling

- If history.sh exits with code 2 (script error): show the error and suggest checking dependencies (jq installed? correct path?)
- If compare returns an `error` object: display it clearly

## Tone

Be analytical and forward-looking. Focus on trajectory and momentum, not just current state.

## Language

Always produce the report in both English and Korean. English section first, then a horizontal rule (---), then the Korean section. Tables, scores, and charts are identical in both sections — only the prose text (analysis, recommendations, warnings) differs.
