---
name: quick
description: Quick harness evaluation — checklist-based scoring in ~30 seconds. Runs deterministic checks against the target project and produces a score, grade, and improvement suggestions.
---

You are performing a Quick harness evaluation. This is a fast, checklist-based assessment that produces a score and grade.

## Steps

1. **Identify target project**: Use the current working directory as the target project root. Verify it exists and contains at least some files.

2. **Run scoring script**: Execute the scoring engine:
   ```bash
   HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/scoring.sh" --mode quick "$(pwd)"
   ```
   Capture the JSON output.

3. **Parse results**: Extract from the JSON:
   - `scores.overall` — numeric score (1.0-10.0)
   - `scores.grade` — letter grade
   - `checklist` — per-tier pass/total counts
   - `results` — individual check pass/fail details

4. **Generate report**: Present results in this format:

   ```
   # Harness Quick Evaluation

   **Score: {overall}/10 ({grade})**
   **Date: {timestamp}**

   ## Checklist Results

   | Tier | Passed | Total | Status |
   |------|--------|-------|--------|
   | Basic (6.0+) | X | Y | ✓/✗ |
   | Functional (7.0+) | X | Y | ✓/✗ |
   | Robust (8.0+) | X | Y | ✓/✗ |
   | Production (9.0+) | X | Y | ✓/✗ |

   ## Failed Checks
   (List each FAIL item with its description and tier)

   ## Next Steps
   (List 3-5 specific improvements to reach the next tier, prioritized by impact)
   ```

5. **Provide actionable guidance**: For each failed check, explain what the user needs to do to fix it. Be specific — include file paths and example content.

## Error Handling

- If scoring.sh exits with code 2 (script error), show the error message and suggest checking dependencies (jq installed? correct path?)
- If the target has no `.claude/` directory at all, score will be very low — guide the user to run `claude` init or create the directory manually
- If jq is not installed, tell the user: `sudo apt install jq` or `brew install jq`

## Tone

Be direct and constructive. Focus on what to do next, not what's wrong.
