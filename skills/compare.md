---
name: compare
description: Compare harness evaluation history — shows score trends, per-tier deltas, diminishing returns detection, and next grade projection.
---

You are performing a harness evaluation comparison. This analyzes evaluation history to show trends and improvements.

## Steps

1. **Get evaluation history**: Run:
   ```bash
   HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/history.sh" "$(pwd)" list
   ```
   This returns a JSON array of past evaluations.

2. **Check minimum history**: If fewer than 2 evaluations exist, inform the user:
   "Not enough evaluation history to compare. Run `/harness-eval quick` or `/harness-eval standard` at least twice to enable comparison."

3. **Get comparison data**: Run:
   ```bash
   HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/history.sh" "$(pwd)" compare
   ```
   This returns current vs previous delta.

4. **Present comparison report**:

   ```
   # Harness Evaluation Comparison

   ## Current vs Previous

   | Metric | Previous | Current | Delta |
   |--------|----------|---------|-------|
   | Score | {prev_score}/10 | {curr_score}/10 | {delta} |
   | Grade | {prev_grade} | {curr_grade} | {changed?} |

   ## Per-Tier Changes

   | Tier | Previous | Current | Delta |
   |------|----------|---------|-------|
   | Basic | X/Y | X/Y | ↑/↓/→ |
   | Functional | X/Y | X/Y | ↑/↓/→ |
   | Robust | X/Y | X/Y | ↑/↓/→ |
   | Production | X/Y | X/Y | ↑/↓/→ |
   ```

5. **Score history chart**: If 3+ evaluations exist, show an ASCII bar chart:
   ```
   ## Score History

   eval-04-06-001  ████████░░  7.2  B
   eval-04-06-002  █████████░  7.9  B
   eval-04-06-003  █████████░  8.5  A-
   ```
   Use █ for filled, ░ for empty, 10 chars total width.

6. **Trend analysis**:
   - **Diminishing returns**: If the last 3+ deltas show shrinking improvements (e.g., +0.7, +0.6, +0.5), warn: "Score improvements are shrinking — further gains will require infrastructure investments (CI/CD, integration tests, performance benchmarks)."
   - **Grade projection**: Based on current score and trend, estimate when the next grade threshold will be reached.
   - **Stalled areas**: Identify tiers that haven't improved across evaluations.

7. **Recommendations**: Based on the comparison, suggest the highest-impact actions to continue improving.

## Error Handling

- If history.sh fails: suggest running an evaluation first
- If only 1 evaluation exists: show current score and suggest running again after improvements
- If compare returns an error: display it clearly

## Tone

Be analytical and forward-looking. Focus on trajectory and momentum, not just current state.
